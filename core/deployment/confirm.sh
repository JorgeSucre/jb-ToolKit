#!/bin/bash

# =========================
# Deployment confirmation
# =========================
# Final review of the Deployment Plan. [I] executes the exact plan shown
# here through the installer (which decides nothing); a y/n gate inside
# run_plan_installation is the last stop before the system changes.

run_plan_confirmation() {

    local choice

    [[ "$PLAN_READY" -eq 1 ]] || return 0

    while true; do

        render_confirmation

        echo ""
        echo "[E] Explicar plan   [G] Ver árbol   [I] Instalar   [0] Volver"
        printf "Selecciona una opción: "
        read -r choice || choice="0"

        case "$choice" in

            [Ee])
                render_plan
                ;;

            [Gg])
                render_plan_tree
                ;;

            [Ii])
                # Executed (any outcome) → the review is over, results are
                # on record. Cancelled at the y/n gate or blocked (no brew)
                # → stay on the confirmation screen.
                if run_plan_installation && [[ "$TXN_RESULT" != "cancelled" ]]; then
                    return 0
                fi
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
