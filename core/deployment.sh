#!/bin/bash

set -Eeuo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/core/utils.sh"
# Session is owned by the jb launcher.
# Only initialize a fallback session when run standalone (outside jb).


init_session
source "$BASE_DIR/core/bootstrap/ui.sh"
source "$BASE_DIR/core/deployment/catalog.sh"
source "$BASE_DIR/core/deployment/resolve.sh"

set_ui_context "Deployment"

# =========================
# Resolution report (developer/CLI view)
# =========================

print_resolution() {

    local profile="$1"
    local bundle app entry name count

    print_section "📦 Resolución del perfil"

    printf "Perfil:       %s\n" "$(profile_field "$profile" NAME)"
    printf "Descripción:  %s\n" "$(profile_field "$profile" DESCRIPTION)"

    echo ""
    echo "Bundles:"

    while IFS= read -r bundle; do
        [[ -z "$bundle" ]] && continue
        count=$(bundle_apps "$bundle" | sed '/^$/d' | wc -l | tr -d ' ')
        printf "   • %s (%s aplicaciones)\n" "$(bundle_display_name "$bundle")" "$count"
    done < <(profile_bundles "$profile")

    resolve_install_set "$profile"

    count=$(printf "%s" "$RESOLVED_APPS" | sed '/^$/d' | wc -l | tr -d ' ')

    echo ""
    echo "Aplicaciones a instalar ($count):"

    while IFS= read -r app; do
        [[ -z "$app" ]] && continue
        printf "   • %s\n" "$(app_field "$app" NAME)"
    done <<< "$RESOLVED_APPS"

    if [[ -n "$RESOLVED_SKIPPED" ]]; then
        echo ""
        echo "Omitidas por compatibilidad:"

        while IFS= read -r entry; do
            [[ -z "$entry" ]] && continue
            name="$(app_field "${entry%%|*}" NAME)"
            printf "   • %s — %s\n" "$name" "${entry#*|}"
        done <<< "$RESOLVED_SKIPPED"
    fi
}

# =========================
# CLI dispatch
# =========================
# Phase 3 exposes catalog tooling only. The interactive deployment
# experience (menus, confirmation, installation) arrives in Phases 4–5.

case "${1:-}" in

    --validate)
        print_banner
        if validate_catalog; then
            print_completion "true"
        else
            print_completion "false"
            exit 1
        fi
        ;;

    --resolve)
        PROFILE_ID="${2:-}"

        print_banner

        if [[ -z "$PROFILE_ID" ]]; then
            error_msg "❌ Uso: deployment.sh --resolve <perfil>"
            echo ""
            echo "Perfiles disponibles:"
            for id in $(list_profiles); do
                printf "   • %s\n" "$id"
            done
            exit 1
        fi

        if ! profile_exists "$PROFILE_ID"; then
            error_msg "❌ El perfil no existe: $PROFILE_ID"
            exit 1
        fi

        print_resolution "$PROFILE_ID"
        print_completion "true"
        ;;

    "")
        print_banner
        echo ""
        info "ℹ️ El módulo interactivo de Deployment estará disponible en una próxima versión"
        info "ℹ️ Herramientas disponibles: --validate | --resolve <perfil>"
        ;;

    *)
        error_msg "❌ Opción no reconocida: $1"
        exit 1
        ;;

esac
