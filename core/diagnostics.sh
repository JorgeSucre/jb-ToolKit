#!/bin/bash

set -Eeo pipefail
set +e  # evitar fallos por comandos informativos

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/core/utils.sh"

# Colors and STATE_FILE are inherited from core/utils.sh

# Helper para normalizar nombres de apps
normalize_app_name() {
    local app_name="$1"

    app_name=$(basename "$app_name" .app)

    echo "$app_name" \
        | tr '[:upper:]' '[:lower:]' \
        | sed 's/[[:space:]_]\+/-/g' \
        | sed 's/[^a-z0-9.-]//g' \
        | sed 's/workbench/workbench-community/g' \
        | sed 's/ledger-wallet/ledger-live/g'
}

# =========================
# Header
# =========================
echo ""
echo "========================================"
echo "   🍺 JB Toolkit Diagnostics v0.9"
echo "========================================"
echo ""

# =========================
# 🧠 Sistema
# =========================
echo "🧠 Sistema"
echo "----------------------------------------"

SCORE=$(calculate_health_score)

CPU_NAME=$(get_cpu_brand_string)
CPU_CORES=$(sysctl -n hw.physicalcpu 2>/dev/null || echo "?")
CPU="${CPU_NAME} • ${CPU_CORES} núcleos"

printf "%-15s %s\n" "CPU:" "$CPU"

# RAM unificada
TOTAL_BYTES=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
TOTAL_MB=$((TOTAL_BYTES / 1024 / 1024))
RAM_PCT=$SYS_RAM_PCT
USED_MB=$((TOTAL_MB * RAM_PCT / 100))
USED_GB=$(awk "BEGIN {printf \"%.1f\", $USED_MB/1024}")
TOTAL_GB=$(awk "BEGIN {printf \"%.0f\", $TOTAL_MB/1024}")

printf "%-15s %s%% utilizada (%sGB / %sGB)\n" "RAM:" "$RAM_PCT" "$USED_GB" "$TOTAL_GB"

# Disco (formato mejorado)
DISK=$(df -h / | awk 'NR==2 {print $4 " libres de " $2}')
DISK=$(echo "$DISK" | sed 's/Gi/GB/g; s/Ti/TB/g')
printf "%-15s %s\n" "Disco:" "$DISK"

# Uptime añadido
UPTIME=$(uptime | sed 's/.*up //; s/, [0-9]* users.*//')
UPTIME=$(echo "$UPTIME" | sed 's/^ *//')

# Normalización visual
if [[ "$UPTIME" =~ ^([0-9]+):([0-9]+)$ ]]; then
    UPTIME="${BASH_REMATCH[1]}h ${BASH_REMATCH[2]}m"
fi

printf "%-15s hace %s\n" "Uptime:" "$UPTIME"

echo ""

# =========================
# 🔥 Procesos
# =========================
echo "🔥 Procesos activos (Top 5)"
echo "----------------------------------------"
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

echo ""

# =========================
# ⚙️ Carga CPU
# =========================
echo "⚙️ Carga CPU"
echo "----------------------------------------"

CPU_LOAD=$SYS_CPU_LOAD
printf "%-15s %s\n" "Uso CPU:" "$CPU_LOAD"

# =========================
# 🌡️ Temperatura
# =========================
echo "🌡️ Temperatura"
echo "----------------------------------------"

TEMP=""

if sudo -n true 2>/dev/null; then
    TEMP=$(powermetrics --samplers smc -n 1 2>/dev/null \
        | grep -i "CPU die temperature" || true)
fi

if [[ -n "$TEMP" ]]; then
    echo "$TEMP"
else
    CPU_FREQ=$(sysctl -n hw.cpufrequency 2>/dev/null || true)

    if [[ -n "$CPU_FREQ" ]]; then
        CPU_GHZ=$(echo "$CPU_FREQ" | awk '{printf "%.2f GHz", $1/1000000000}')
        echo "Sensores térmicos no disponibles"
        echo "CPU actual: $CPU_GHZ"
    else
        if [[ "$(uname -m)" == "arm64" ]]; then
            echo "Temperatura no disponible sin permisos elevados"
        else
            echo "No disponible (requiere permisos elevados)"
        fi
    fi
fi

echo ""

# =========================
# 📊 Score del sistema
# =========================
echo "📊 Health Score"
echo "----------------------------------------"

# Usar valores ya calculados y cacheados
DISK_PCT=$SYS_DISK_PCT
CACHE_SIZE_MB=$SYS_CACHE_SIZE_MB
QUARANTINE_COUNT=$SYS_QUARANTINE_COUNT

FILLED=$((SCORE / 10))
EMPTY=$((10 - FILLED))

BAR_FILLED=""
BAR_EMPTY=""

for ((i=0; i<FILLED; i++)); do
    BAR_FILLED+="█"
done

for ((i=0; i<EMPTY; i++)); do
    BAR_EMPTY+="░"
done
SCORE_BAR="${BAR_FILLED}${BAR_EMPTY}"

if [[ "$SCORE" -ge 90 ]]; then
    SCORE_COLOR="$GREEN"
    SCORE_STATUS="Excelente"
elif [[ "$SCORE" -ge 75 ]]; then
    SCORE_COLOR="$YELLOW"
    SCORE_STATUS="Bueno"
else
    SCORE_COLOR="$RED"
    SCORE_STATUS="Requiere atención"
fi

printf "Score actual: ${SCORE_COLOR}%s %s/100${NC} (%s)\n" "$SCORE_BAR" "$SCORE" "$SCORE_STATUS"

# Guardar estado
cat > "$STATE_FILE" <<EOF
SCORE_BEFORE=$SCORE
TIMESTAMP=$(date +%Y-%m-%d_%H:%M:%S)
EOF

log "📁 Score guardado en estado"
echo ""

# =========================
# 🧠 Resumen ejecutivo
# =========================
echo ""
echo "🧠 Resumen ejecutivo"
echo "----------------------------------------"

if [[ "$SCORE" -ge 85 && "$CACHE_SIZE_MB" -lt 1500 ]]; then
    echo -e "${GREEN}• No se detectaron problemas críticos del sistema${NC}"
elif [[ "$SCORE" -ge 75 ]]; then
    echo -e "${YELLOW}• Sistema funcional con oportunidades de optimización${NC}"
else
    echo -e "${RED}• Sistema requiere mantenimiento importante${NC}"
fi

if [[ -n "$CACHE_SIZE_MB" && "$CACHE_SIZE_MB" -gt 1500 ]]; then
    echo -e "${YELLOW}• Se detectó espacio recuperable importante en cachés${NC}"
fi

if [[ "$DISK_PCT" -gt 80 ]]; then
    echo -e "${RED}• El almacenamiento comienza a estar limitado${NC}"
fi

if [[ "$DISK_PCT" -lt 70 ]]; then
    echo -e "${GREEN}• El almacenamiento tiene espacio disponible suficiente${NC}"
fi

if [[ "$CPU_INT" -lt 40 ]]; then
    echo -e "${GREEN}• No se detectó carga elevada de CPU${NC}"
fi

echo ""

# =========================
# 🧹 Recomendaciones / Próximas acciones
# =========================
echo "🧹 Recomendaciones (lo que maintenance hará)"
echo "----------------------------------------"

LOG_SIZE_MB=$(du -sm ~/Library/Logs 2>/dev/null | awk '{print $1}')
LOG_SIZE_MB=${LOG_SIZE_MB:-0}

MAINTENANCE_IMPACT=0

[[ "$CACHE_SIZE_MB" -gt 500 ]] && ((MAINTENANCE_IMPACT+=2))
[[ "$LOG_SIZE_MB" -gt 300 ]] && ((MAINTENANCE_IMPACT+=1))
[[ "$QUARANTINE_COUNT" -gt 10 ]] && ((MAINTENANCE_IMPACT+=1))
[[ "$DISK_PCT" -gt 80 ]] && ((MAINTENANCE_IMPACT+=2))

echo "🧠 Impacto estimado de Maintenance:"

if [[ "$CACHE_SIZE_MB" -gt 2000 ]]; then
    printf "${GREEN}• 🟢 Alto impacto (~%sMB recuperables detectados)${NC}\n" "$CACHE_SIZE_MB"
elif [[ "$SCORE" -ge 90 ]]; then
    printf "${GREEN}• 🟢 Impacto ligero (sistema ya optimizado)${NC}\n"
elif [[ "$MAINTENANCE_IMPACT" -ge 2 ]]; then
    printf "${YELLOW}• 🟡 Impacto medio (limpieza recomendada)${NC}\n"
else
    printf "• ⚪ Impacto bajo (sistema relativamente limpio)\n"
fi

echo ""

# 1) Cachés grandes
if [[ -n "$CACHE_SIZE_MB" && "$CACHE_SIZE_MB" -gt 200 ]]; then
    echo -e "${YELLOW}🟡 Cachés: ${CACHE_SIZE_MB} MB → se liberará espacio${NC}"
else
    echo -e "${GREEN}🟢 Cachés: sin acumulación importante${NC}"
fi

# 2) Logs grandes
if [[ -n "$LOG_SIZE_MB" && "$LOG_SIZE_MB" -gt 100 ]]; then
    echo -e "${YELLOW}🟡 Logs: ${LOG_SIZE_MB} MB → se limpiarán${NC}"
else
    echo -e "${GREEN}🟢 Logs: tamaño normal${NC}"
fi

# 3) Archivos grandes (preview ligero, sin escaneo completo)
echo "📦 Archivos grandes:"
echo "   Maintenance buscará videos, ISOs, backups y máquinas virtuales que ocupen mucho espacio"

# 5) Apps descargadas recientemente
echo ""
echo "• Apps instaladas desde internet:"

QUARANTINE_FOUND=0
QUARANTINE_TOTAL=0
QUARANTINE_SHOWN=0
BREW_CASKS=""

if brew_available; then
    BREW_CASKS=$(brew list --cask 2>/dev/null || true)
fi

while IFS= read -r app; do
    [[ -z "$app" ]] && continue

    if ! xattr -p com.apple.quarantine "$app" &>/dev/null; then
        continue
    fi

    NORMALIZED_APP=$(normalize_app_name "$app")

    if [[ -n "$BREW_CASKS" ]]; then
        if echo "$BREW_CASKS" | grep -qiE "^${NORMALIZED_APP}$"; then
            continue
        fi
    fi

    ((QUARANTINE_TOTAL++))

    if [[ "$QUARANTINE_SHOWN" -lt 8 ]]; then
        DISPLAY_NAME=$(basename "$app" .app)

        case "$DISPLAY_NAME" in
            kdenlive)
                DISPLAY_NAME="Kdenlive"
                ;;
            "Ledger Wallet")
                DISPLAY_NAME="Ledger Live"
                ;;
        esac

        echo "   - ${DISPLAY_NAME}.app"
        ((QUARANTINE_SHOWN++))
    fi

    QUARANTINE_FOUND=1
done <<< "$QUARANTINE_APPS"

if [[ "$QUARANTINE_TOTAL" -gt 8 ]]; then
    EXTRA=$((QUARANTINE_TOTAL - 8))
    echo "   (+${EXTRA} más)"
fi

if [[ "$QUARANTINE_FOUND" -eq 0 ]]; then
    echo "   (ninguna detectada)"
fi

# 6) Brew outdated
if brew_available; then
    OUTDATED=$(brew outdated --quiet 2>/dev/null || true)

    if [[ -n "$OUTDATED" ]]; then
        echo ""
        echo "• Paquetes Homebrew desactualizados:"
        echo "$OUTDATED" | head -5 | sed 's/^/   - /'
    fi
fi

echo ""
echo "👉 Ejecuta Maintenance para aplicar estos cambios"
echo ""

# =========================
# Footer
# =========================
echo "========================================"
echo "✔ Diagnóstico completado"
echo "========================================"
echo ""
