#!/bin/bash

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
