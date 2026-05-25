#!/bin/bash

set -Eeuo pipefail

# Evitar ejecución duplicada en la misma sesión
if [[ "${JB_REPORT_ALREADY_RUN:-0}" == "1" ]]; then
    return 0 2>/dev/null || exit 0
fi
export JB_REPORT_ALREADY_RUN=1

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/core/utils.sh"


state_value() {
    local key="$1"
    local value=""

    if [[ -f "$STATE_FILE" ]]; then
        value=$(awk -F= -v key="$key" '$1 == key {print substr($0, length(key) + 2); exit}' "$STATE_FILE")
    fi

    if [[ -n "$value" ]]; then
        printf "%s\n" "$value"
    else
        printf "%s\n" "N/A"
    fi
}

# =========================
# Información del sistema
# =========================

section "JB Report"

echo "Modelo:"
load_hardware_info
MODEL="${HARDWARE_NAME:-${HARDWARE_MODEL:-Unknown}}"
echo "$MODEL"

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
fi

if [[ "$TOTAL_MB" -gt 0 ]]; then
    RAM_PCT=$((USED_MB * 100 / TOTAL_MB))
else
    RAM_PCT=0
fi

echo "$USED_MB MB / $TOTAL_MB MB (${RAM_PCT}%)"

echo ""
echo "Disco (/):"
df -h / | tail -1 || echo "No disponible"

echo ""
echo "Homebrew paquetes:"
if brew_available; then
    brew list 2>/dev/null | wc -l | tr -d ' '
else
    echo "0"
fi

# =========================
# Score comparación
# =========================
section "Resultados"

SCORE_BEFORE="$(state_value SCORE_BEFORE)"

SCORE_AFTER=$(calculate_health_score)

# Guardar SCORE_AFTER en state.env para el generador de PDF
grep -v "SCORE_AFTER" "$STATE_FILE" 2>/dev/null > "${STATE_FILE}.tmp" || true
echo "SCORE_AFTER=$SCORE_AFTER" >> "${STATE_FILE}.tmp"
mv "${STATE_FILE}.tmp" "$STATE_FILE"

echo "Score anterior: $SCORE_BEFORE"
echo "Score actual:   $SCORE_AFTER"

if [[ "$SCORE_BEFORE" != "N/A" ]]; then
    DIFF=$((SCORE_AFTER - SCORE_BEFORE))

    if [[ "$DIFF" -gt 0 ]]; then
        log "🚀 Mejora: +$DIFF puntos"
    elif [[ "$DIFF" -lt 0 ]]; then
        log "⚠️ Cambio negativo: $DIFF"
    else
        log "➖ Sin cambios"
    fi
else
    log "ℹ️ No hay score previo registrado"
fi

# =========================
# Resumen rápido
# =========================
section "Resumen"

if [[ "$SCORE_AFTER" -ge 90 ]]; then
    log "🟢 Sistema en excelente estado"
elif [[ "$SCORE_AFTER" -ge 70 ]]; then
    log "🟡 Sistema en estado aceptable"
else
    log "🔴 Sistema requiere atención"
fi

# Salida inmediata tras generación
return 0 2>/dev/null || exit 0
