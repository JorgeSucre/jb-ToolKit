

#!/bin/bash

# =========================
# Homebrew helpers
# =========================

BREW_FRESH_INSTALL=0
BREW_OK=0
BREW_BIN=""
BREW_ALREADY_INSTALLED=0

check_internet_connection() {

    if ping -c 1 github.com >/dev/null 2>&1; then
        return 0
    fi

    echo ""
    error_msg "❌ No se detectó conexión a internet"
    echo "Homebrew requiere acceso a internet para continuar"
    echo ""

    return 1
}

install_brew() {

    if brew_available; then
        BREW_FRESH_INSTALL=0
        BREW_ALREADY_INSTALLED=1
        log "✔ Homebrew ya instalado"
        return 0
    fi

    log "📦 Instalando Homebrew..."

    for i in {1..3}; do

        log "🔁 Intento $i/3..."

        INSTALL_SCRIPT="/tmp/homebrew_install.sh"

        if curl -fsSL \
            --retry 3 \
            --retry-delay 2 \
            --connect-timeout 5 \
            https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh \
            -o "$INSTALL_SCRIPT"; then

            chmod +x "$INSTALL_SCRIPT"

            echo ""
            info "ℹ️ Homebrew puede solicitar contraseña y confirmación de instalación"
            echo ""

            if run_cmd --visible /bin/bash "$INSTALL_SCRIPT"; then

                BREW_FRESH_INSTALL=1
                log "✔ Instalador de Homebrew finalizado"

                if configure_brew && validate_brew; then
                    log "✔ Homebrew instalado y validado correctamente"
                    return 0
                fi

                warn "⚠️ El instalador terminó, pero Homebrew no quedó disponible"
            fi

            warn "⚠️ Homebrew no pudo instalarse correctamente"

            if (( ! HAS_SUDO )); then
                log "ℹ️ La cuenta actual no tiene privilegios administrativos"
            else
                log "ℹ️ Verifica la contraseña sudo o permisos del sistema"
            fi

        else
            warn "⚠️ No se pudo descargar el instalador de Homebrew"
        fi

        sleep 5
    done

    log "❌ No se pudo instalar Homebrew"

    return 1
}

configure_brew() {

    for path in \
        "/opt/homebrew/bin/brew" \
        "/usr/local/bin/brew"; do

        if [[ -x "$path" ]]; then
            BREW_BIN="$path"
            break
        fi

    done

    if [[ -z "$BREW_BIN" ]] && command -v brew &>/dev/null; then
        BREW_BIN="$(command -v brew)"
    fi

    if [[ -z "$BREW_BIN" ]]; then
        log "❌ brew sigue sin estar disponible en PATH"
        return 1
    fi

    local shellenv
    shellenv="$("$BREW_BIN" shellenv 2>/dev/null)" || {
        error_msg "❌ No se pudo obtener brew shellenv"
        return 1
    }
    eval "$shellenv"

    export PATH="$(dirname "$BREW_BIN"):$PATH"

    command -v brew >/dev/null 2>&1 || {
        error_msg "❌ brew no quedó disponible en PATH"
        return 1
    }

    if (( ! BREW_ALREADY_INSTALLED )); then
        log "✔ brew listo para usarse"
    fi

    return 0
}

validate_brew() {
    if ! command -v brew >/dev/null 2>&1; then
        error_msg "❌ Homebrew no está disponible en PATH después de la instalación"
        return 1
    fi

    if ! brew --version >/dev/null 2>&1; then
        error_msg "❌ Homebrew está en PATH, pero no responde correctamente"
        return 1
    fi

    BREW_BIN="$(command -v brew)"
    BREW_OK=1
}

update_brew_indexes() {

    if ! brew_available; then
        warn "⚠️ Homebrew no disponible, se omite actualización"
        return 0
    fi

    print_section "📦 Homebrew"

    if (( BREW_FRESH_INSTALL )); then
        success "✔ Homebrew recién instalado, actualización omitida"
        return 0
    fi

    BREW_REPO=$(brew --repository 2>/dev/null || true)
    RECENT_UPDATE=""

    if [[ -n "$BREW_REPO" ]]; then
        RECENT_UPDATE=$(find "$BREW_REPO" -name FETCH_HEAD -mtime -1 2>/dev/null || true)
    fi

    if [[ -n "$RECENT_UPDATE" ]]; then
        success "✔ Índices recientes detectados"
        return 0
    fi

    log "🔄 Actualizando índices Homebrew..."

    if HOMEBREW_NO_ENV_HINTS=1 run_cmd brew update; then
        success "✔ Índices Homebrew sincronizados"
    else
        warn "⚠️ No se pudieron actualizar los índices de Homebrew"
        return 1
    fi
}

# Base CLI tools the toolkit itself depends on (Diagnostics and Report use
# fastfetch). Installed through the engine pattern and verified afterward.
ensure_base_tools() {

    if brew_formula_installed "fastfetch"; then
        success "✔ fastfetch disponible"
        return 0
    fi

    log "📦 Instalando fastfetch (herramienta base del toolkit)..."

    if ! HOMEBREW_NO_ENV_HINTS=1 retry 3 5 run_cmd --visible brew install fastfetch; then
        warn "⚠️ La instalación de fastfetch reportó errores"
    fi

    brew_cache_reset

    if brew_formula_installed "fastfetch"; then
        success "✔ fastfetch instalado y verificado"
        return 0
    fi

    error_msg "❌ fastfetch no quedó instalado"
    return 1
}

# Pending updates for everything Homebrew manages on this machine.
# Preview → confirm → upgrade each → verify with a fresh outdated query.
offer_package_updates() {

    local pkg pkg_name count remaining
    local -a queue=()

    print_section "📚 Actualizaciones pendientes"

    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] && queue+=("$pkg")
    done <<< "$(brew_outdated_formula)"$'\n'"$(brew_outdated_cask)"

    count="${#queue[@]}"

    if [[ "$count" -eq 0 ]]; then
        success "✔ No se detectaron actualizaciones pendientes"
        return 0
    fi

    warn "📋 $count paquetes tienen actualizaciones disponibles"
    echo ""

    for pkg in "${queue[@]}"; do
        echo "   • ${pkg%% *}"
    done
    echo ""

    if ! ask_yes_no "¿Actualizar ahora?"; then
        info "ℹ️ Actualizaciones omitidas"
        return 0
    fi

    for pkg in "${queue[@]}"; do
        pkg_name="${pkg%% *}"
        echo "   • $pkg_name"
        brew_upgrade_package "$pkg_name" || warn "⚠️ No se pudo actualizar $pkg_name"
    done

    run_cmd brew cleanup -s || warn "⚠️ Homebrew cleanup no pudo completarse"
    brew_cache_reset

    remaining=$(( $(brew_outdated_formula | grep -c . || true) \
        + $(brew_outdated_cask | grep -c . || true) ))

    if [[ "$remaining" -eq 0 ]]; then
        success "✔ Todos los paquetes quedaron actualizados"
    else
        warn "⚠️ Quedan $remaining paquetes sin actualizar"
    fi
}
