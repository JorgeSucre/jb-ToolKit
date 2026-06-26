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

# Needed for the app-inventory sections below (hardware recommendations +
# the optional-app catalog used by detect_app_state/package_label_for) —
# sourced once here instead of inside the PDF block so the console report
# can show the same data even when the user declines the PDF.
declare -f compute_hardware_recommendations >/dev/null 2>&1 \
    || source "$BASE_DIR/core/bootstrap/hardware.sh"
declare -f compute_hardware_recommendations >/dev/null 2>&1 \
    || source "$BASE_DIR/core/bootstrap/packages.sh"

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
# TODO(architecture): this recalculates RAM live via sysctl/memory_pressure/
# vm_stat instead of consuming state_value RAM_USED_PCT (written by
# Diagnostics — see core/diagnostics.sh and AGENTS.md §6). That key is now
# correctly populated after the subshell fix in calculate_health_score, so
# it's safe to prefer here, but only when fresh (state.env may be N/A or
# stale if Report runs without a recent Diagnostics pass — e.g. right after
# Maintenance). Needs an explicit "prefer state.env, fall back to live query"
# guard like report_pdf.py already has (see its RAM section) rather than an
# unconditional swap — left as a follow-up, not done here to stay in scope.
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
# TODO(architecture): same issue as the RAM block above — recalculates via
# df -H instead of consuming state_value DISK_USED_PCT. See note above.

DISK_INFO=$(df -H / 2>/dev/null | tail -1)

if [[ -n "$DISK_INFO" ]]; then

    DISK_TOTAL=$(echo "$DISK_INFO" | awk '{print $2}')
    DISK_USED=$(echo "$DISK_INFO" | awk '{print $3}')
    DISK_AVAIL=$(echo "$DISK_INFO" | awk '{print $4}')
    DISK_PERCENT=$(echo "$DISK_INFO" | awk '{print $5}')

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

# =========================
# Aplicaciones recomendadas (Homebrew vs. manual vs. no instalada)
# =========================
# Reuses the same detection engine Bootstrap uses (detect_app_state via
# compute_hardware_recommendations) — never re-implemented here. Wording
# stays honest: manual installs are never described as "updated" or
# "actualizado", since Homebrew has no version visibility into them.
compute_hardware_recommendations

APP_INVENTORY=""
for ((i=0; i<${#HARDWARE_RECOMMENDED_IDS[@]}; i++)); do
    pkg="${HARDWARE_RECOMMENDED_IDS[$i]}"
    label="${HARDWARE_RECOMMENDED_LABELS[$i]}"
    bundle="$(package_app_bundle_name "$pkg")"
    full_state="$(detect_app_state "$pkg" "$bundle" 2>/dev/null || echo not_installed:none)"
    APP_INVENTORY+="${label}|${full_state}"$'\n'
done
export JB_APP_INVENTORY="$APP_INVENTORY"

if [[ -n "${APP_INVENTORY//$'\n'/}" ]]; then
    echo ""
    section "Aplicaciones recomendadas"

    while IFS='|' read -r label full_state; do
        [[ -z "$label" ]] && continue
        state="${full_state%%:*}"
        method="${full_state##*:}"

        case "$state" in
            installed)
                if [[ "$method" == "manual" ]]; then
                    echo "⚠ $label (Instalación manual)"
                elif [[ "$method" == "app-store" ]]; then
                    echo "✓ $label (App Store)"
                else
                    echo "✓ $label (Homebrew)"
                fi
                ;;
            update)
                echo "✓ $label (Homebrew, actualización disponible)"
                ;;
            *)
                echo "✗ $label (No instalada)"
                ;;
        esac
    done <<< "$APP_INVENTORY"
fi

# =========================
# Software instalado durante esta sesión (Bootstrap)
# =========================
# INSTALLED_APPS_SESSION is written once per Bootstrap run (see
# bootstrap.sh) and only ever contains packages that transitioned from
# not-installed to installed/updated during that run — never
# already-installed or failed packages.
INSTALLED_APPS_SESSION_STATE="$(state_value INSTALLED_APPS_SESSION)"
INSTALLED_SESSION_LABELS=""

if [[ "$INSTALLED_APPS_SESSION_STATE" != "N/A" && -n "$INSTALLED_APPS_SESSION_STATE" ]]; then
    IFS=',' read -ra _installed_session_ids <<< "$INSTALLED_APPS_SESSION_STATE"
    for pkg in "${_installed_session_ids[@]}"; do
        [[ -z "$pkg" ]] && continue
        INSTALLED_SESSION_LABELS+="$(package_label_for "$pkg")"$'\n'
    done
fi
export JB_INSTALLED_APPS_SESSION="$INSTALLED_SESSION_LABELS"

if [[ -n "${INSTALLED_SESSION_LABELS//$'\n'/}" ]]; then
    echo ""
    section "Software instalado durante esta sesión"

    while IFS= read -r label; do
        [[ -z "$label" ]] && continue
        echo "✓ $label"
    done <<< "$INSTALLED_SESSION_LABELS"
fi

# =========================
# Historial reciente de mantenimiento
# =========================
# Reads core/maintenance/state.sh's flat history file directly (same
# pattern as state_value reading state.env) — Report never sources
# maintenance modules or recalculates anything, it only displays the last
# 5 lines someone else already wrote.
MAINTENANCE_HISTORY_FILE="$BASE_DIR/logs/maintenance_history.log"

if [[ -f "$MAINTENANCE_HISTORY_FILE" && -s "$MAINTENANCE_HISTORY_FILE" ]]; then
    echo ""
    section "Historial reciente de mantenimiento"

    while IFS='|' read -r hist_timestamp hist_profile hist_score; do
        [[ -z "$hist_timestamp" ]] && continue
        printf "• %s — perfil: %s — score: %s\n" "$hist_timestamp" "$hist_profile" "$hist_score"
    done < <(tail -r "$MAINTENANCE_HISTORY_FILE" 2>/dev/null | head -n 5)
fi

# =========================
# Privacy Inventory (read state.env — written once by Diagnostics)
# =========================
# Never re-runs detection here — see AGENTS.md §6. FILEVAULT_STATUS and
# PRIVACY_INVENTORY are both written by core/diagnostics.sh in one place;
# Report only ever displays them and bridges them to the PDF.
FILEVAULT_STATUS_STATE="$(state_value FILEVAULT_STATUS)"
PRIVACY_INVENTORY_STATE="$(state_value PRIVACY_INVENTORY)"

JB_PRIVACY_INVENTORY=""
if [[ "$PRIVACY_INVENTORY_STATE" != "N/A" && -n "$PRIVACY_INVENTORY_STATE" ]]; then
    JB_PRIVACY_INVENTORY="$(printf '%s' "$PRIVACY_INVENTORY_STATE" | tr ';;' '\n')"
fi
export JB_PRIVACY_INVENTORY
export JB_FILEVAULT_STATUS="$FILEVAULT_STATUS_STATE"

if [[ "$FILEVAULT_STATUS_STATE" != "N/A" || -n "$JB_PRIVACY_INVENTORY" ]]; then
    echo ""
    section "Privacy Inventory"

    if [[ "$FILEVAULT_STATUS_STATE" != "N/A" ]]; then
        echo "FileVault: $FILEVAULT_STATUS_STATE"
        echo ""
    fi

    if [[ -n "$JB_PRIVACY_INVENTORY" ]]; then
        while IFS='|' read -r priv_label priv_state; do
            [[ -z "$priv_label" ]] && continue
            echo "${priv_label}: ${priv_state}"
        done <<< "$JB_PRIVACY_INVENTORY"
    fi
fi

# =========================
# Velocidad de internet (read state.env — written once by Diagnostics)
# =========================
# Never re-runs the speed test here; if Diagnostics hasn't run one yet,
# this section is simply omitted.
NETWORK_DOWNLOAD_STATE="$(state_value NETWORK_DOWNLOAD_MBPS)"
NETWORK_UPLOAD_STATE="$(state_value NETWORK_UPLOAD_MBPS)"
NETWORK_LATENCY_STATE="$(state_value NETWORK_LATENCY_MS)"
NETWORK_SPEED_TIMESTAMP_STATE="$(state_value NETWORK_SPEED_TIMESTAMP)"

export JB_NETWORK_DOWNLOAD="$NETWORK_DOWNLOAD_STATE"
export JB_NETWORK_UPLOAD="$NETWORK_UPLOAD_STATE"
export JB_NETWORK_LATENCY="$NETWORK_LATENCY_STATE"

if [[ "$NETWORK_DOWNLOAD_STATE" != "N/A" ]]; then
    echo ""
    section "Velocidad de internet"
    echo "Descarga: ${NETWORK_DOWNLOAD_STATE} Mbps"
    echo "Subida: ${NETWORK_UPLOAD_STATE} Mbps"
    echo "Latencia: ${NETWORK_LATENCY_STATE} ms"
    echo "Medido: ${NETWORK_SPEED_TIMESTAMP_STATE}"
fi

# =========================
# Overall Recommendation (Executive Recommendations)
# =========================
# Pure synthesis of values already read above (or already in state.env) —
# no new detection, no recalculation. Each candidate has a fixed priority
# weight; only the top 5 are ever shown, highest weight first, so the
# technician is never overwhelmed. The star rating reflects the single
# highest weight among the candidates that actually applied.
STALE_APPS_COUNT_STATE="$(state_value STALE_APPS_COUNT)"

OUTDATED_BREW_COUNT=0
if brew_available; then
    OUTDATED_BREW_COUNT=$(
        { brew outdated --formula 2>/dev/null; brew outdated --cask 2>/dev/null; } \
            | sed '/^$/d' | wc -l | tr -d ' '
    )
fi

RECOMMENDATIONS=""

add_recommendation() {
    # weight|text
    RECOMMENDATIONS+="$1|$2"$'\n'
}

DISK_USED_PCT_STATE="$(state_value DISK_USED_PCT)"
RAM_USED_PCT_STATE="$(state_value RAM_USED_PCT)"

if [[ "$DISK_USED_PCT_STATE" =~ ^[0-9]+$ && "$DISK_USED_PCT_STATE" -ge 90 ]]; then
    add_recommendation 90 "Liberar espacio en disco (uso actual: ${DISK_USED_PCT_STATE}%)"
elif [[ "$DISK_USED_PCT_STATE" =~ ^[0-9]+$ && "$DISK_USED_PCT_STATE" -ge 80 ]]; then
    add_recommendation 70 "Revisar uso de almacenamiento (uso actual: ${DISK_USED_PCT_STATE}%)"
fi

if [[ "$FILEVAULT_STATUS_STATE" == "Disabled" ]]; then
    add_recommendation 85 "Enable FileVault"
fi

if [[ "$SCORE_AFTER" =~ ^[0-9]+$ && "$SCORE_AFTER" -lt 70 ]]; then
    add_recommendation 75 "Realizar mantenimiento general (score actual: ${SCORE_AFTER}/100)"
fi

if [[ "$STALE_APPS_COUNT_STATE" =~ ^[0-9]+$ && "$STALE_APPS_COUNT_STATE" -gt 0 ]]; then
    add_recommendation 55 "Eliminar aplicaciones grandes inactivas (${STALE_APPS_COUNT_STATE} detectadas)"
fi

if [[ "$RAM_USED_PCT_STATE" =~ ^[0-9]+$ && "$RAM_USED_PCT_STATE" -ge 85 ]]; then
    add_recommendation 60 "Considerar ampliar memoria RAM (uso actual: ${RAM_USED_PCT_STATE}%)"
fi

if echo "$JB_PRIVACY_INVENTORY" | grep -q "|Detected$"; then
    add_recommendation 50 "Revisar servicios de actualización/telemetría detectados"
fi

if [[ "$OUTDATED_BREW_COUNT" -gt 0 ]]; then
    add_recommendation 40 "Actualizar paquetes de Homebrew disponibles (${OUTDATED_BREW_COUNT})"
fi

if [[ "$LAST_MAINTENANCE" == "N/A" ]]; then
    add_recommendation 45 "Ejecutar Maintenance — aún no se ha realizado en este equipo"
elif [[ "$PERFORMANCE_PROFILE_STATE" == "N/A" || "$PERFORMANCE_PROFILE_STATE" == "none" ]]; then
    add_recommendation 20 "Revisar aplicaciones de inicio"
fi

RECOMMENDATIONS="$(printf '%s' "$RECOMMENDATIONS" | sed '/^$/d' | sort -t'|' -k1 -nr | head -n 5)"
export JB_RECOMMENDATIONS="$RECOMMENDATIONS"

if [[ -n "$RECOMMENDATIONS" ]]; then
    TOP_WEIGHT="$(printf '%s\n' "$RECOMMENDATIONS" | head -1 | cut -d'|' -f1)"

    if [[ "$TOP_WEIGHT" -ge 80 ]]; then
        STARS="★★★★★"
        PRIORITY_LEVEL=5
    elif [[ "$TOP_WEIGHT" -ge 60 ]]; then
        STARS="★★★★☆"
        PRIORITY_LEVEL=4
    elif [[ "$TOP_WEIGHT" -ge 40 ]]; then
        STARS="★★★☆☆"
        PRIORITY_LEVEL=3
    elif [[ "$TOP_WEIGHT" -ge 20 ]]; then
        STARS="★★☆☆☆"
        PRIORITY_LEVEL=2
    else
        STARS="★☆☆☆☆"
        PRIORITY_LEVEL=1
    fi
    export JB_RECOMMENDATIONS_STARS="$STARS"
    export JB_RECOMMENDATIONS_PRIORITY="$PRIORITY_LEVEL"

    echo ""
    section "Overall Recommendation"
    echo "Priority: $STARS"
    echo ""
    echo "Recommended actions:"
    echo ""
    while IFS='|' read -r rec_weight rec_text; do
        [[ -z "$rec_text" ]] && continue
        echo "• $rec_text"
    done <<< "$RECOMMENDATIONS"
fi

PDF_GENERATED="false"
PDF_BASENAME=""

echo ""
if ask_yes_no "¿Generar PDF ejecutivo también?"; then
    # Usa un entorno virtual propio del toolkit (core/utils.sh) en vez de
    # python3/pip del sistema u Homebrew: evita el bloqueo PEP 668
    # "externally-managed-environment" al instalar reportlab.
    info "ℹ️ Preparando entorno Python para el reporte PDF"
    if ! ensure_pdf_python; then
        warn "⚠️ No se pudo preparar reportlab; el PDF se omitirá"
    fi

    if [[ -n "$JB_PDF_PYTHON" ]]; then
        PDF_BASENAME="jb_report_$(date '+%Y-%m-%d_%H-%M-%S').pdf"
        export JB_PDF_OUTPUT="$BASE_DIR/logs/$PDF_BASENAME"

        if run_cmd "$JB_PDF_PYTHON" "$BASE_DIR/core/report_pdf.py" \
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

# =========================
# Support Bundle (v1.1)
# =========================
# Zips up exactly the artifacts a technician would otherwise have to
# attach one by one when asking for help: the session log, state.env,
# the system snapshot, and the report PDF if one is available (the one
# just generated, or the last one on record). Read-only — only ever
# reads existing files and writes a new zip under logs/; never modifies
# any of the source files.
echo ""
if ask_yes_no "¿Generar paquete de soporte (ZIP) con los archivos de esta sesión?"; then
    SUPPORT_BUNDLE_NAME="jb_support_bundle_$(date '+%Y-%m-%d_%H-%M-%S').zip"
    SUPPORT_BUNDLE_PATH="$BASE_DIR/logs/$SUPPORT_BUNDLE_NAME"

    SUPPORT_BUNDLE_PDF=""
    if [[ "$PDF_GENERATED" == "true" ]]; then
        SUPPORT_BUNDLE_PDF="$BASE_DIR/logs/$PDF_BASENAME"
    else
        LAST_PDF_STATE="$(state_value LAST_PDF_REPORT)"
        if [[ "$LAST_PDF_STATE" != "N/A" && -f "$BASE_DIR/logs/$LAST_PDF_STATE" ]]; then
            SUPPORT_BUNDLE_PDF="$BASE_DIR/logs/$LAST_PDF_STATE"
        fi
    fi

    SUPPORT_BUNDLE_FILES=()
    [[ -f "$BASE_DIR/logs/$SESSION_LOG_STATE" ]] && SUPPORT_BUNDLE_FILES+=("$BASE_DIR/logs/$SESSION_LOG_STATE")
    [[ -f "$BASE_DIR/logs/$SNAPSHOT_STATE" ]] && SUPPORT_BUNDLE_FILES+=("$BASE_DIR/logs/$SNAPSHOT_STATE")
    [[ -f "$STATE_FILE" ]] && SUPPORT_BUNDLE_FILES+=("$STATE_FILE")
    [[ -n "$SUPPORT_BUNDLE_PDF" ]] && SUPPORT_BUNDLE_FILES+=("$SUPPORT_BUNDLE_PDF")

    if [[ "${#SUPPORT_BUNDLE_FILES[@]}" -eq 0 ]]; then
        warn "⚠️ No hay archivos disponibles para el paquete de soporte"
    elif command_exists zip \
        && run_cmd zip -j "$SUPPORT_BUNDLE_PATH" "${SUPPORT_BUNDLE_FILES[@]}" \
        && [[ -f "$SUPPORT_BUNDLE_PATH" ]]; then
        success "✔ Paquete de soporte generado: $SUPPORT_BUNDLE_NAME"
    else
        warn "⚠️ No se pudo generar el paquete de soporte"
    fi
fi

print_completion "true"

# Salida inmediata tras generación
return 0 2>/dev/null || exit 0
