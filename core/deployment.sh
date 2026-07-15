#!/bin/bash

set -Eeuo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/core/utils.sh"
# Session is owned by the jb launcher.
# Only initialize a fallback session when run standalone (outside jb).


init_session
source "$BASE_DIR/core/bootstrap/ui.sh"
source "$BASE_DIR/core/bootstrap/hardware.sh"
source "$BASE_DIR/core/deployment/catalog.sh"
source "$BASE_DIR/core/deployment/doctor.sh"
source "$BASE_DIR/core/deployment/resolve.sh"
source "$BASE_DIR/core/deployment/planner.sh"
source "$BASE_DIR/core/deployment/render.sh"
source "$BASE_DIR/core/deployment/menu.sh"
source "$BASE_DIR/core/deployment/confirm.sh"
source "$BASE_DIR/core/deployment/transaction.sh"
source "$BASE_DIR/core/deployment/install.sh"

set_ui_context "Deployment"

# =========================
# CLI helpers
# =========================
# Every plan command is a different representation of the SAME Deployment
# Plan: build once through the planner, then hand to a renderer. No
# command has planning logic of its own.

require_plan() {

    local mode="$1" profile="$2"

    if [[ -z "$profile" ]]; then
        error_msg "❌ Uso: deployment.sh $mode <perfil>"
        echo ""
        echo "Perfiles disponibles:"
        for id in $(list_profiles); do
            printf "   • %-14s %s\n" "$id" "$(render_profile "$id")"
        done
        exit 1
    fi

    build_deployment_plan "$profile" || exit 1
}

# =========================
# Dispatch
# =========================

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

    --doctor)
        print_banner
        if ! validate_catalog; then
            print_completion "false"
            exit 1
        fi
        run_catalog_doctor
        print_completion "true"
        ;;

    --resolve)
        print_banner
        require_plan "--resolve" "${2:-}"
        render_plan_summary
        print_completion "true"
        ;;

    --explain)
        print_banner
        require_plan "--explain" "${2:-}"
        render_plan
        print_completion "true"
        ;;

    --tree)
        print_banner
        require_plan "--tree" "${2:-}"
        render_plan_tree
        print_completion "true"
        ;;

    --plan)
        print_banner
        require_plan "--plan" "${2:-}"
        PLAN_FILE="$(export_deployment_plan)"
        print_section "🧾 Plan exportado"
        cat "$PLAN_FILE"
        echo ""
        info "ℹ️ Archivo: logs/$(basename "$PLAN_FILE")"
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
        echo ""
        echo "Comandos: --validate | --doctor | --resolve <perfil> | --explain <perfil> | --tree <perfil> | --plan <perfil>"
        exit 1
        ;;

esac
