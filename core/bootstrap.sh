#!/bin/bash

set -Eeuo pipefail

SECONDS=0
STAGE_START_TIME=0
CURRENT_STAGE=1
TOTAL_STAGES=5

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/core/utils.sh"
# Session is owned by the jb launcher.
# Only initialize a fallback session when run standalone (outside jb).


init_session
source "$BASE_DIR/core/bootstrap/ui.sh"
source "$BASE_DIR/core/bootstrap/stages.sh"
source "$BASE_DIR/core/bootstrap/brew.sh"
source "$BASE_DIR/core/bootstrap/packages.sh"
source "$BASE_DIR/core/bootstrap/hardware.sh"
source "$BASE_DIR/core/docs.sh"
set_ui_context "Bootstrap"

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

BREW_OK=0

if ! install_brew; then
    error_msg "❌ Bootstrap no puede continuar sin Homebrew"
    print_completion "false"
    exit 1
fi

if ! configure_brew || ! validate_brew; then
    error_msg "❌ Homebrew no está disponible después de la instalación"
    print_completion "false"
    exit 1
fi
BREW_OK=1

print_stage "Configurando Homebrew"
update_brew_indexes || info "ℹ️ Se intentará continuar con los índices disponibles"

print_stage "Detectando hardware"
detect_rosetta
print_hardware_summary
select_brewfile || exit 1

offer_hardware_recommendations

print_section "📚 Documentación de herramientas"
if ask_yes_no "¿Deseas revisar la documentación de las aplicaciones recomendadas antes de instalar?"; then
    docs_main
    set_ui_context "Bootstrap"
fi

select_optional_packages

print_stage "Sincronizando paquetes"

prepare_brewfile
if [[ ! -f "$TEMP_BREWFILE" ]]; then
    error_msg "❌ No se pudo preparar el Brewfile"
    exit 1
fi
if ! filter_brewfile_to_selection; then
    cleanup_brewfile
    print_completion "false"
    exit 1
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

if ! sync_brewfile; then
    error_msg "❌ No se pudo completar brew bundle"
    cleanup_brewfile
    print_completion "false"
    exit 1
fi

if ! brew list --formula fastfetch >/dev/null 2>&1; then
    error_msg "❌ fastfetch no quedó instalado después de brew bundle"
    cleanup_brewfile
    print_completion "false"
    exit 1
fi
print_installed_summary

print_optimization_summary

print_stage "Finalizando setup"

print_section "🧠 Resultado final"

success "• Entorno base configurado correctamente"

if (( BREW_OK )); then
    success "• Herramientas sincronizadas"
else
    warn "• Homebrew no pudo configurarse automáticamente"
fi

success "• Perfil optimizado para este hardware"

cleanup_brewfile

ELAPSED=$SECONDS

print_elapsed_time "$ELAPSED"

if (( BREW_OK )); then
    print_completion "true"
else
    print_completion "false"
fi
