#!/bin/bash

set -Eeuo pipefail

BASE_DIR="${BASE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$BASE_DIR/core/utils.sh"
# Session is owned by the jb launcher.
# Only initialize a fallback session when run standalone (outside jb).


init_session
source "$BASE_DIR/core/bootstrap/ui.sh"
source "$BASE_DIR/core/bootstrap/hardware.sh"
source "$BASE_DIR/core/deployment/catalog.sh"
source "$BASE_DIR/core/deployment/doctor.sh"
source "$BASE_DIR/core/deployment/selection.sh"
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
# Plan: load the named preset into a fresh selection (no manual editing —
# that's an interactive-only concept), build the plan once, then hand to a
# renderer. No command has planning logic of its own.

require_plan() {

    local mode="$1" preset="$2"

    if [[ -z "$preset" ]]; then
        error_msg "❌ Uso: deployment.sh $mode <preset>"
        echo ""
        echo "Presets disponibles:"
        for id in $(list_presets_ordered); do
            printf "   • %-14s %s\n" "$id" "$(render_preset "$id")"
        done
        exit 1
    fi

    if ! preset_exists "$preset"; then
        error_msg "❌ El preset no existe: $preset"
        exit 1
    fi

    load_preset_into_selection "$preset"
    build_plan_from_selection "$preset"
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
        echo "Comandos: --validate | --doctor | --resolve <preset> | --explain <preset> | --tree <preset> | --plan <preset>"
        exit 1
        ;;

esac
