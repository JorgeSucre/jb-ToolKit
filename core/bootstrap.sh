#!/bin/bash

set -Eeuo pipefail

SECONDS=0
STAGE_START_TIME=0
CURRENT_STAGE=1
TOTAL_STAGES=5

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/core/utils.sh"
source "$BASE_DIR/core/bootstrap/ui.sh"
source "$BASE_DIR/core/bootstrap/stages.sh"
source "$BASE_DIR/core/bootstrap/brew.sh"
source "$BASE_DIR/core/bootstrap/packages.sh"
source "$BASE_DIR/core/bootstrap/hardware.sh"

STATE_FILE="$BASE_DIR/logs/state.env"
mkdir -p "$BASE_DIR/logs" 2>/dev/null || true

print_banner

check_internet_connection || exit 1

print_section "🛠️ Preparando herramientas base"
log "🛠️ Verificando Command Line Tools..."

install_clt() {

    if xcode-select -p &>/dev/null; then
        log "✔ CLT ya instaladas"
        return 0
    fi

    log "📦 Intentando instalar CLT..."
    xcode-select --install 2>/dev/null || true

    for i in {1..60}; do

        if xcode-select -p &>/dev/null; then
            log "✔ CLT instaladas correctamente"
            return 0
        fi

        sleep 5
    done

    log "❌ CLT no se instalaron automáticamente"
    return 1
}

print_stage "Verificando herramientas base"
install_clt || log "⚠️ Continuando sin CLT (brew puede fallar)"

HAS_SUDO=0

if dseditgroup -o checkmember -m "$USER" admin 2>/dev/null | grep -q "yes"; then
    HAS_SUDO=1
else
    print_section "🔐 Permisos del sistema"
    warn "⚠️ Esta cuenta no tiene permisos administrativos"
    echo "Homebrew requiere acceso sudo en macOS"
fi

INSTALL_OPTIONAL_APPS="false"

BREW_OK=0

if install_brew; then
    BREW_OK=1
else
    log "⚠️ Brew no disponible, algunas funciones fallarán"
fi

configure_brew || true

print_stage "Configurando Homebrew"
update_brew_indexes

select_brewfile

if ask_yes_no "¿Instalar navegador alternativo?"; then
    INSTALL_OPTIONAL_APPS="true"
fi

print_stage "Sincronizando paquetes"

if brew_available && [[ -f "$BREWFILE" ]]; then

    TEMP_BREWFILE="/tmp/jb_brewfile.$$"
    cp "$BREWFILE" "$TEMP_BREWFILE"

    if [[ "$INSTALL_OPTIONAL_APPS" != "true" ]]; then
        sed -i '' '/floorp/d' "$TEMP_BREWFILE"
    fi

    EXPECTED_PACKAGES=$(grep '^brew ' "$TEMP_BREWFILE" 2>/dev/null | awk -F'"' '{print $2}' || true)
    EXPECTED_CASKS=$(grep '^cask ' "$TEMP_BREWFILE" 2>/dev/null | awk -F'"' '{print $2}' || true)

    INSTALLED_BREW=$(brew list --formula 2>/dev/null || true)
    INSTALLED_CASKS=$(brew list --cask 2>/dev/null || true)

    build_external_package_list
    print_external_package_summary
    ask_external_package_updates

    build_outdated_package_list
    print_outdated_summary
    update_toolkit_packages
    update_external_packages

    sync_brewfile
    print_installed_summary
fi

print_stage "Detectando hardware"

detect_rosetta
print_hardware_summary
print_optimization_summary

print_stage "Finalizando setup"

print_section "🧠 Resultado final"

success "• Entorno base configurado correctamente"

if (( BREW_OK )); then
    success "• Herramientas sincronizadas"
    success "• Perfil optimizado para este hardware"
else
    warn "• Homebrew no pudo configurarse automáticamente"
fi

success "• Optimización aplicada para este hardware"

cleanup_brewfile

ELAPSED=$SECONDS

print_elapsed_time "$ELAPSED"

if (( BREW_OK )); then
    print_completion "true"
else
    print_completion "false"
fi
