#!/bin/bash

# =========================
# Base Config & Directories
# =========================
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export BASE_DIR
export STATE_FILE="$BASE_DIR/logs/state.env"
export JB_VERSION="${JB_VERSION:-0.9}"
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
            mem_pressure=$((free_mb * 100 / total_mb))
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

state_value() {
    local key="$1"
    local value=""

    if [[ -f "$STATE_FILE" ]]; then
        value=$(awk -F= -v key="$key" \
            '$1 == key {print substr($0, length(key) + 2); exit}' \
            "$STATE_FILE")
    fi

    printf "%s\n" "${value:-N/A}"
}

write_state_values() {
    local temp_file="${STATE_FILE}.tmp.$$"
    local key pair

    mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true
    [[ -f "$STATE_FILE" ]] && cp "$STATE_FILE" "$temp_file" || : > "$temp_file"

    for pair in "$@"; do
        key="${pair%%=*}"
        awk -F= -v key="$key" '$1 != key' "$temp_file" > "${temp_file}.next"
        mv "${temp_file}.next" "$temp_file"
        printf "%s\n" "$pair" >> "$temp_file"
    done

    mv "$temp_file" "$STATE_FILE"
}

session_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

session_write() {
    local level="$1"
    shift

    [[ -n "${JB_SESSION_LOG:-}" ]] || return 0
    printf "%s [%s] [%s] %s\n" \
        "$(session_timestamp)" \
        "$level" \
        "${JB_MODULE:-Launcher}" \
        "$*" >> "$JB_SESSION_LOG" 2>/dev/null || true
}

set_session_module() {
    JB_MODULE="${1:-Unknown}"
    export JB_MODULE
    session_write INFO "Starting $JB_MODULE"
}

shell_quote_command() {
    local arg quoted=""

    for arg in "$@"; do
        printf -v arg "%q" "$arg"
        quoted+="${quoted:+ }$arg"
    done
    printf "%s\n" "$quoted"
}

run_cmd() {
    local visible="false"
    local command_text output_file exit_code

    if [[ "${1:-}" == "--visible" ]]; then
        visible="true"
        shift
    fi

    [[ "$#" -gt 0 ]] || return 0

    command_text="$(shell_quote_command "$@")"
    output_file="${TMPDIR:-/tmp}/jb_cmd_output.$$"
    session_write CMD "$command_text"

    set +e
    if [[ "$visible" == "true" ]]; then
        "$@" 2>&1 | tee "$output_file"
        exit_code=${PIPESTATUS[0]}
    else
        "$@" >"$output_file" 2>&1
        exit_code=$?
    fi
    set -e

    if [[ -s "$output_file" && -n "${JB_SESSION_LOG:-}" ]]; then
        sed 's/^/    /' "$output_file" >> "$JB_SESSION_LOG" 2>/dev/null || true
    fi
    rm -f "$output_file" 2>/dev/null || true

    session_write EXIT "$exit_code"
    return "$exit_code"
}

retain_recent_artifacts() {
    local pattern="$1"
    local keep="${2:-20}"
    local file
    local index=0

    while IFS= read -r file; do
        index=$((index + 1))
        if [[ "$index" -gt "$keep" ]]; then
            rm -f "$file" 2>/dev/null || true
        fi
    done < <(find "$BASE_DIR/logs" -maxdepth 1 -type f -name "$pattern" \
        -print 2>/dev/null | sort -r)
}

generate_system_snapshot() {
    local snapshot_file="$1"
    local macos_version model cpu total_bytes ram_gb disk_info
    local brew_version="Not installed"
    local fastfetch_version="Not installed"
    local formula_count=0
    local cask_count=0
    local displays interfaces uptime_text

    macos_version="$(sw_vers -productVersion 2>/dev/null || echo "Unavailable")"
    load_hardware_info
    model="${HARDWARE_NAME:-${HARDWARE_MODEL:-Unavailable}}"
    cpu="$(get_cpu_brand_string)"
    total_bytes="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"
    ram_gb="$(awk -v bytes="$total_bytes" 'BEGIN {printf "%.0f GB", bytes/1024/1024/1024}')"

    local disk_total disk_used disk_avail disk_pct disk_name filesystem
    local _df_raw
    _df_raw="$(df -H / 2>/dev/null | awk 'NR==2 {print $2, $3, $4, $5}')"
    read -r disk_total disk_used disk_avail disk_pct <<< "$_df_raw"

    disk_total="$(echo "$disk_total" | sed 's/G/ GB/; s/M/ MB/; s/T/ TB/')"
    disk_used="$(echo "$disk_used" | sed 's/G/ GB/; s/M/ MB/; s/T/ TB/')"
    disk_avail="$(echo "$disk_avail" | sed 's/G/ GB/; s/M/ MB/; s/T/ TB/')"

    disk_total="${disk_total:-Unavailable}"
    disk_used="${disk_used:-Unavailable}"
    disk_avail="${disk_avail:-Unavailable}"
    disk_pct="${disk_pct:-Unavailable}"

    disk_name="$(diskutil info / 2>/dev/null | grep "Volume Name:" | sed -E 's/.*Volume Name:[[:space:]]*//')"
    filesystem="$(diskutil info / 2>/dev/null | grep "File System Personality:" | sed -E 's/.*File System Personality:[[:space:]]*//')"
    disk_name="${disk_name:-Macintosh HD}"
    filesystem="${filesystem:-APFS}"

    if brew_available; then
        brew_version="$(brew --version 2>/dev/null | head -1)"
        formula_count="$(brew_list_formula | wc -l | tr -d ' ')"
        cask_count="$(brew_list_cask | wc -l | tr -d ' ')"
    fi

    if command_exists fastfetch; then
        fastfetch_version="$(fastfetch --version 2>/dev/null | head -1)"
    fi

    displays="$(system_profiler SPDisplaysDataType 2>/dev/null | awk '
        /^[[:space:]]{8}[^:]+:$/ {name=$0; gsub(/^[[:space:]]+|:$/, "", name)}
        /Resolution:/ {
            value=$0; sub(/^[[:space:]]+Resolution:[[:space:]]*/, "", value)
            printf " - %s%s%s\n", (name ? name : "Display"), (name ? ": " : ""), value
        }')"
    displays="${displays:-- Unavailable}"

    interfaces="$(networksetup -listallhardwareports 2>/dev/null | awk -F': ' '
        /^Hardware Port:/ {port=$2}
        /^Device:/ {printf " - %s (%s)\n", port, $2}')"
    if [[ -z "$interfaces" ]]; then
        interfaces="$(ifconfig -l 2>/dev/null | tr ' ' '\n' | sed '/^$/d; s/^/ - /')"
    fi
    interfaces="${interfaces:-- Unavailable}"

    uptime_text="$(uptime 2>/dev/null | sed 's/.*up //; s/, [0-9]* users.*//; s/^ *//')"
    uptime_text="${uptime_text:-Unavailable}"

    {
        echo "JB Toolkit System Snapshot"
        echo "Generated: $(session_timestamp)"
        echo "JB Toolkit Version: $JB_VERSION"
        echo "macOS: $macos_version"
        echo "Model: $model"
        echo "CPU: $cpu"
        echo "RAM: $ram_gb"
        echo "Capacidad total: $disk_total"
        echo "Espacio utilizado: $disk_used"
        echo "Espacio disponible para el usuario: $disk_avail"
        echo "Uso del disco: $disk_pct"
        echo "Disco principal: $disk_name"
        echo "Sistema de archivos: $filesystem"
        echo "Architecture: $(uname -m)"
        echo "Uptime: $uptime_text"
        echo "Homebrew: $brew_version"
        echo "Fastfetch: $fastfetch_version"
        echo "Installed formulas: $formula_count"
        echo "Installed casks: $cask_count"
        echo ""
        echo "Displays:"
        printf "%s\n" "$displays"
        echo ""
        echo "Network interfaces:"
        printf "%s\n" "$interfaces"
    } > "$snapshot_file"
}

init_session() {
    local stamp

    if [[ -n "${JB_SESSION_LOG:-}" && -f "$JB_SESSION_LOG" ]]; then
        return 0
    fi

    stamp="$(date '+%Y-%m-%d_%H-%M-%S')"
    JB_SESSION_LOG="$BASE_DIR/logs/session_${stamp}.log"
    JB_SYSTEM_SNAPSHOT="$BASE_DIR/logs/system_snapshot_${stamp}.txt"
    export JB_SESSION_LOG JB_SYSTEM_SNAPSHOT

    : > "$JB_SESSION_LOG"
    session_write INFO "JB Toolkit session started"

    if generate_system_snapshot "$JB_SYSTEM_SNAPSHOT"; then
        session_write SUCCESS "System snapshot created: $(basename "$JB_SYSTEM_SNAPSHOT")"
    else
        session_write WARNING "System snapshot could not be completed"
    fi

    write_state_values \
        "LAST_SESSION_LOG=$(basename "$JB_SESSION_LOG")" \
        "LAST_SYSTEM_SNAPSHOT=$(basename "$JB_SYSTEM_SNAPSHOT")"

    retain_recent_artifacts 'session_*.log' 20
    retain_recent_artifacts 'system_snapshot_*.txt' 20
}

finish_session_module() {
    local exit_code="${1:-0}"
    session_write EXIT "Module completed with exit code $exit_code"
}

handle_unexpected_error() {
    local exit_code="$1"
    local command="$2"
    local line="$3"

    session_write ERROR "Command: $command | Exit: $exit_code | Line: $line"
}

install_session_traps() {
    trap 'exit_code=$?; handle_unexpected_error "$exit_code" "$BASH_COMMAND" "$LINENO"' ERR
    trap 'exit_code=$?; finish_session_module "$exit_code"' EXIT
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
    case "$1" in
        *"❌"*) session_write ERROR "$1" ;;
        *"⚠️"*) session_write WARNING "$1" ;;
        *"✔"*) session_write SUCCESS "$1" ;;
        *) session_write INFO "$1" ;;
    esac
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

# =========================
# Homebrew query cache
# Session-level: each list/outdated query runs at most once per process.
# Cache is populated lazily; skipped when brew is unavailable.
# =========================
_BREW_LIST_FORMULA=""
_BREW_LIST_CASK=""
_BREW_OUTDATED_FORMULA=""
_BREW_OUTDATED_CASK=""
_BREW_LIST_FORMULA_LOADED=0
_BREW_LIST_CASK_LOADED=0
_BREW_OUTDATED_FORMULA_LOADED=0
_BREW_OUTDATED_CASK_LOADED=0

# A transient brew failure must not poison the session: the cache is only
# marked loaded when the query succeeded, so the next call retries.
brew_list_formula() {
    if [[ "$_BREW_LIST_FORMULA_LOADED" -eq 0 ]] && brew_available; then
        if _BREW_LIST_FORMULA=$(brew list --formula 2>/dev/null); then
            _BREW_LIST_FORMULA_LOADED=1
        else
            _BREW_LIST_FORMULA=""
        fi
    fi
    printf "%s\n" "$_BREW_LIST_FORMULA"
}

brew_list_cask() {
    if [[ "$_BREW_LIST_CASK_LOADED" -eq 0 ]] && brew_available; then
        if _BREW_LIST_CASK=$(brew list --cask 2>/dev/null); then
            _BREW_LIST_CASK_LOADED=1
        else
            _BREW_LIST_CASK=""
        fi
    fi
    printf "%s\n" "$_BREW_LIST_CASK"
}

brew_outdated_formula() {
    if [[ "$_BREW_OUTDATED_FORMULA_LOADED" -eq 0 ]] && brew_available; then
        if _BREW_OUTDATED_FORMULA=$(brew outdated --formula 2>/dev/null); then
            _BREW_OUTDATED_FORMULA_LOADED=1
        else
            _BREW_OUTDATED_FORMULA=""
        fi
    fi
    printf "%s\n" "$_BREW_OUTDATED_FORMULA"
}

brew_outdated_cask() {
    if [[ "$_BREW_OUTDATED_CASK_LOADED" -eq 0 ]] && brew_available; then
        if _BREW_OUTDATED_CASK=$(brew outdated --cask 2>/dev/null); then
            _BREW_OUTDATED_CASK_LOADED=1
        else
            _BREW_OUTDATED_CASK=""
        fi
    fi
    printf "%s\n" "$_BREW_OUTDATED_CASK"
}

brew_formula_installed() {
    brew_list_formula | grep -qx "$1"
}

brew_cask_installed() {
    brew_list_cask | grep -qx "$1"
}

brew_upgrade_package() {
    HOMEBREW_NO_ENV_HINTS=1 run_cmd brew upgrade "$1"
}

brew_cache_reset() {
    _BREW_LIST_FORMULA=""
    _BREW_LIST_CASK=""
    _BREW_OUTDATED_FORMULA=""
    _BREW_OUTDATED_CASK=""
    _BREW_LIST_FORMULA_LOADED=0
    _BREW_LIST_CASK_LOADED=0
    _BREW_OUTDATED_FORMULA_LOADED=0
    _BREW_OUTDATED_CASK_LOADED=0
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
    if command -v print_section >/dev/null 2>&1; then
        print_section "$1"
    else
        echo ""
        echo "$1"
        echo "----------------------------------------"
    fi
}

command_exists() {
    command -v "$1" &>/dev/null
}

# parse_selection INPUT MAX
# Expands comma-separated numbers and ranges (e.g. "1,3-5,7") into one
# number per line.  Numbers outside [1, MAX] and invalid tokens are
# rejected with a warning.  Backward-compatible: plain "1,2,5" still works.
parse_selection() {
    local input="$1" max="$2"
    local part start end n
    local -a _ps_parts

    input="${input// /}"
    [[ -z "$input" ]] && return 0

    IFS=',' read -ra _ps_parts <<< "$input"
    for part in "${_ps_parts[@]}"; do
        if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            start="${BASH_REMATCH[1]}"
            end="${BASH_REMATCH[2]}"
            if (( start < 1 || end > max || start > end )); then
                warn "⚠️ Rango inválido: $part"
                continue
            fi
            for ((n = start; n <= end; n++)); do
                printf "%d\n" "$n"
            done
        elif [[ "$part" =~ ^[0-9]+$ ]]; then
            if (( part >= 1 && part <= max )); then
                printf "%d\n" "$part"
            else
                warn "⚠️ Selección ignorada: $part"
            fi
        else
            warn "⚠️ Selección ignorada: $part"
        fi
    done
}

# =========================
# Shared size helpers
# =========================

dir_size_mb() {
    du -sm "$1" 2>/dev/null | awk '{print $1+0}'
}

human_size() {
    local size_mb="$1"
    if [[ "$size_mb" -ge 1024 ]]; then
        awk "BEGIN {printf \"%.1fGB\", $size_mb/1024}"
    else
        printf "%sMB" "$size_mb"
    fi
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

has_external_display() {
    local display_count

    display_count=$(system_profiler SPDisplaysDataType 2>/dev/null \
        | awk '/Resolution:/ {count++} END {print count+0}')

    [[ "$display_count" -gt 1 ]]
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
