#!/bin/bash

# =========================
# Base Config & Directories
# =========================
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export BASE_DIR
export STATE_FILE="$BASE_DIR/logs/state.env"
mkdir -p "$BASE_DIR/logs" 2>/dev/null || true

# =========================
# ANSI Colors (Interactive only)
# =========================
if [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    GREEN=''
    YELLOW=''
    RED=''
    BLUE=''
    NC=''
fi
export GREEN YELLOW RED BLUE NC

# =========================
# Global System Metrics Cache
# =========================
SYS_RAM_PCT=0
SYS_DISK_PCT=0
SYS_CPU_LOAD="0%"
SYS_CACHE_SIZE_MB=0
SYS_QUARANTINE_COUNT=0

get_cpu_brand_string() {
    local cpu
    cpu="$(sysctl -n hw.brand_string 2>/dev/null || sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "No disponible")"
    echo "$cpu"
}

calculate_health_score() {
    local cpu_load cpu_int ram_pct disk_pct cache_size_mb quarantine_count score=100

    # Uso CPU
    cpu_load=$(top -l 1 | awk '/CPU usage/ {printf "%d%%", ($3 + $5)}' 2>/dev/null)
    cpu_load=${cpu_load:-0%}
    cpu_int=$(echo "$cpu_load" | tr -d '%' | cut -d'.' -f1)
    cpu_int=${cpu_int:-0}

    # RAM (estimación realista para macOS)
    local total_bytes total_mb mem_pressure free_pages spec_pages free_mb used_mb
    total_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
    total_mb=$((total_bytes / 1024 / 1024))
    mem_pressure=$(memory_pressure 2>/dev/null \
        | awk -F': ' '/System-wide memory free percentage/ {print $2}' \
        | tr -d '%' 2>/dev/null)

    if [[ -z "$mem_pressure" ]]; then
        free_pages=$(vm_stat 2>/dev/null | awk '/Pages free/ {print $3}' | tr -d '.')
        spec_pages=$(vm_stat 2>/dev/null | awk '/Pages speculative/ {print $3}' | tr -d '.')
        free_pages=${free_pages:-0}
        spec_pages=${spec_pages:-0}
        free_mb=$(((free_pages + spec_pages) * 4096 / 1024 / 1024))
        if [[ "$total_mb" -gt 0 ]]; then
            mem_pressure=$((100 - (free_mb * 100 / total_mb)))
        else
            mem_pressure=0
        fi
    fi

    used_mb=$((total_mb * (100 - mem_pressure) / 100))
    if [[ "$total_mb" -gt 0 ]]; then
        ram_pct=$((used_mb * 100 / total_mb))
    else
        ram_pct=0
    fi

    # Disco
    disk_pct=$(df -h / 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
    disk_pct=${disk_pct:-0}

    # Caches
    cache_size_mb=$(du -sm ~/Library/Caches 2>/dev/null | awk '{print $1}')
    cache_size_mb=${cache_size_mb:-0}

    # Apps com.apple.quarantine
    local quarantine_apps
    quarantine_apps=$(find /Applications -maxdepth 1 -type d -name "*.app" 2>/dev/null)
    if [[ -n "$quarantine_apps" ]]; then
        quarantine_count=$(echo "$quarantine_apps" \
            | while read -r app; do
                [[ -n "$app" ]] && xattr -p com.apple.quarantine "$app" &>/dev/null && echo 1
              done | wc -l | tr -d ' ')
    fi

    # Deducciones de Score
    # RAM
    if [[ "$ram_pct" -gt 85 ]]; then
        score=$((score - 25))
    elif [[ "$ram_pct" -gt 70 ]]; then
        score=$((score - 10))
    fi

    # Disco
    if [[ "$disk_pct" -gt 90 ]]; then
        score=$((score - 25))
    elif [[ "$disk_pct" -gt 80 ]]; then
        score=$((score - 10))
    fi

    # CPU
    if [[ "$cpu_int" -gt 80 ]]; then
        score=$((score - 15))
    elif [[ "$cpu_int" -gt 50 ]]; then
        score=$((score - 5))
    fi

    # Cachés grandes
    if [[ "$cache_size_mb" -gt 3000 ]]; then
        score=$((score - 20))
    elif [[ "$cache_size_mb" -gt 2000 ]]; then
        score=$((score - 15))
    elif [[ "$cache_size_mb" -gt 1000 ]]; then
        score=$((score - 8))
    fi

    # Quarantine
    if [[ "$quarantine_count" -gt 15 ]]; then
        score=$((score - 10))
    elif [[ "$quarantine_count" -gt 8 ]]; then
        score=$((score - 5))
    fi

    # Evitar negativos
    if [[ "$score" -lt 0 ]]; then
        score=0
    fi

    # Cachear métricas para uso del script invocante
    SYS_RAM_PCT=$ram_pct
    SYS_DISK_PCT=$disk_pct
    SYS_CPU_LOAD=$cpu_load
    SYS_CACHE_SIZE_MB=$cache_size_mb
    SYS_QUARANTINE_COUNT=$quarantine_count

    echo "$score"
}

HARDWARE_MODEL=""
HARDWARE_NAME=""
BREW_BIN=""

load_hardware_info() {
    [[ -n "$HARDWARE_MODEL" && -n "$HARDWARE_NAME" ]] && return


    HARDWARE_MODEL="$(sysctl -n hw.model 2>/dev/null || echo Unknown)"
    HARDWARE_NAME="$(system_profiler SPHardwareDataType -detailLevel mini 2>/dev/null \
        | awk -F ": " '/Model Name/ {print $2; exit}' || true)"

    if [[ -z "$HARDWARE_NAME" ]]; then
        HARDWARE_NAME="$HARDWARE_MODEL"
    fi
}

log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

brew_bin() {
    if [[ -n "$BREW_BIN" && -x "$BREW_BIN" ]]; then
        printf "%s\n" "$BREW_BIN"
        return 0
    fi

    if command -v brew >/dev/null 2>&1; then
        BREW_BIN="$(command -v brew)"
    elif [[ -x "/opt/homebrew/bin/brew" ]]; then
        BREW_BIN="/opt/homebrew/bin/brew"
    elif [[ -x "/usr/local/bin/brew" ]]; then
        BREW_BIN="/usr/local/bin/brew"
    else
        return 1
    fi

    printf "%s\n" "$BREW_BIN"
}

ensure_brew_path() {
    local bin
    bin="$(brew_bin 2>/dev/null)" || return 1

    export PATH="$(dirname "$bin"):$PATH"
}

brew_available() {
    ensure_brew_path || return 1
    brew --version >/dev/null 2>&1 || return 1
    return 0
}

brew_prefix_safe() {
    ensure_brew_path || return 1
    brew --prefix 2>/dev/null
}

retry() {
    local retries=$1 delay=$2; shift 2
    local cmd=("$@")

    for ((i=1;i<=retries;i++)); do
        "${cmd[@]}" && return 0
        log "⚠️ Intento $i/$retries falló"
        sleep "$delay"
    done
    return 1
}

section() {
    echo ""
    echo "=============================="
    echo " $1"
    echo "=============================="
}

command_exists() {
    command -v "$1" &>/dev/null
}

# =========================
# Hardware Detection
# =========================

get_arch() {
    local arch
    arch="$(uname -m)"
    case "$arch" in
        arm64) echo "apple_silicon" ;;
        x86_64) echo "intel" ;;
        *) echo "unknown" ;;
    esac
}

is_laptop() {
    load_hardware_info
    echo "$HARDWARE_NAME" | grep -qi "MacBook"
}

has_battery() {
    pmset -g batt 2>/dev/null | grep -q "InternalBattery"
}

has_fan() {
    load_hardware_info
    # Modelos conocidos SIN ventilador
    if echo "$HARDWARE_NAME" | grep -Eqi "MacBook \(Retina, 12-inch"; then
        return 1
    fi

    # Desktops normalmente tienen ventilador
    if echo "$HARDWARE_NAME" | grep -Eqi "Mac mini|iMac|Mac Studio|Mac Pro"; then
        return 0
    fi

    # MacBook Pro siempre tiene ventilador
    if echo "$HARDWARE_NAME" | grep -qi "MacBook Pro"; then
        return 0
    fi

    # Fallback: sensores/reportes del sistema
    if system_profiler SPPowerDataType -detailLevel mini 2>/dev/null | grep -Eqi "fan|rpm"; then
        return 0
    fi

    return 1
}

get_device_profile() {
    load_hardware_info
    local arch type battery fan

    arch="$(get_arch)"

    if is_laptop; then
        type="laptop"
    else
        type="desktop"
    fi

    if has_battery; then
        battery="yes"
    else
        battery="no"
    fi

    if has_fan; then
        fan="yes"
    else
        fan="no"
    fi

    # Normalización: laptops siempre tienen batería
    if [[ "$type" == "laptop" ]]; then
        battery="yes"
    fi

    echo "MODEL_NAME=$HARDWARE_NAME"
    echo "MODEL_ID=$HARDWARE_MODEL"
    echo "ARCH=$arch"
    echo "TYPE=$type"
    echo "BATTERY=$battery"
    echo "FAN=$fan"
}

# =========================
# Apps Diagnostics
# =========================

is_app_executable() {
    local app_path="$1"
    local exec_bin

    exec_bin=$(defaults read "$app_path/Contents/Info" CFBundleExecutable 2>/dev/null || true)

    if [[ -z "$exec_bin" ]]; then
        return 1
    fi

    if [[ -x "$app_path/Contents/MacOS/$exec_bin" ]]; then
        return 0
    fi

    return 1
}

is_app_32bit() {
    local app_path="$1"
    local exec_bin

    exec_bin=$(defaults read "$app_path/Contents/Info" CFBundleExecutable 2>/dev/null || true)

    if [[ -z "$exec_bin" ]]; then
        return 1
    fi

    file "$app_path/Contents/MacOS/$exec_bin" 2>/dev/null | grep -qi "Mach-O.*i386"
}

scan_apps() {
    if [[ "${ENABLE_APP_SCAN:-false}" != "true" ]]; then
        return 0
    fi

    local base_dirs=("/Applications" "$HOME/Applications")
    local app app_name size last_used last_used_epoch now_epoch diff_days
    local old_apps=0 broken_apps=0 quarantine_apps=0 heavy_apps=0

    section "Diagnóstico de apps"
    DRY_RUN_APPS=true

    for dir in "${base_dirs[@]}"; do
        [[ -d "$dir" ]] || continue

        for app in "$dir"/*.app; do
            [[ -d "$app" ]] || continue

            app_name=$(basename "$app")

            # Tamaño de app (solo modo verbose por rendimiento)
            if [[ "${VERBOSE:-false}" == "true" ]]; then
                size=$(du -sm "$app" 2>/dev/null | awk '{print $1}')
                size=${size:-0}

                if [[ -n "$size" && "$size" -gt 1024 ]]; then
                    log "📦 $app_name → app pesada (${size}MB)"
                    ((heavy_apps++))
                fi
            fi

            # Último uso (solo apps usuario / más eficiente)
            last_used=""

            if [[ "$app" != /System/* ]]; then
                last_used=$(mdls -raw -name kMDItemLastUsedDate "$app" 2>/dev/null)
            fi

            if [[ -n "$last_used" && "$last_used" != "(null)" ]]; then
                last_used_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S %z" "$last_used" "+%s" 2>/dev/null || true)
                now_epoch=$(date "+%s")

                if [[ -n "$last_used_epoch" ]]; then
                    diff_days=$(( (now_epoch - last_used_epoch) / 86400 ))
                    if [[ "$diff_days" -gt 180 ]]; then
                        log "🧹 $app_name → no usada en $diff_days días"
                        ((old_apps++))
                    fi
                fi
            else
                [[ "${VERBOSE:-false}" == "true" ]] && \
                    log "ℹ️ $app_name → sin registro de uso"
            fi

            # Quarantine (solo verbose por rendimiento)
            if [[ "${VERBOSE:-false}" == "true" ]]; then
                if xattr -p com.apple.quarantine "$app" &>/dev/null; then
                    log "ℹ️ $app_name → descargada externamente"
                    ((quarantine_apps++))
                fi
            fi

            # Ejecutable roto
            if ! is_app_executable "$app"; then
                log "❌ $app_name → ejecutable inválido"
                ((broken_apps++))
                continue
            fi

            # App 32 bits (no compatible)
            if is_app_32bit "$app"; then
                log "⚠️ $app_name → posible app 32-bit (no compatible)"
                continue
            fi

            # Intento de ejecución controlado
            if [[ "$DRY_RUN_APPS" != "true" ]]; then
                if ! open -Ra "$app" >/dev/null 2>&1; then
                    log "⚠️ $app_name → no se puede abrir"
                fi
            else
                [[ "${VERBOSE:-false}" == "true" ]] && log "ℹ️ $app_name → ejecución omitida"
            fi
        done
    done

    echo ""
    echo "Resumen de apps:"
    echo "• Apps abandonadas: $old_apps"
    echo "• Apps pesadas: $heavy_apps"
    echo "• Apps quarantine: $quarantine_apps"
    echo "• Apps rotas: $broken_apps"
}
