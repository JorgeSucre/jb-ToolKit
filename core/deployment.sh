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
source "$BASE_DIR/core/deployment/planner.sh"
source "$BASE_DIR/core/deployment/render.sh"
source "$BASE_DIR/core/deployment/menu.sh"
source "$BASE_DIR/core/deployment/confirm.sh"

set_ui_context "Deployment"

# =========================
# Dispatch
# =========================
# Interactive: catalog-generated menus → planner → confirmation.
# CLI tools (--validate / --resolve / --tree) support catalog maintenance.
# Nothing in this module modifies the system; installation arrives in
# Phase 5 and will execute the plan built here.

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

    --resolve|--tree)
        MODE="$1"
        PROFILE_ID="${2:-}"

        print_banner

        if [[ -z "$PROFILE_ID" ]]; then
            error_msg "❌ Uso: deployment.sh $MODE <perfil>"
            echo ""
            echo "Perfiles disponibles:"
            for id in $(list_profiles); do
                printf "   • %s\n" "$id"
            done
            exit 1
        fi

        if ! build_deployment_plan "$PROFILE_ID"; then
            exit 1
        fi

        if [[ "$MODE" == "--tree" ]]; then
            render_plan_tree
        else
            render_plan
        fi

        print_completion "true"
        ;;

    "")
        print_banner

        if ! validate_catalog; then
            error_msg "❌ Corrige el catálogo antes de continuar"
            print_completion "false"
            exit 1
        fi

        run_deployment_menu

        print_completion "true"
        ;;

    *)
        error_msg "❌ Opción no reconocida: $1"
        exit 1
        ;;

esac
