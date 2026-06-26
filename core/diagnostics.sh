#!/bin/bash

set -Eeo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/core/utils.sh"
# Session is owned by the jb launcher.
# Only initialize a fallback session when run standalone (outside jb).


init_session
source "$BASE_DIR/core/bootstrap/ui.sh"
source "$BASE_DIR/core/maintenance/privacy.sh"
set_ui_context "Diagnostics"

HAS_FASTFETCH="false"

if command_exists fastfetch; then
    HAS_FASTFETCH="true"
fi

# Colors and STATE_FILE are inherited from core/utils.sh

# =========================
# Header
# =========================
print_banner
echo ""
info "ℹ️ Ejecutando diagnóstico general del sistema"


# =========================
# 🖥️ Información del sistema
# =========================

if [[ "$HAS_FASTFETCH" == "true" ]]; then

    print_section "🖥️ Información del sistema"

    fastfetch --logo small --separator " → " 2>/dev/null || true

    echo ""
fi

# Ejecutar en el shell actual (sin "$(...)") para que los efectos
# secundarios de calculate_health_score (SYS_RAM_PCT, SYS_DISK_PCT,
# SYS_CPU_LOAD) sobrevivan; un subshell los descartaría y persistiría
# ceros en state.env.
calculate_health_score >/dev/null
SCORE="$SYS_HEALTH_SCORE"

CPU_LOAD=$SYS_CPU_LOAD
CPU_INT=$(echo "$CPU_LOAD" | tr -dc '0-9')
CPU_INT=${CPU_INT:-0}

# Mostrar resumen manual solo si fastfetch no existe
if [[ "$HAS_FASTFETCH" != "true" ]]; then

    # =========================
    # 🧠 Sistema
    # =========================
    print_section "🧠 Sistema"

    CPU_NAME=$(get_cpu_brand_string)
    CPU_CORES=$(sysctl -n hw.physicalcpu 2>/dev/null || echo "?")
    CPU="${CPU_NAME} • ${CPU_CORES} núcleos"

    printf "%-15s %s\n" "CPU:" "$CPU"

    TOTAL_BYTES=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
    TOTAL_MB=$((TOTAL_BYTES / 1024 / 1024))
    RAM_PCT=${SYS_RAM_PCT:-0}
    USED_MB=$((TOTAL_MB * RAM_PCT / 100))
    USED_GB=$(awk "BEGIN {printf \"%.1f\", $USED_MB/1024}")
    TOTAL_GB=$(awk "BEGIN {printf \"%.0f\", $TOTAL_MB/1024}")

    printf "%-15s %s%% utilizada (%sGB / %sGB)\n" "RAM:" "$RAM_PCT" "$USED_GB" "$TOTAL_GB"

    DISK=$(df -h / | awk 'NR==2 {print $4 " libres de " $2}')
    DISK=$(echo "$DISK" | sed 's/Gi/GB/g; s/Ti/TB/g')
    printf "%-15s %s\n" "Disco:" "$DISK"

    UPTIME=$(uptime | sed 's/.*up //; s/, [0-9]* users.*//')
    UPTIME=$(echo "$UPTIME" | sed 's/^ *//')

    if [[ "$UPTIME" =~ ^([0-9]+):([0-9]+)$ ]]; then
        UPTIME="${BASH_REMATCH[1]}h ${BASH_REMATCH[2]}m"
    fi

    printf "%-15s hace %s\n" "Uptime:" "$UPTIME"

    echo ""
fi

# =========================
# 🔥 Procesos
# =========================
print_section "🔥 Procesos con mayor consumo"
info "ℹ️ Mostrando procesos únicos con mayor uso de CPU"
echo ""
{
    ps -Ao pid,pcpu,pmem,comm \
    | grep -Ev 'kernel_task|/bin/bash|awk$|sort$|head$|grep$|ps$|diagnostics' \
    | awk '
    {
        name=$4
        sub(/^.*\//, "", name)
        key=tolower(name)

        if (!seen[key]++) {
            print
        }
    }' \
    | sort -nrk 2 \
    | head -5 \
    | awk '
    BEGIN {
        printf "%-6s %-6s %-6s %s\n", "PID", "CPU%", "MEM%", "NOMBRE"
    }
    {
        name = $4
        sub(/^.*\//, "", name)

        if (name == "") {
            name = "desconocido"
        }

        printf "%-6s %-6s %-6s %s\n", $1, $2, $3, name
    }'
} || true

echo ""

# =========================
# 📊 Score del sistema
# =========================
print_section "📊 Health Score del sistema"

# Usar valores ya calculados y cacheados
DISK_PCT=$SYS_DISK_PCT

FILLED=$(((SCORE + 5) / 10))
EMPTY=$((10 - FILLED))
[[ "$FILLED" -gt 10 ]] && FILLED=10
[[ "$EMPTY" -lt 0 ]] && EMPTY=0

BAR_FILLED=""
BAR_EMPTY=""

for ((i=0; i<FILLED; i++)); do
    BAR_FILLED+="█"
done

for ((i=0; i<EMPTY; i++)); do
    BAR_EMPTY+="░"
done
SCORE_BAR="${BAR_FILLED}${BAR_EMPTY}"

if [[ "$SCORE" -ge 95 ]]; then
    SCORE_COLOR="$GREEN"
    SCORE_STATUS="Excelente"
elif [[ "$SCORE" -ge 85 ]]; then
    SCORE_COLOR="$GREEN"
    SCORE_STATUS="Muy bueno"
elif [[ "$SCORE" -ge 70 ]]; then
    SCORE_COLOR="$YELLOW"
    SCORE_STATUS="Bueno"
else
    SCORE_COLOR="$RED"
    SCORE_STATUS="Requiere atención"
fi

printf "Estado actual: ${SCORE_COLOR}%s %s/100${NC} (%s)\n" "$SCORE_BAR" "$SCORE" "$SCORE_STATUS"

# =========================
# 🔒 Privacidad y seguridad
# =========================
# Detection only — never enables/disables FileVault, never modifies the
# vendor services privacy.sh looks for. Computed once here so Report and
# the PDF only ever read state.env instead of re-running detection
# (AGENTS.md §6: prefer state.env over recalculation).
print_section "🔒 Privacidad y seguridad"

FILEVAULT_STATUS="$(detect_filevault_status)"

case "$FILEVAULT_STATUS" in
    Enabled) success "✔ FileVault: Enabled" ;;
    Disabled) warn "⚠️ FileVault: Disabled" ;;
    *) info "ℹ️ FileVault: Unknown" ;;
esac

echo ""
echo "Inventario de privacidad (solo detección):"

PRIVACY_INVENTORY=""
for _privacy_pair in \
    "Google Keystone|$(detect_google_keystone)" \
    "Microsoft Office|$(detect_microsoft_office_telemetry)" \
    "Adobe|$(detect_adobe_telemetry)" \
    "Zoom|$(detect_zoom_analytics)"; do

    _privacy_label="${_privacy_pair%%|*}"
    _privacy_matches="${_privacy_pair#*|}"

    if [[ -n "$_privacy_matches" ]]; then
        _privacy_state="Detected"
        warn "⚠️ ${_privacy_label}: Detected"
    else
        _privacy_state="Not Detected"
        success "✔ ${_privacy_label}: Not Detected"
    fi

    PRIVACY_INVENTORY+="${_privacy_label}|${_privacy_state};;"
done
PRIVACY_INVENTORY="${PRIVACY_INVENTORY%;;}"

echo ""

# Guardar solo métricas de diagnóstico; preservar resultados de mantenimiento.
write_state_values \
    "SCORE_BEFORE=$SCORE" \
    "SCORE_AFTER=$SCORE" \
    "TIMESTAMP=$(date +%Y-%m-%d_%H:%M:%S)" \
    "LAST_DIAGNOSTIC=$(date +%Y-%m-%d_%H:%M:%S)" \
    "LAST_MODULE=diagnostics" \
    "ARCH=$(uname -m)" \
    "JB_VERSION=$JB_VERSION" \
    "CPU_LOAD=$SYS_CPU_LOAD" \
    "RAM_USED_PCT=$SYS_RAM_PCT" \
    "DISK_USED_PCT=$SYS_DISK_PCT" \
    "FILEVAULT_STATUS=$FILEVAULT_STATUS" \
    "PRIVACY_INVENTORY=$PRIVACY_INVENTORY"

info "📁 Estado del diagnóstico guardado correctamente"
echo ""

# =========================
# 🌐 Velocidad de internet (opcional — nunca automático)
# =========================
# Uses networkQuality, built into macOS since Big Sur — no new
# dependency. Never runs without asking first; if a result is already
# in state.env it's shown and re-running is offered, not assumed.
print_section "🌐 Velocidad de internet"

run_internet_speed_test() {
    command_exists networkQuality || return 1

    local json dl_bps ul_bps rtt_ms

    json="$(networkQuality -c 2>/dev/null)"
    [[ -z "$json" ]] && return 1

    dl_bps=$(echo "$json" | grep '"dl_throughput"' | head -1 | awk -F': ' '{print $2}' | tr -d ',')
    ul_bps=$(echo "$json" | grep '"ul_throughput"' | head -1 | awk -F': ' '{print $2}' | tr -d ',')
    rtt_ms=$(echo "$json" | grep '"base_rtt"' | head -1 | awk -F': ' '{print $2}' | tr -d ',')

    [[ -z "$dl_bps" || -z "$ul_bps" ]] && return 1

    NETWORK_DOWNLOAD_MBPS=$(awk -v b="$dl_bps" 'BEGIN{printf "%.1f", b/1000000}')
    NETWORK_UPLOAD_MBPS=$(awk -v b="$ul_bps" 'BEGIN{printf "%.1f", b/1000000}')
    NETWORK_LATENCY_MS=$(awk -v r="${rtt_ms:-0}" 'BEGIN{printf "%.0f", r}')

    return 0
}

EXISTING_DOWNLOAD="$(state_value NETWORK_DOWNLOAD_MBPS)"
RUN_SPEED_TEST="false"

if [[ "$EXISTING_DOWNLOAD" != "N/A" ]]; then
    info "ℹ️ Último resultado disponible ($(state_value NETWORK_SPEED_TIMESTAMP)): ${EXISTING_DOWNLOAD} Mbps ↓ / $(state_value NETWORK_UPLOAD_MBPS) Mbps ↑ / $(state_value NETWORK_LATENCY_MS) ms"
    if ask_yes_no "¿Deseas volver a ejecutar la prueba de velocidad?"; then
        RUN_SPEED_TEST="true"
    fi
elif ask_yes_no "¿Deseas ejecutar una prueba de velocidad de internet? (opcional, ~10-20s)"; then
    RUN_SPEED_TEST="true"
fi

if [[ "$RUN_SPEED_TEST" == "true" ]]; then
    info "ℹ️ Ejecutando prueba de velocidad..."
    if run_internet_speed_test; then
        success "✔ Descarga: ${NETWORK_DOWNLOAD_MBPS} Mbps · Subida: ${NETWORK_UPLOAD_MBPS} Mbps · Latencia: ${NETWORK_LATENCY_MS} ms"
        write_state_values \
            "NETWORK_DOWNLOAD_MBPS=$NETWORK_DOWNLOAD_MBPS" \
            "NETWORK_UPLOAD_MBPS=$NETWORK_UPLOAD_MBPS" \
            "NETWORK_LATENCY_MS=$NETWORK_LATENCY_MS" \
            "NETWORK_SPEED_TIMESTAMP=$(date +%Y-%m-%d_%H:%M:%S)"
    else
        warn "⚠️ No se pudo completar la prueba de velocidad"
    fi
fi
echo ""

# =========================
# 🧠 Resumen ejecutivo
# =========================
print_section "🧠 Resumen ejecutivo"

info "ℹ️ Evaluación rápida del estado actual del sistema"
echo ""

if [[ "$SCORE" -ge 85 ]]; then
    success "• No se detectaron problemas críticos del sistema"
elif [[ "$SCORE" -ge 70 ]]; then
    warn "• Sistema funcional con oportunidades de optimización"
else
    error "• Sistema requiere mantenimiento importante"
fi

if [[ "$DISK_PCT" -gt 80 ]]; then
    error "• El almacenamiento comienza a estar limitado"
elif [[ "$DISK_PCT" -lt 70 ]]; then
    success "• El almacenamiento tiene espacio disponible suficiente"
fi

if [[ "$CPU_INT" -lt 40 ]]; then
    success "• No se detectó carga elevada de CPU"
elif [[ "$CPU_INT" -lt 75 ]]; then
    warn "• Se detectó carga moderada de CPU"
else
    error "• Se detectó carga elevada de CPU"
fi

echo ""

# =========================
# 💡 Próximo paso recomendado
# =========================
print_section "💡 Próximo paso recomendado"

echo "Maintenance puede ayudarte a:"
echo "• Liberar espacio eliminando cachés y logs innecesarios"
echo "• Detectar aplicaciones potencialmente olvidadas"
echo "• Revisar almacenamiento y consumo del sistema"
echo "• Aplicar optimizaciones generales de mantenimiento"

echo ""
echo "👉 Ejecuta Maintenance para aplicar optimizaciones recomendadas"
echo ""

# =========================
# Footer
# =========================
print_completion "true"
