#!/bin/bash

# =========================
# Deployment confirmation
# =========================
# Final Phase 4 screen: the plan is complete and reviewable; installation
# is intentionally disabled until the Phase 5 engine exists. The plan the
# user confirms here is exactly the plan the installer will execute.

run_plan_confirmation() {

    local choice

    [[ "$PLAN_READY" -eq 1 ]] || return 0

    while true; do

        render_confirmation

        echo ""
        echo "[E] Explicar plan   [G] Ver árbol   [I] Instalar (no disponible)   [0] Volver"
        printf "Selecciona una opción: "
        read -r choice

        case "$choice" in

            [Ee])
                render_plan
                ;;

            [Gg])
                render_plan_tree
                ;;

            [Ii])
                warn "⚠️ La instalación aún no está disponible en esta versión"
                info "ℹ️ El plan está completo; la ejecución llegará en la próxima fase"
                ;;

            0|[Bb])
                return 0
                ;;

            *)
                warn "⚠️ Opción inválida"
                ;;

        esac

    done
}
