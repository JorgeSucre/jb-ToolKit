#!/bin/bash

set -Eeo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/core/utils.sh"
# Session is owned by the jb launcher.
# Only initialize a fallback session when run standalone (outside jb).


init_session
source "$BASE_DIR/core/bootstrap/ui.sh"
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

SCORE=$(calculate_health_score)

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

# Guardar solo métricas de diagnóstico; preservar resultados de mantenimiento.
write_state_values \
    "SCORE_BEFORE=$SCORE" \
    "SCORE_AFTER=$SCORE" \
    "TIMESTAMP=$(date +%Y-%m-%d_%H:%M:%S)" \
    "LAST_DIAGNOSTIC=$(date +%Y-%m-%d_%H:%M:%S)" \
    "LAST_MODULE=diagnostics" \
    "ARCH=$(uname -m)" \
    "JB_VERSION=0.9" \
    "CPU_LOAD=$SYS_CPU_LOAD" \
    "RAM_USED_PCT=$SYS_RAM_PCT" \
    "DISK_USED_PCT=$SYS_DISK_PCT"

info "📁 Estado del diagnóstico guardado correctamente"
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
