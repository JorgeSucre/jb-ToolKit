

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

select_brewfile() {

    if [[ -f "$BASE_DIR/Brewfile" ]]; then
        BREWFILE="$BASE_DIR/Brewfile"
    elif [[ -f "$BASE_DIR/brewfile" ]]; then
        BREWFILE="$BASE_DIR/brewfile"
    else
        error_msg "❌ No se encontró Brewfile ni brewfile"
        return 1
    fi
    ARCH_NAME="$(uname -m)"

    if [[ "$ARCH_NAME" == "arm64" ]]; then

        [[ -f "$BASE_DIR/Brewfile.apple" ]] && BREWFILE="$BASE_DIR/Brewfile.apple"

        info "🧠 Perfil Apple Silicon detectado"

    else

        [[ -f "$BASE_DIR/Brewfile.intel" ]] && BREWFILE="$BASE_DIR/Brewfile.intel"

        info "🧠 Perfil Intel detectado"
    fi
}

prepare_brewfile() {

    TEMP_BREWFILE="/tmp/jb_brewfile.$$"

    cp "$BREWFILE" "$TEMP_BREWFILE" || return 1

}

sync_brewfile() {

    INSTALL_COUNT=$(grep -Ec '^(brew|cask) ' "$TEMP_BREWFILE" 2>/dev/null \
        || true)
    INSTALL_COUNT=${INSTALL_COUNT:-0}

    log "📦 Aplicando $(basename "$BREWFILE")..."

    echo ""

    info "ℹ️ Instalando ${INSTALL_COUNT} paquetes y aplicaciones... esto puede tardar varios minutos"
    info "ℹ️ Homebrew mostrará progreso automáticamente"

    echo ""

    if retry 3 5 run_cmd --visible "$BREW_BIN" bundle --file="$TEMP_BREWFILE"; then

        success "✔ Brewfile sincronizado correctamente"

        return 0
    fi

    warn "⚠️ Brew bundle encontró algunos problemas"

    return 1
}

cleanup_brewfile() {

    if [[ -n "${TEMP_BREWFILE:-}" ]]; then
        rm -f "$TEMP_BREWFILE" 2>/dev/null || true
    fi
}
