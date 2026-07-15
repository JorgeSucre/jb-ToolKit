#!/bin/bash

set -Eeuo pipefail

# Evitar ejecución duplicada en la misma sesión
if [[ "${JB_REPORT_ALREADY_RUN:-0}" == "1" ]]; then
    return 0 2>/dev/null || exit 0
fi
export JB_REPORT_ALREADY_RUN=1

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/core/utils.sh"
# Session is owned by the jb launcher.
# Only initialize a fallback session when run standalone (outside jb).


init_session
source "$BASE_DIR/core/bootstrap/ui.sh"

set_ui_context "Report"

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

_df_raw="$(df -H / 2>/dev/null | awk 'NR==2 {print $2, $3, $4, $5}')"
read -r DISK_TOTAL DISK_USED DISK_AVAIL DISK_PERCENT <<< "$_df_raw"

if [[ -n "$DISK_TOTAL" ]]; then

    DISK_TOTAL_FRIENDLY=$(echo "$DISK_TOTAL" | sed 's/G/ GB/; s/M/ MB/; s/T/ TB/')
    DISK_USED_FRIENDLY=$(echo "$DISK_USED" | sed 's/G/ GB/; s/M/ MB/; s/T/ TB/')
    DISK_AVAIL_FRIENDLY=$(echo "$DISK_AVAIL" | sed 's/G/ GB/; s/M/ MB/; s/T/ TB/')

    echo "• Capacidad total: ${DISK_TOTAL_FRIENDLY}"
    echo "• Espacio utilizado: ${DISK_USED_FRIENDLY}"
    echo "• Espacio disponible para el usuario: ${DISK_AVAIL_FRIENDLY}"
    echo "• Uso del disco: ${DISK_PERCENT}"

else
    echo "• Información no disponible"
fi

echo ""
echo "Homebrew:"

if brew_available; then

    FORMULA_COUNT=$(brew_list_formula | wc -l | tr -d ' ')
    CASK_COUNT=$(brew_list_cask | wc -l | tr -d ' ')

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

SCORE_AFTER="$(state_value SCORE_AFTER)"

echo "Score anterior: $SCORE_BEFORE"
echo "Score actual:   $SCORE_AFTER"

if [[ "$SCORE_BEFORE" =~ ^[0-9]+$ && "$SCORE_AFTER" =~ ^[0-9]+$ ]]; then
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

if [[ "$SCORE_AFTER" =~ ^[0-9]+$ && "$SCORE_AFTER" -ge 90 ]]; then
    echo "• Sistema en excelente estado"
elif [[ "$SCORE_AFTER" =~ ^[0-9]+$ && "$SCORE_AFTER" -ge 70 ]]; then
    echo "• Sistema en estado aceptable"
elif [[ "$SCORE_AFTER" =~ ^[0-9]+$ ]]; then
    echo "• Sistema requiere atención"
else
    echo "• Ejecuta Diagnostics para calcular el estado del sistema"
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

DEPLOYED_PROFILE_STATE="$(state_value DEPLOYED_PROFILE)"

if [[ "$DEPLOYED_PROFILE_STATE" != "N/A" ]]; then

    echo ""
    echo "Despliegue reciente:"
    echo "• Perfil desplegado: $DEPLOYED_PROFILE_STATE"

    LAST_DEPLOYMENT_STATE="$(state_value LAST_DEPLOYMENT)"
    DEPLOYMENT_INSTALLED_STATE="$(state_value DEPLOYMENT_APPS_INSTALLED)"
    DEPLOYMENT_FAILED_STATE="$(state_value DEPLOYMENT_APPS_FAILED)"

    if [[ "$LAST_DEPLOYMENT_STATE" != "N/A" ]]; then
        echo "• Última ejecución: $LAST_DEPLOYMENT_STATE"
    fi

    if [[ "$DEPLOYMENT_INSTALLED_STATE" != "N/A" ]]; then
        echo "• Aplicaciones instaladas: $DEPLOYMENT_INSTALLED_STATE"
    fi

    if [[ "$DEPLOYMENT_FAILED_STATE" =~ ^[0-9]+$ && "$DEPLOYMENT_FAILED_STATE" -gt 0 ]]; then
        echo "• Aplicaciones fallidas: $DEPLOYMENT_FAILED_STATE"
    fi
fi

PDF_GENERATED="false"
PDF_BASENAME=""

echo ""
if ask_yes_no "¿Generar PDF ejecutivo también?"; then
    if ! run_cmd python3 -c "import reportlab"; then
        info "ℹ️ Instalando dependencia para el reporte PDF"
        if ! run_cmd python3 -m pip install --user reportlab --quiet; then
            warn "⚠️ No se pudo instalar reportlab; el PDF se omitirá"
        fi
    fi

    if run_cmd python3 -c "import reportlab"; then
        PDF_BASENAME="jb_report_$(date '+%Y-%m-%d_%H-%M-%S').pdf"
        export JB_PDF_OUTPUT="$BASE_DIR/logs/$PDF_BASENAME"

        if run_cmd python3 "$BASE_DIR/core/report_pdf.py" \
            && [[ -f "$JB_PDF_OUTPUT" ]]; then
            PDF_GENERATED="true"
            write_state_values "LAST_PDF_REPORT=$PDF_BASENAME"
            success "✔ PDF ejecutivo generado"
        else
            warn "⚠️ No se pudo generar el PDF ejecutivo"
        fi
    fi
fi

SESSION_LOG_STATE="$(state_value LAST_SESSION_LOG)"
SNAPSHOT_STATE="$(state_value LAST_SYSTEM_SNAPSHOT)"

print_section "📁 Archivos generados"

if [[ "$PDF_GENERATED" == "true" ]]; then
    success "✔ Reporte PDF: $PDF_BASENAME"
else
    info "• Reporte PDF: no generado"
fi

if [[ "$SNAPSHOT_STATE" != "N/A" && -f "$BASE_DIR/logs/$SNAPSHOT_STATE" ]]; then
    success "✔ Inventario del sistema: $SNAPSHOT_STATE"
else
    warn "⚠️ Inventario del sistema no disponible"
fi

if [[ "$SESSION_LOG_STATE" != "N/A" && -f "$BASE_DIR/logs/$SESSION_LOG_STATE" ]]; then
    success "✔ Registro de sesión: $SESSION_LOG_STATE"
else
    warn "⚠️ Registro de sesión no disponible"
fi

echo ""
echo "Ubicación: $BASE_DIR/logs/"

print_completion "true"

# Salida inmediata tras generación
return 0 2>/dev/null || exit 0
