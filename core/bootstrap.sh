#!/bin/bash

set -Eeuo pipefail

SECONDS=0
STAGE_START_TIME=0
CURRENT_STAGE=1
TOTAL_STAGES=5

BASE_DIR="${BASE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$BASE_DIR/core/utils.sh"
# Session is owned by the jb launcher.
# Only initialize a fallback session when run standalone (outside jb).


init_session
source "$BASE_DIR/core/bootstrap/ui.sh"
source "$BASE_DIR/core/bootstrap/stages.sh"
source "$BASE_DIR/core/bootstrap/brew.sh"
source "$BASE_DIR/core/bootstrap/hardware.sh"

# Deployment library — Bootstrap's software step consumes the same
# catalog, planner, and installer as the Deployment module. Bootstrap
# owns no software selection of its own.
source "$BASE_DIR/core/deployment/catalog.sh"
source "$BASE_DIR/core/deployment/selection.sh"
source "$BASE_DIR/core/deployment/planner.sh"
source "$BASE_DIR/core/deployment/render.sh"
source "$BASE_DIR/core/deployment/menu.sh"
source "$BASE_DIR/core/deployment/confirm.sh"
source "$BASE_DIR/core/deployment/transaction.sh"
source "$BASE_DIR/core/deployment/install.sh"
source "$BASE_DIR/core/bootstrap/wizard.sh"

set_ui_context "Bootstrap"

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

if ! ensure_base_tools; then
    print_completion "false"
    exit 1
fi

offer_package_updates

print_stage "Detectando hardware"
detect_rosetta
print_hardware_summary

print_stage "Preparando el equipo"
run_onboarding_wizard

print_stage "Finalizando setup"

print_optimization_summary

print_section "🧠 Resultado final"

success "• Entorno base configurado correctamente"

if [[ -n "$TXN_RESULT" && "$TXN_RESULT" != "cancelled" ]]; then
    success "• Software desplegado con la plantilla ${PLAN_PRESET_NAME:-N/A}"
else
    info "• Despliegue de software omitido"
fi

success "• Perfil optimizado para este hardware"

ELAPSED=$SECONDS

print_elapsed_time "$ELAPSED"

if (( BREW_OK )); then
    print_completion "true"
else
    print_completion "false"
fi
