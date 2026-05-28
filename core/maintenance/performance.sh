#!/bin/bash

# =========================
# Performance optimization
# =========================

PERFORMANCE_PROFILE="none"

IS_APPLE_SILICON="false"

if [[ "$(uname -m)" == "arm64" ]]; then
    IS_APPLE_SILICON="true"
fi

# =========================
# Light optimization
# =========================

apply_light_optimization() {

    local silent="${1:-false}"

    PERFORMANCE_PROFILE="light"

    log "⚡ Aplicando optimización ligera..."

    # Reduce Motion
    defaults write com.apple.universalaccess \
        reduceMotion -bool true 2>/dev/null || true

    # Reduce Transparency
    defaults write com.apple.universalaccess \
        reduceTransparency -bool true 2>/dev/null || true

    # Disable window animations
    defaults write NSGlobalDomain \
        NSAutomaticWindowAnimationsEnabled -bool false \
        >/dev/null 2>&1 || true

    # Faster Dock animations
    defaults write com.apple.dock \
        autohide-time-modifier -float 0.15 \
        >/dev/null 2>&1 || true

    defaults write com.apple.dock \
        expose-animation-duration -float 0.1 \
        >/dev/null 2>&1 || true

    killall Dock >/dev/null 2>&1 || true

    if [[ "$silent" != "true" ]]; then
        success "✔ Optimización ligera aplicada"
    fi
}

# =========================
# Aggressive optimization
# =========================

apply_aggressive_optimization() {

    PERFORMANCE_PROFILE="aggressive"

    log "⚡ Aplicando optimización agresiva..."

    apply_light_optimization "true"

    # Personalized ads
    defaults write com.apple.AdLib \
        allowApplePersonalizedAdvertising -bool false \
        >/dev/null 2>&1 || true

    # Siri / assistant optimizations
    if [[ "$IS_APPLE_SILICON" != "true" ]]; then

        defaults write com.apple.assistant.support \
            'Assistant Enabled' -bool false \
            >/dev/null 2>&1 || true

        defaults write com.apple.Siri \
            StatusMenuVisible -bool false \
            >/dev/null 2>&1 || true

    fi

    # Startup apps cleanup
    for app in \
        Discord \
        Steam \
        EpicGamesLauncher \
        Microsoft\ Teams \
        Spotify; do

        osascript <<EOF >/dev/null 2>&1
        tell application "System Events"
            delete every login item whose name is "$app"
        end tell
EOF

    done

    success "✔ Optimización agresiva aplicada"

    echo "• Animaciones reducidas"
    echo "• Transparencias reducidas"
    echo "• Apps de inicio optimizadas"
    echo "• Procesos secundarios reducidos"

    info "ℹ️ Se redujeron procesos visuales y apps secundarias de inicio"
}

# =========================
# Restore defaults
# =========================

restore_performance_defaults() {

    PERFORMANCE_PROFILE="default"

    log "🔄 Restaurando configuración por defecto..."

    defaults delete com.apple.universalaccess \
        reduceMotion >/dev/null 2>&1 || true

    defaults delete com.apple.universalaccess \
        reduceTransparency >/dev/null 2>&1 || true

    defaults delete NSGlobalDomain \
        NSAutomaticWindowAnimationsEnabled >/dev/null 2>&1 || true

    defaults delete com.apple.dock \
        autohide-time-modifier >/dev/null 2>&1 || true

    defaults delete com.apple.dock \
        expose-animation-duration >/dev/null 2>&1 || true

    defaults delete com.apple.AdLib \
        allowApplePersonalizedAdvertising >/dev/null 2>&1 || true

    defaults delete com.apple.assistant.support \
        'Assistant Enabled' >/dev/null 2>&1 || true

    defaults delete com.apple.Siri \
        StatusMenuVisible >/dev/null 2>&1 || true

    killall Dock >/dev/null 2>&1 || true

    success "✔ Configuración por defecto restaurada"
}

# =========================
# Performance menu
# =========================

run_performance_optimization() {

    echo ""
    print_section "⚡ Optimización de rendimiento"

    echo "1) Ligera (recomendado y seguro)"
    echo "2) Agresiva"
    echo "3) Restaurar valores por defecto"
    echo "0) Omitir"

    echo ""

    printf "Selecciona una opción: "

    read -r PERFORMANCE_MODE

    case "$PERFORMANCE_MODE" in

        1)
            apply_light_optimization
            ;;

        2)
            echo ""

            warn "⚠️ Este modo reduce efectos visuales y algunos procesos en segundo plano"

            printf "¿Continuar? (y/n): "

            read -r AGGRESSIVE_CONFIRM

            if [[ "$AGGRESSIVE_CONFIRM" =~ ^[YySs]$ ]]; then
                apply_aggressive_optimization
            else
                warn "⚠️ Optimización agresiva cancelada"
            fi
            ;;

        3)
            restore_performance_defaults
            ;;

        *)
            PERFORMANCE_PROFILE="none"
            info "ℹ️ Optimización omitida"
            ;;

    esac

    if [[ "$PERFORMANCE_PROFILE" != "none" ]]; then

        echo ""

        info "ℹ️ Algunas configuraciones pueden requerir cerrar sesión para aplicarse completamente"
    fi
}