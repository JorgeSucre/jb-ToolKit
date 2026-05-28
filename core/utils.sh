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

get_cpu_brand_string() {
    local cpu
    cpu="$(sysctl -n hw.brand_string 2>/dev/null || sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "No disponible")"
    echo "$cpu"
}

calculate_health_score() {
    local cpu_load cpu_int ram_pct disk_pct score=100

    # Uso CPU
    cpu_load=$(top -l 1 | awk '/CPU usage/ {printf "%d%%", ($3 + $5)}' 2>/dev/null)
    cpu_load=${cpu_load:-0%}
    cpu_int=$(echo "$cpu_load" | tr -dc '0-9')
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

    # Evitar negativos
    if [[ "$score" -lt 0 ]]; then
        score=0
    fi

    # Cachear métricas para uso del script invocante
    SYS_RAM_PCT=$ram_pct
    SYS_DISK_PCT=$disk_pct
    SYS_CPU_LOAD=$cpu_load

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
