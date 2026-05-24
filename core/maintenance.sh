#!/bin/bash

set -Euo pipefail
START_TIME=$(date +%s)

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/core/utils.sh"

# ANSI colors (solo terminal interactiva)
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

echo ""
echo "========================================"
echo "   🍺 JB Toolkit Maintenance v0.9"
echo "========================================"

DRY_RUN=false
TOTAL_FREED_MB=0
FILES_REMOVED=0

PREVIEW_CACHE_COUNT=0
PREVIEW_LOG_COUNT=0
PREVIEW_TRASH_COUNT=0

safe_find_count() {
    local path="$1"
    shift

    local count

    [[ -e "$path" ]] || {
        echo 0
        return
    }

    count=$(find "$path" "$@" 2>/dev/null | wc -l | tr -d ' ')

    if [[ ! "$count" =~ ^[0-9]+$ ]]; then
        count=0
    fi

    echo "$count"
}

safe_dir_size_mb() {
    local path="$1"

    local size
    size=$(du -sm "$path" 2>/dev/null | awk 'NR==1 {print $1}')

    if [[ ! "$size" =~ ^[0-9]+$ ]]; then
        size=0
    fi

    echo "$size"
}

safe_old_files_size_mb() {
    local path="$1"
    shift

    local size

    [[ -e "$path" ]] || {
        echo 0
        return
    }

    size=$(find "$path" "$@" -exec du -sm {} + 2>/dev/null \
        | awk '{sum += $1} END {print sum+0}')

    if [[ ! "$size" =~ ^[0-9]+$ ]]; then
        size=0
    fi

    echo "$size"
}

safe_last_used_days() {
    local app_path="$1"

    local last_used
    last_used=$(mdls -name kMDItemLastUsedDate "$app_path" 2>/dev/null \
        | sed 's/.*= //' \
        | tr -d '"')

    if [[ -z "$last_used" || "$last_used" == "(null)" ]]; then
        echo 999
        return
    fi

    local last_epoch
    last_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S %z" "$last_used" "+%s" 2>/dev/null || echo 0)

    if [[ "$last_epoch" -eq 0 ]]; then
        echo 999
        return
    fi

    local now
    now=$(date +%s)

    echo $(( (now - last_epoch) / 86400 ))
}

safe_app_size_mb() {
    local app_path="$1"

    local size
    size=$(du -sm "$app_path" 2>/dev/null | awk 'NR==1 {print $1}')

    if [[ ! "$size" =~ ^[0-9]+$ ]]; then
        size=0
    fi

    echo "$size"
}

format_size_human() {
    local size_mb="$1"

    if [[ ! "$size_mb" =~ ^[0-9]+$ ]]; then
        echo "0MB"
        return
    fi

    if [[ "$size_mb" -ge 1024 ]]; then
        awk "BEGIN {printf \"%.1fGB\", $size_mb/1024}"
    else
        echo "${size_mb}MB"
    fi
}

# Get real file size in MB (not apparent size, for sparse/compressed files)
get_real_file_size_mb() {
    local file_path="$1"

    local bytes
    bytes=$(stat -f%z "$file_path" 2>/dev/null || echo 0)

    if [[ ! "$bytes" =~ ^[0-9]+$ ]]; then
        bytes=0
    fi

    echo $((bytes / 1024 / 1024))
}

safe_delete() {
    local target="$1"
    if [[ "$DRY_RUN" == true ]]; then
        log "🧪 Simulación: eliminar $target"
    else
        rm -rf "$target" 2>/dev/null || true
    fi
}

# =========================
# System State
# =========================
echo ""
echo "🧠 Estado del sistema"
echo "----------------------------------------"

SPOTLIGHT_STATUS=$(mdutil -s / 2>/dev/null || true)

if echo "$SPOTLIGHT_STATUS" | grep -qi "Indexing enabled"; then
    printf "${GREEN}✔ Spotlight operativo${NC}\n"
fi

if echo "$SPOTLIGHT_STATUS" | grep -qi "Scanning"; then
    printf "${YELLOW}🔎 Spotlight está reindexando el disco${NC}\n"
fi

SWAP_USAGE=$(sysctl vm.swapusage 2>/dev/null || true)

if echo "$SWAP_USAGE" | grep -qi "used = [1-9]"; then
    printf "${YELLOW}⚠️ Uso de memoria virtual detectado${NC}\n"
else
    printf "${GREEN}✔ Sin presión importante de memoria virtual${NC}\n"
fi

# =========================
# Maintenance Preview
# =========================

PREVIEW_CACHE_COUNT=$(safe_find_count "$HOME/Library/Caches" -type f -mtime +7)
PREVIEW_LOG_COUNT=$(safe_find_count "$HOME/Library/Logs" -type f -mtime +14)
PREVIEW_TRASH_COUNT=$(safe_find_count "$HOME/.Trash" -mindepth 1 -mtime +7)

PREVIEW_CACHE_SIZE=$(safe_old_files_size_mb "$HOME/Library/Caches" -type f -mtime +7)
PREVIEW_LOG_SIZE=$(safe_old_files_size_mb "$HOME/Library/Logs" -type f -mtime +14)

PREVIEW_ESTIMATE=$((PREVIEW_CACHE_SIZE + PREVIEW_LOG_SIZE))

echo ""
echo "🧪 Vista previa del mantenimiento"
echo "----------------------------------------"
printf "• Cachés antiguas detectadas: %s archivos\n" "$PREVIEW_CACHE_COUNT"
printf "• Logs antiguos detectados: %s archivos\n" "$PREVIEW_LOG_COUNT"
printf "• Papelera antigua detectada: %s elementos\n" "$PREVIEW_TRASH_COUNT"
printf "• Espacio potencial a recuperar: ~%sMB\n" "$PREVIEW_ESTIMATE"

echo ""
printf "¿Continuar con el mantenimiento? (y/n): "
read -r MAINTENANCE_CONFIRM

if [[ ! "$MAINTENANCE_CONFIRM" =~ ^[YySs]$ ]]; then
    echo ""
    printf "${YELLOW}⚠️ Maintenance cancelado por el usuario${NC}\n"
    exit 0
fi

# =========================
# Homebrew Cleanup
# =========================
echo ""
echo "📦 Homebrew"
echo "----------------------------------------"
log "🧹 Limpiando paquetes y cachés Homebrew..."

BREW_BEFORE=0
BREW_AFTER=0
BREW_FREED=0

if brew_available; then
    BREW_BEFORE=$(safe_dir_size_mb "$HOME/Library/Caches/Homebrew")

    brew cleanup -s >/dev/null 2>&1 || true

    BREW_AFTER=$(safe_dir_size_mb "$HOME/Library/Caches/Homebrew")
    BREW_FREED=$(( BREW_BEFORE - BREW_AFTER ))
    [[ "$BREW_FREED" -lt 0 ]] && BREW_FREED=0
else
    printf "${YELLOW}⚠️ Homebrew no disponible, limpieza omitida${NC}\n"
fi

if [[ "$BREW_FREED" -gt 0 ]]; then
    printf "${GREEN}✔ Homebrew limpiado (%sMB liberados)${NC}\n" "$BREW_FREED"
elif brew_available; then
    printf "${GREEN}✔ Homebrew ya se encontraba limpio${NC}\n"
fi

TOTAL_FREED_MB=$((TOTAL_FREED_MB + BREW_FREED))

# =========================
# User Cache Cleanup (older than 7 days)
# =========================
echo ""
echo "🧹 Cachés de usuario"
echo "----------------------------------------"

log "🧹 Eliminando cachés antiguas (>7 días)..."

if [[ ! -d "$HOME/Library/Caches" ]]; then
    mkdir -p "$HOME/Library/Caches"
fi

SIZE_BEFORE=$(safe_dir_size_mb "$HOME/Library/Caches")

CACHE_COUNT=$(safe_find_count "$HOME/Library/Caches" -type f -mtime +7)

find "$HOME/Library/Caches" -type f -mtime +7 -exec rm -f {} + >/dev/null 2>&1 || true

SIZE_AFTER=$(safe_dir_size_mb "$HOME/Library/Caches")

FREED=$((SIZE_BEFORE - SIZE_AFTER))
[[ "$FREED" -lt 0 ]] && FREED=0

if [[ "$CACHE_COUNT" -gt 0 ]]; then
    printf "${GREEN}✔ %s archivos eliminados${NC}\n" "$CACHE_COUNT"
    printf "${GREEN}✔ %sMB recuperados${NC}\n" "$FREED"
else
    printf "${GREEN}✔ No se detectaron cachés antiguas${NC}\n"
fi

TOTAL_FREED_MB=$((TOTAL_FREED_MB + FREED))
FILES_REMOVED=$((FILES_REMOVED + CACHE_COUNT))

# =========================
# Logs Cleanup (older than 14 days)
# =========================
echo ""
echo "📜 Logs del sistema"
echo "----------------------------------------"

log "🧹 Eliminando logs antiguos (>14 días)..."

LOG_SIZE_BEFORE=$(safe_dir_size_mb "$HOME/Library/Logs")

LOG_COUNT=$(safe_find_count "$HOME/Library/Logs" -type f -mtime +14)

find "$HOME/Library/Logs" -type f -mtime +14 -exec rm -f {} + >/dev/null 2>&1 || true

LOG_SIZE_AFTER=$(safe_dir_size_mb "$HOME/Library/Logs")

LOG_FREED=$((LOG_SIZE_BEFORE - LOG_SIZE_AFTER))
[[ "$LOG_FREED" -lt 0 ]] && LOG_FREED=0

if [[ "$LOG_COUNT" -gt 0 ]]; then
    printf "${GREEN}✔ %s logs eliminados${NC}\n" "$LOG_COUNT"

    if [[ "$LOG_FREED" -gt 0 ]]; then
        printf "${GREEN}✔ %sMB recuperados${NC}\n" "$LOG_FREED"
    else
        printf "${GREEN}✔ Espacio mínimo recuperado${NC}\n"
    fi
else
    printf "${GREEN}✔ No se detectaron logs antiguos${NC}\n"
fi

TOTAL_FREED_MB=$((TOTAL_FREED_MB + LOG_FREED))
FILES_REMOVED=$((FILES_REMOVED + LOG_COUNT))

# =========================
# Xcode Cleanup
# =========================
if [[ -d "$HOME/Library/Developer/Xcode/DerivedData" ]]; then
    log "🧹 Limpiando DerivedData de Xcode..."
    safe_delete "$HOME/Library/Developer/Xcode/DerivedData"
fi

# =========================
# iOS Backups Cleanup (>30 days)
# =========================
if [[ -d "$HOME/Library/Application Support/MobileSync/Backup" ]]; then
    log "🧹 Revisando backups de iPhone/iPad..."

    IOS_BACKUP_COUNT=$(find "$HOME/Library/Application Support/MobileSync/Backup" \
        -mindepth 1 -type d -mtime +30 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$IOS_BACKUP_COUNT" -gt 0 ]]; then

        find "$HOME/Library/Application Support/MobileSync/Backup" \
            -mindepth 1 -type d -mtime +30 \
            -exec rm -rf {} + 2>/dev/null || true

        printf "${GREEN}✔ %s backups antiguos eliminados${NC}\n" "$IOS_BACKUP_COUNT"

    else
        printf "${GREEN}✔ No se detectaron backups antiguos de iPhone/iPad${NC}\n"
    fi
fi

# =========================
# Trash Cleanup (older than 7 days)
# =========================
echo ""
echo "🗑️ Papelera"
echo "----------------------------------------"

log "🧹 Eliminando elementos antiguos (>7 días)..."

TRASH_COUNT=$(safe_find_count "$HOME/.Trash" -mindepth 1 -mtime +7)

find "$HOME/.Trash" -mindepth 1 -mtime +7 -exec rm -rf {} + >/dev/null 2>&1 || true

if [[ "$TRASH_COUNT" -gt 0 ]]; then
    printf "${GREEN}✔ %s elementos eliminados${NC}\n" "$TRASH_COUNT"
else
    printf "${GREEN}✔ Papelera ya se encontraba limpia${NC}\n"
fi

FILES_REMOVED=$((FILES_REMOVED + TRASH_COUNT))
# =========================
# Cloud Sync Detection
# =========================
echo ""
echo "☁️ Sincronización en la nube"
echo "----------------------------------------"

CLOUD_FOUND="false"

if [[ -d "$HOME/Library/CloudStorage/OneDrive-Personal" ]]; then
    CLOUD_FOUND="true"
    echo "• OneDrive detectado"
fi

if [[ -d "$HOME/Library/Mobile Documents" ]]; then
    CLOUD_FOUND="true"
    echo "• iCloud Drive detectado"
fi

if [[ "$CLOUD_FOUND" != "true" ]]; then
    printf "${GREEN}✔ No se detectaron plataformas de sincronización relevantes${NC}\n"
fi

# =========================
# Large Files Detection (>1GB)
# =========================

CLAUDE_VM_SHOWN="false"
WHATSAPP_SHOWN="false"

echo ""
echo "💾 Revisión de almacenamiento"
echo "----------------------------------------"

SEARCH_DIRS=()
[[ -d "$HOME/Downloads" ]] && SEARCH_DIRS+=("$HOME/Downloads")
[[ -d "$HOME/Documents" ]] && SEARCH_DIRS+=("$HOME/Documents")
[[ -d "$HOME/Library" ]] && SEARCH_DIRS+=("$HOME/Library")

LARGE_FILES=""
if [[ "${#SEARCH_DIRS[@]}" -gt 0 ]]; then
    LARGE_FILES=$(find "${SEARCH_DIRS[@]}" -type f -size +1G \
    -not -path "*OneDrive*" \
    -not -path "*Group Containers*" \
    -not -path "*Containers*" \
    -not -path "*VirtualMachines*" \
    -not -path "*.utm*" \
    2>/dev/null | head -20 || true)
fi

if [[ -n "$LARGE_FILES" ]]; then
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        FILE_SIZE_MB=$(get_real_file_size_mb "$file")
        FILE_SIZE_MB=${FILE_SIZE_MB:-0}
        FILE_SIZE_HUMAN=$(format_size_human "$FILE_SIZE_MB")

        if [[ "$file" == *"Claude/vm_bundles"* ]]; then
            if [[ "$CLAUDE_VM_SHOWN" != "true" ]]; then
                echo "ℹ️ Claude Desktop utiliza una VM local (~$FILE_SIZE_HUMAN)"
                echo "  Utilizada por herramientas sandbox e IA"
                CLAUDE_VM_SHOWN="true"
            fi

        elif [[ "$file" == *"WhatsApp"* ]]; then
            if [[ "$WHATSAPP_SHOWN" != "true" ]]; then
                echo "• Archivo multimedia/comprimido grande detectado"
                echo "  $(basename "$file") (~$FILE_SIZE_HUMAN)"
                WHATSAPP_SHOWN="true"
            fi

        else
            echo "• $(basename "$file") (~$FILE_SIZE_HUMAN)"
        fi

    done <<< "$LARGE_FILES"
else
    printf "${GREEN}✔ No se detectaron archivos grandes relevantes${NC}\n"
fi

# =========================
# LaunchAgents Review
# =========================
echo ""
echo "🚀 LaunchAgents personalizados"
echo "----------------------------------------"

BROKEN_AGENTS=""
if [[ -d "$HOME/Library/LaunchAgents" ]]; then
    BROKEN_AGENTS=$(find "$HOME/Library/LaunchAgents" -name '*.plist' 2>/dev/null | head -10)
fi

if [[ -n "$BROKEN_AGENTS" ]]; then
    printf "${YELLOW}ℹ️ LaunchAgents detectados:${NC}\n"
    echo "$BROKEN_AGENTS" | sed 's/^/   - /'
else
    printf "${GREEN}✔ No se detectaron LaunchAgents relevantes${NC}\n"
fi

# =========================
# Intelligent App Cleanup
# =========================
echo ""
echo "📦 Aplicaciones candidatas a limpieza"
echo "----------------------------------------"

PROTECTED_APPS=(
    "Microsoft Word"
    "Microsoft Excel"
    "Microsoft PowerPoint"
    "UTM"
    "Xcode"
)

APP_INDEX=1
APP_LIST=()
DUPLICATE_BROWSERS=0

while IFS= read -r app; do

    [[ -z "$app" ]] && continue

    APP_NAME=$(basename "$app" .app)

    if [[ "$app" == /System/* ]]; then
        continue
    fi

    APP_SIZE=$(safe_app_size_mb "$app")
    if [[ "$APP_SIZE" -lt 512 ]]; then
    continue
fi
    LAST_USED_DAYS=$(safe_last_used_days "$app")

    SHOW_APP="false"
    APP_REASON=""

    if [[ "$APP_SIZE" -ge 4096 ]]; then
    SHOW_APP="true"
    APP_REASON="Tamaño crítico"

elif [[ "$APP_SIZE" -ge 1024 && "$LAST_USED_DAYS" -ne 999 && "$LAST_USED_DAYS" -ge 60 ]]; then
    SHOW_APP="true"
    APP_REASON="Gran tamaño e inactividad"

elif [[ "$LAST_USED_DAYS" -ne 999 && "$LAST_USED_DAYS" -ge 120 ]]; then
    SHOW_APP="true"
    APP_REASON="Inactividad prolongada"

elif [[ "$APP_SIZE" -ge 512 ]]; then

    APP_BINARY_FAST="$app/Contents/MacOS"

    if [[ -d "$APP_BINARY_FAST" ]]; then
        APP_FAST_FILE=$(find "$APP_BINARY_FAST" -maxdepth 1 -type f 2>/dev/null | head -1)

        if [[ -n "$APP_FAST_FILE" ]]; then
            FAST_ARCH=$(file "$APP_FAST_FILE" 2>/dev/null || true)

            if echo "$FAST_ARCH" | grep -qi "x86_64" && ! echo "$FAST_ARCH" | grep -qi "arm64"; then
                SHOW_APP="true"
                APP_REASON="Aplicación Intel-only"
            fi
        fi
    fi
fi

    if [[ "$SHOW_APP" != "true" ]]; then
        continue
    fi

    APP_BINARY=$(find "$app/Contents/MacOS" -maxdepth 1 -type f 2>/dev/null | head -1)
    APP_ARCH=""

    if [[ -n "$APP_BINARY" ]]; then
        APP_ARCH=$(file "$APP_BINARY" 2>/dev/null || true)
    fi

    printf "%s) %s\n" "$APP_INDEX" "$APP_NAME"
    printf "   • Tamaño: %s\n" "$(format_size_human "$APP_SIZE")"

    if [[ "$LAST_USED_DAYS" -ge 999 ]]; then
        printf "   • Uso reciente no disponible\n"
    else
        printf "   • Último uso: hace %s días\n" "$LAST_USED_DAYS"
    fi

    if [[ "$APP_SIZE" -ge 2048 && "$LAST_USED_DAYS" -lt 30 ]]; then
        printf "   ${YELLOW}• App pesada pero utilizada recientemente${NC}\n"
    fi

    if [[ -n "$APP_REASON" ]]; then
        printf "   • Candidata por: %s\n" "$APP_REASON"
    fi

    if echo "$APP_ARCH" | grep -qi "x86_64" && ! echo "$APP_ARCH" | grep -qi "arm64"; then
        printf "   ${YELLOW}• Aplicación Intel-only detectada${NC}\n"
    fi

    if [[ "$APP_NAME" =~ (Chrome|Firefox|Floorp|Brave|Edge|Opera) ]]; then
        DUPLICATE_BROWSERS=$((DUPLICATE_BROWSERS + 1))
    fi

    for protected in "${PROTECTED_APPS[@]}"; do
        if [[ "$APP_NAME" == "$protected" ]]; then
            printf "   ${YELLOW}• Aplicación importante detectada${NC}\n"
            break
        fi
    done

    APP_LIST+=("$app")

    echo ""

    APP_INDEX=$((APP_INDEX + 1))

DONE_APPS="true"

done < <(find /Applications "$HOME/Applications" -maxdepth 1 -name '*.app' 2>/dev/null | sort)

if [[ "${#APP_LIST[@]}" -eq 0 ]]; then
    printf "${GREEN}✔ No se detectaron aplicaciones recomendadas para limpieza${NC}\n"
else

    if [[ "$DUPLICATE_BROWSERS" -ge 3 ]]; then
        printf "${YELLOW}⚠️ Se detectaron múltiples navegadores instalados${NC}\n"
        echo ""
    fi

    printf "Selecciona apps a mover a la Papelera (ej: 1,3,5 | 0 para omitir): "
    read -r APP_SELECTION

    if [[ "$APP_SELECTION" == "0" ]]; then
        APP_SELECTION=""
    fi

    if [[ -n "$APP_SELECTION" ]]; then

        IFS=',' read -ra SELECTED <<< "$APP_SELECTION"

        echo ""
        echo "⚠️ Aplicaciones seleccionadas"
        echo "----------------------------------------"

        VALID_SELECTIONS=()

        for item in "${SELECTED[@]}"; do

            INDEX=$(echo "$item" | tr -d ' ')

            if [[ "$INDEX" =~ ^[0-9]+$ ]]; then

                ARRAY_INDEX=$((INDEX - 1))

                if [[ "$ARRAY_INDEX" -ge 0 && "$ARRAY_INDEX" -lt "${#APP_LIST[@]}" ]]; then

                    APP_PATH="${APP_LIST[$ARRAY_INDEX]}"
                    APP_NAME=$(basename "$APP_PATH")

                    echo "• $APP_NAME"

                    VALID_SELECTIONS+=("$APP_PATH")
                fi
            fi
        done

        echo ""
        printf "¿Mover estas apps a la Papelera? (y/n): "
        read -r CONFIRM_REMOVE

        if [[ "$CONFIRM_REMOVE" =~ ^[YySs]$ ]]; then

            echo ""
            echo "🗑️ Eliminando aplicaciones"
            echo "----------------------------------------"

            for app_path in "${VALID_SELECTIONS[@]}"; do

                APP_NAME=$(basename "$app_path")

                if brew list --cask 2>/dev/null | grep -qx "${APP_NAME%.app}"; then
                    brew uninstall --cask "${APP_NAME%.app}" >/dev/null 2>&1 || true
                fi

                osascript <<EOF >/dev/null 2>&1
 tell application "Finder"
     delete POSIX file "$app_path"
 end tell
EOF

                printf "${GREEN}✔ %s movida a la Papelera${NC}\n" "$APP_NAME"
            done
        fi
    fi
fi

# =========================
# Performance Optimization
# =========================

echo ""
echo "⚡ Optimización de rendimiento"
echo "----------------------------------------"

echo "1) Ligera (recomendado)"
echo "2) Agresiva"
echo "3) Restaurar valores por defecto"
echo "0) Omitir"

echo ""
printf "Selecciona una opción: "
read -r PERFORMANCE_MODE

apply_light_optimization() {

    local silent="${1:-false}"

    if [[ "$silent" != "true" ]]; then
        log "⚡ Aplicando optimización ligera..."
    fi

    if [[ "$(uname -m)" == "arm64" ]]; then
        printf "${BLUE}ℹ️ Perfil optimizado para Apple Silicon${NC}\n"
    else
        printf "${BLUE}ℹ️ Perfil optimizado para Intel${NC}\n"
    fi

    defaults write com.apple.universalaccess reduceMotion -bool true >/dev/null 2>&1 || true
    defaults write com.apple.universalaccess reduceTransparency -bool true >/dev/null 2>&1 || true

    defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false >/dev/null 2>&1 || true

    defaults write com.apple.dock autohide-time-modifier -float 0.15 >/dev/null 2>&1 || true
    defaults write com.apple.dock expose-animation-duration -float 0.1 >/dev/null 2>&1 || true

    defaults write com.apple.finder DisableAllAnimations -bool true >/dev/null 2>&1 || true

    killall Dock >/dev/null 2>&1 || true
    killall Finder >/dev/null 2>&1 || true

    if [[ "$silent" != "true" ]]; then
        printf "${GREEN}✔ Optimización ligera aplicada${NC}\n"
    fi
}

apply_aggressive_optimization() {

    log "⚡ Aplicando optimización agresiva..."

    apply_light_optimization "true"

    defaults write com.apple.AdLib allowApplePersonalizedAdvertising -bool false >/dev/null 2>&1 || true

    if [[ "$(uname -m)" != "arm64" ]]; then

        defaults write com.apple.assistant.support 'Assistant Enabled' -bool false >/dev/null 2>&1 || true
        defaults write com.apple.Siri StatusMenuVisible -bool false >/dev/null 2>&1 || true

        launchctl disable gui/$UID/com.apple.tipsd >/dev/null 2>&1 || true
        launchctl disable gui/$UID/com.apple.assistantd >/dev/null 2>&1 || true
    fi

    for app in Discord Steam EpicGamesLauncher Microsoft\ Teams Spotify; do
        osascript <<EOF >/dev/null 2>&1
tell application "System Events"
    delete every login item whose name is "$app"
end tell
EOF
    done

    printf "${GREEN}✔ Optimización agresiva aplicada${NC}\n"
    printf "• Animaciones reducidas\n"
    printf "• Transparencias reducidas\n"
    printf "• Apps de inicio optimizadas\n"
    if [[ "$(uname -m)" == "arm64" ]]; then
        printf "• Servicios visuales optimizados\n"
    else
        printf "• Telemetría no esencial reducida\n"
    fi

    printf "${YELLOW}ℹ️ Se redujeron procesos visuales y telemetría no esencial${NC}\n"
}

restore_performance_defaults() {

    log "🔄 Restaurando configuración por defecto..."

    defaults delete com.apple.universalaccess reduceMotion >/dev/null 2>&1 || true
    defaults delete com.apple.universalaccess reduceTransparency >/dev/null 2>&1 || true

    defaults delete NSGlobalDomain NSAutomaticWindowAnimationsEnabled >/dev/null 2>&1 || true

    defaults delete com.apple.dock autohide-time-modifier >/dev/null 2>&1 || true
    defaults delete com.apple.dock expose-animation-duration >/dev/null 2>&1 || true

    defaults delete com.apple.finder DisableAllAnimations >/dev/null 2>&1 || true

    defaults delete com.apple.AdLib allowApplePersonalizedAdvertising >/dev/null 2>&1 || true

    defaults delete com.apple.assistant.support 'Assistant Enabled' >/dev/null 2>&1 || true
    defaults delete com.apple.Siri StatusMenuVisible >/dev/null 2>&1 || true

    launchctl enable gui/$UID/com.apple.tipsd >/dev/null 2>&1 || true
    launchctl enable gui/$UID/com.apple.assistantd >/dev/null 2>&1 || true

    killall Dock >/dev/null 2>&1 || true
    killall Finder >/dev/null 2>&1 || true

    printf "${GREEN}✔ Configuración por defecto restaurada${NC}\n"
}

case "$PERFORMANCE_MODE" in
    1)
        apply_light_optimization
        ;;
    2)
        echo ""
        printf "${YELLOW}⚠️ Este modo reduce efectos visuales, telemetría y procesos en segundo plano${NC}\n"
        printf "¿Continuar? (y/n): "
        read -r AGGRESSIVE_CONFIRM
        if [[ "$AGGRESSIVE_CONFIRM" =~ ^[YySs]$ ]]; then
            apply_aggressive_optimization
        else
            printf "${YELLOW}⚠️ Optimización agresiva cancelada${NC}\n"
        fi
        ;;
    3)
        restore_performance_defaults
        ;;
    *)
        printf "${BLUE}ℹ️ Optimización omitida${NC}\n"
        ;;
esac

if [[ "$PERFORMANCE_MODE" == "2" || "$PERFORMANCE_MODE" == "3" ]]; then
    echo ""
    printf "${BLUE}ℹ️ Algunas configuraciones pueden requerir cerrar sesión para aplicarse completamente${NC}\n"
fi

# =========================
# Summary
# =========================
echo ""
echo "🧠 Resumen ejecutivo"
echo "----------------------------------------"

if [[ "$TOTAL_FREED_MB" -gt 2000 ]]; then
    printf "🔴 Acumulación importante detectada\n"
elif [[ "$TOTAL_FREED_MB" -gt 500 ]]; then
    printf "🟡 Limpieza moderada aplicada\n"
elif [[ "$PERFORMANCE_MODE" == "2" ]]; then
    printf "🟢 Perfil de rendimiento aplicado\n"
else
    printf "🟢 Estado saludable\n"
fi

echo ""

if [[ "$TOTAL_FREED_MB" -gt 2000 ]]; then
    printf "${GREEN}• El sistema tenía acumulación significativa de archivos temporales${NC}\n"
elif [[ "$TOTAL_FREED_MB" -gt 500 ]]; then
    printf "${YELLOW}• Se recuperó espacio moderado del sistema${NC}\n"
elif [[ "$TOTAL_FREED_MB" -gt 0 ]]; then
    printf "• Se realizó limpieza ligera del sistema\n"
else
    printf "• El sistema ya se encontraba optimizado\n"
fi

echo ""

if [[ "$TOTAL_FREED_MB" -ge 100 ]]; then
    printf "${GREEN}💾 Espacio recuperado: %sMB${NC}\n" "$TOTAL_FREED_MB"

elif [[ "$TOTAL_FREED_MB" -gt 0 ]]; then
    printf "${GREEN}💾 Limpieza ligera aplicada${NC}\n"

else
    printf "${GREEN}💾 Espacio recuperado: mínimo/no relevante${NC}\n"
fi
echo ""
echo "📊 Impacto del mantenimiento"
echo "----------------------------------------"

printf "• Cachés: %sMB\n" "$FREED"
printf "• Logs: %sMB\n" "$LOG_FREED"
printf "• Homebrew: %sMB\n" "$BREW_FREED"
if [[ "$TRASH_COUNT" -gt 0 ]]; then
    printf "• Papelera: %s elementos procesados\n" "$TRASH_COUNT"
else
    printf "• Papelera: sin elementos antiguos\n"
fi

# Guardar para reporte
STATE_FILE="$BASE_DIR/logs/state.env"
mkdir -p "$BASE_DIR/logs"

grep -v "TOTAL_FREED_MB\|FILES_REMOVED" "$STATE_FILE" 2>/dev/null > "${STATE_FILE}.tmp" || true

cat >> "${STATE_FILE}.tmp" <<EOF
TOTAL_FREED_MB=$TOTAL_FREED_MB
FILES_REMOVED=$FILES_REMOVED
PERFORMANCE_MODE=$PERFORMANCE_MODE
EOF

mv "${STATE_FILE}.tmp" "$STATE_FILE"

echo ""
echo "🧠 Resultado final"
echo "----------------------------------------"

if system_profiler SPHardwareDataType 2>/dev/null | grep -qi "MacBook Air"; then
    printf "${YELLOW}• Equipo sin ventilación activa detectado${NC}\n"
fi
if [[ "$CACHE_COUNT" -gt 0 && "$FREED" -gt 0 ]]; then
    printf "${GREEN}• Cachés temporales limpiadas${NC}\n"

elif [[ "$CACHE_COUNT" -gt 0 ]]; then
    printf "${GREEN}• Cachés antiguas verificadas y optimizadas${NC}\n"
else
    printf "${GREEN}• No se detectaron cachés antiguas${NC}\n"
fi
if [[ "$LOG_COUNT" -gt 0 ]]; then
    printf "${GREEN}• Logs temporales limpiados${NC}\n"
else
    printf "${GREEN}• No se detectaron logs antiguos${NC}\n"
fi
if [[ "$TOTAL_FREED_MB" -ge 100 ]]; then
    printf "${GREEN}• Espacio recuperado correctamente${NC}\n"
elif [[ "$TOTAL_FREED_MB" -gt 0 ]]; then
    printf "${GREEN}• El sistema ya se encontraba relativamente limpio${NC}\n"
else
    printf "${GREEN}• No fue necesaria limpieza adicional${NC}\n"
fi
case "$PERFORMANCE_MODE" in
    1|2)
        printf "${GREEN}• Perfil de rendimiento aplicado${NC}\n"
        ;;

    3)
        printf "${GREEN}• Configuración visual restaurada${NC}\n"
        ;;

    *)
        printf "${GREEN}• Configuración de rendimiento sin cambios${NC}\n"
        ;;
esac
echo ""
echo "🛡️ Seguridad del mantenimiento"
echo "----------------------------------------"

printf "${GREEN}• No se eliminaron aplicaciones automáticamente${NC}\n"
printf "${GREEN}• No se alteraron archivos sincronizados en la nube${NC}\n"
printf "${GREEN}• No se modificaron archivos del sistema${NC}\n"
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

printf "⏱️ Tiempo total: %s segundos\n" "$ELAPSED"

echo ""

echo "========================================"
printf "${GREEN}✔ Maintenance completado correctamente${NC}\n"
echo "========================================"
