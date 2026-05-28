#!/bin/bash

set -Eeuo pipefail

# Evitar ejecución duplicada en la misma sesión
if [[ "${JB_REPORT_ALREADY_RUN:-0}" == "1" ]]; then
    return 0 2>/dev/null || exit 0
fi
export JB_REPORT_ALREADY_RUN=1

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/core/utils.sh"
source "$BASE_DIR/core/bootstrap/ui.sh"

set_ui_context "Report"

# Helper to retrieve a value from the state file
state_value() {

    local key="$1"
    local value=""

    if [[ -f "$STATE_FILE" ]]; then
        value=$(awk -F= -v key="$key" \
            '$1 == key {print substr($0, length(key) + 2); exit}' \
            "$STATE_FILE")
    fi

    if [[ -n "$value" ]]; then
        printf "%s\n" "$value"
    else
        printf "%s\n" "N/A"
    fi
}

# =========================
# Header
# =========================

print_banner

echo ""
info "ℹ️ Generando resumen ejecutivo del sistema"

section "Sistema"

load_hardware_info
MODEL="${HARDWARE_NAME:-${HARDWARE_MODEL:-Unknown}}"

if command -v fastfetch >/dev/null 2>&1; then

    echo "Modelo:"
    fastfetch --structure Host \
        --logo none \
        --pipe false 2>/dev/null || echo "$MODEL"

else

    echo "Modelo:"
    echo "$MODEL"
fi

if command -v fastfetch >/dev/null 2>&1; then

    echo ""
    echo "macOS:"
    fastfetch --structure OS:Kernel:Uptime:Display \
        --logo none \
        --pipe false 2>/dev/null || true
fi

echo ""
echo "CPU:"
sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "No disponible"

echo ""
echo "RAM:"
PAGE_SIZE=4096
TOTAL_MB=$(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1024 / 1024 ))
FREE_PERCENT=$(memory_pressure 2>/dev/null \
    | awk -F': ' '/System-wide memory free percentage/ {print $2}' \
    | tr -d '%')

if [[ -n "$FREE_PERCENT" && "$TOTAL_MB" -gt 0 ]]; then
    USED_MB=$((TOTAL_MB * (100 - FREE_PERCENT) / 100))
else
    FREE_PAGES=$(vm_stat | awk '/Pages free/ {print $3}' | tr -d '.')
    SPECULATIVE_PAGES=$(vm_stat | awk '/Pages speculative/ {print $3}' | tr -d '.')
    FREE_PAGES=${FREE_PAGES:-0}
    SPECULATIVE_PAGES=${SPECULATIVE_PAGES:-0}
    FREE_MB=$(((FREE_PAGES + SPECULATIVE_PAGES) * PAGE_SIZE / 1024 / 1024))
    USED_MB=$((TOTAL_MB - FREE_MB))
    [[ "$USED_MB" -lt 0 ]] && USED_MB=0
fi

if [[ "$TOTAL_MB" -gt 0 ]]; then
    RAM_PCT=$((USED_MB * 100 / TOTAL_MB))
else
    RAM_PCT=0
fi

USED_RAM_GB=$(awk "BEGIN {printf \"%.1f\", $USED_MB/1024}")
TOTAL_RAM_GB=$(awk "BEGIN {printf \"%.0f\", $TOTAL_MB/1024}")

echo "${USED_RAM_GB}GB / ${TOTAL_RAM_GB}GB (${RAM_PCT}%)"

echo ""
echo "Disco:"

DISK_INFO=$(df -H / 2>/dev/null | tail -1)

if [[ -n "$DISK_INFO" ]]; then

    DISK_TOTAL=$(echo "$DISK_INFO" | awk '{print $2}')
    DISK_USED=$(echo "$DISK_INFO" | awk '{print $3}')
    DISK_PERCENT=$(echo "$DISK_INFO" | awk '{print $5}')

    echo "• Capacidad total: ${DISK_TOTAL}"
    echo "• Espacio utilizado: ${DISK_USED} (${DISK_PERCENT})"

else
    echo "• Información no disponible"
fi

echo ""
echo "Homebrew:"

if brew_available; then

    FORMULA_COUNT=$(brew list --formula 2>/dev/null | wc -l | tr -d ' ')
    CASK_COUNT=$(brew list --cask 2>/dev/null | wc -l | tr -d ' ')

    echo "• ${FORMULA_COUNT} fórmulas"
    echo "• ${CASK_COUNT} casks"

else
    echo "• Homebrew no instalado"
fi

# =========================
# Score comparación
# =========================
section "Resultados"

SCORE_BEFORE="$(state_value SCORE_BEFORE)"

SCORE_AFTER=$(calculate_health_score \
    | tail -1 \
    | tr -dc '0-9')

# Guardar SCORE_AFTER en state.env para el generador de PDF
grep -v "^SCORE_AFTER=" "$STATE_FILE" 2>/dev/null > "${STATE_FILE}.tmp" || true
echo "SCORE_AFTER=$SCORE_AFTER" >> "${STATE_FILE}.tmp"
mv "${STATE_FILE}.tmp" "$STATE_FILE"

echo "Score anterior: $SCORE_BEFORE"
echo "Score actual:   $SCORE_AFTER"

if [[ "$SCORE_BEFORE" != "N/A" ]]; then
    DIFF=$((SCORE_AFTER - SCORE_BEFORE))

    if [[ "$DIFF" -gt 0 ]]; then
        echo "• Mejora detectada: +$DIFF puntos"
    elif [[ "$DIFF" -lt 0 ]]; then
        echo "• Cambio negativo detectado: $DIFF puntos"
    else
        echo "• Estado estable"
    fi
else
    echo "• No hay score previo registrado"
fi

# =========================
# Resumen rápido
# =========================
section "Resumen"

REPORT_DATE=$(date '+%Y-%m-%d %H:%M')

echo "Fecha del reporte: $REPORT_DATE"
echo ""

SPACE_RECOVERED="$(state_value TOTAL_FREED_MB)"
FILES_REMOVED_STATE="$(state_value FILES_REMOVED)"
PERFORMANCE_PROFILE_STATE="$(state_value PERFORMANCE_PROFILE)"
LAST_MAINTENANCE="$(state_value LAST_MAINTENANCE)"

if [[ "$SCORE_AFTER" -ge 90 ]]; then
    echo "• Sistema en excelente estado"
elif [[ "$SCORE_AFTER" -ge 70 ]]; then
    echo "• Sistema en estado aceptable"
else
    echo "• Sistema requiere atención"
fi


echo ""
echo "Mantenimiento reciente:"

if [[ "$LAST_MAINTENANCE" != "N/A" ]]; then
    echo "• Última ejecución: $LAST_MAINTENANCE"
fi

if [[ "$SPACE_RECOVERED" != "N/A" ]]; then

    if [[ "$SPACE_RECOVERED" -eq 0 ]]; then
        echo "• No fue necesario liberar espacio"
    elif [[ "$SPACE_RECOVERED" -ge 1024 ]]; then
        printf "• Espacio recuperado: %.1fGB\n" \
            "$(awk "BEGIN {print $SPACE_RECOVERED/1024}")"
    else
        printf "• Espacio recuperado: %sMB\n" "$SPACE_RECOVERED"
    fi
fi

if [[ "$FILES_REMOVED_STATE" != "N/A" && "$FILES_REMOVED_STATE" -gt 0 ]]; then
    echo "• Elementos eliminados: $FILES_REMOVED_STATE"
fi

if [[ "$PERFORMANCE_PROFILE_STATE" != "N/A" && "$PERFORMANCE_PROFILE_STATE" != "none" ]]; then
    echo "• Perfil aplicado: $PERFORMANCE_PROFILE_STATE"
fi

PDF_GENERATED="false"

print_completion "true"

# Salida inmediata tras generación
return 0 2>/dev/null || exit 0
