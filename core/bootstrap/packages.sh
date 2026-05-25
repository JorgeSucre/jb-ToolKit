#!/bin/bash

# =========================
# Package helpers
# =========================

EXTRA_PACKAGES=""
TOOLKIT_OUTDATED=""

# =========================
# External packages
# =========================

append_external_packages() {

    local installed="$1"
    local expected="$2"
    local prefix="$3"

    while IFS= read -r item; do

        [[ -z "$item" ]] && continue

        if ! grep -qx "$item" <<< "$expected"; then
            EXTRA_PACKAGES+="${prefix}:${item}"$'\n'
        fi

    done <<< "$installed"
}

build_external_package_list() {

    append_external_packages \
        "$INSTALLED_BREW" \
        "$EXPECTED_PACKAGES" \
        "brew"

    append_external_packages \
        "$INSTALLED_CASKS" \
        "$EXPECTED_CASKS" \
        "cask"
}

print_external_package_summary() {

    EXTRA_COUNT=$(printf "%s" "$EXTRA_PACKAGES" \
        | sed '/^$/d' \
        | wc -l \
        | tr -d ' ')

    [[ "$EXTRA_COUNT" -eq 0 ]] && return 0

    print_section "📦 Paquetes detectados fuera del Brewfile"

    warn "Se detectaron herramientas instaladas fuera del toolkit"
    info "ℹ️ Esto es normal en sistemas ya configurados"

    echo ""
    echo "Principales detectados:"
    echo ""

    KNOWN_PACKAGES=$( \
        printf "%s" "$EXTRA_PACKAGES" \
            | sed '/^$/d' \
            | sed 's/^brew://g' \
            | sed 's/^cask://g' \
            | head -5 \
            | sed 's/^/   • /'
    ) || true

    if [[ -n "$KNOWN_PACKAGES" ]]; then
        printf "%s\n" "$KNOWN_PACKAGES"
    else
        echo "   • Herramientas de desarrollo y dependencias detectadas"
    fi
}

ask_external_package_updates() {

    UPDATE_EXTRA_PACKAGES="false"

    [[ "$EXTRA_COUNT" -eq 0 ]] && return 0

    echo ""

    if ask_yes_no "¿Actualizar también los paquetes externos al Brewfile?"; then
        UPDATE_EXTRA_PACKAGES="true"
    fi
}

update_external_packages() {

    [[ "$UPDATE_EXTRA_PACKAGES" != "true" ]] && return 0

    print_section "📦 Paquetes externos al Brewfile"

    log "⬆️ Actualizando paquetes externos..."

    OUTDATED_EXTERNAL=$(brew outdated 2>/dev/null || true)

    if [[ -z "$OUTDATED_EXTERNAL" ]]; then
        success "✔ No había paquetes externos pendientes"
        return 0
    fi

    while IFS= read -r pkg; do

        [[ -z "$pkg" ]] && continue

        pkg_name=$(awk '{print $1}' <<< "$pkg")

        echo "   • $pkg_name"

        HOMEBREW_NO_ENV_HINTS=1 brew upgrade "$pkg_name" >/dev/null 2>&1 || true

    done <<< "$OUTDATED_EXTERNAL"

    success "✔ Paquetes externos actualizados"
}

# =========================
# Outdated toolkit packages
# =========================

append_outdated() {

    local installed="$1"
    local outdated="$2"

    while IFS= read -r item; do

        [[ -z "$item" ]] && continue

        if grep -qx "$item" <<< "$outdated"; then
            TOOLKIT_OUTDATED+="$item"$'\n'
        fi

    done <<< "$installed"
}

build_outdated_package_list() {

    OUTDATED_FORMULAS=$(brew outdated --formula 2>/dev/null || true)
    OUTDATED_CASKS=$(brew outdated --cask 2>/dev/null || true)

    append_outdated \
        "$EXPECTED_PACKAGES" \
        "$OUTDATED_FORMULAS"

    append_outdated \
        "$EXPECTED_CASKS" \
        "$OUTDATED_CASKS"
}

print_outdated_summary() {

    TOOLKIT_OUTDATED_COUNT=$(printf "%s" "$TOOLKIT_OUTDATED" \
        | sed '/^$/d' \
        | wc -l \
        | tr -d ' ')

    print_section "📚 Configuración de paquetes"

    if [[ "$TOOLKIT_OUTDATED_COUNT" -eq 0 ]]; then
        success "✔ No se detectaron actualizaciones pendientes del toolkit"
        return 0
    fi

    warn "📋 ${TOOLKIT_OUTDATED_COUNT} paquetes del toolkit requieren actualización"

    echo ""

    while IFS= read -r pkg; do

        [[ -z "$pkg" ]] && continue

        echo "   • $pkg"

    done <<< "$TOOLKIT_OUTDATED"
}

update_toolkit_packages() {

    [[ "$TOOLKIT_OUTDATED_COUNT" -eq 0 ]] && return 0

    echo ""

    log "⬆️ Actualizando paquetes del toolkit..."

    while IFS= read -r pkg; do

        [[ -z "$pkg" ]] && continue

        pkg_name=$(awk '{print $1}' <<< "$pkg")

        echo "   • $pkg_name"

        HOMEBREW_NO_ENV_HINTS=1 brew upgrade "$pkg_name" >/dev/null 2>&1 || true

    done <<< "$TOOLKIT_OUTDATED"

    brew cleanup -s >/dev/null 2>&1 || true

    echo ""

    success "✔ Paquetes del toolkit actualizados correctamente"
}

# =========================
# Installed package summary
# =========================

print_installed_summary() {

    INSTALLED_SUMMARY=$(grep -E '^(brew|cask)' "$TEMP_BREWFILE" \
        | awk -F'"' '{print $2}' \
        | head -10)

    [[ -z "$INSTALLED_SUMMARY" ]] && return 0

    print_section "📦 Herramientas principales disponibles"

    while IFS= read -r item; do

        [[ -z "$item" ]] && continue

        printf "• %s\n" "$item"

    done <<< "$INSTALLED_SUMMARY"
}