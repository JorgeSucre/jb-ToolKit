#!/bin/bash

# =========================
# Onboarding wizard
# =========================
# Bootstrap's software step. The wizard owns NO software selection logic:
# it asks one question — how will this Mac be used? — and hands the answer
# to the Deployment pipeline (catalog → planner → installer). There is one
# catalog, one planner, and one installer in the toolkit; this screen is
# just another consumer of them, generated from the same catalog data as
# the Deployment menu.

run_onboarding_wizard() {

    local category choice index count
    local -a categories=()

    if ! validate_catalog; then
        warn "⚠️ Catálogo inválido; se omite el despliegue de software"
        info "ℹ️ Corrige el catálogo y usa el módulo Deployment más tarde"
        return 0
    fi

    while true; do

        categories=()
        while IFS= read -r category; do
            [[ -n "$category" ]] && categories+=("$category")
        done < <(list_categories)

        count="${#categories[@]}"

        print_section "🚀 ¿Cómo se usará este Mac?"
        echo ""

        for ((index=0; index<count; index++)); do
            category="${categories[$index]}"
            if [[ -n "$(category_direct_profile "$category")" ]]; then
                render_category "$((index + 1))" "$category" 0
            else
                render_category "$((index + 1))" "$category" 1
            fi
        done

        render_category "$((count + 1))" "Personalizado (combinar bundles)" 0
        echo "0) Omitir despliegue de software"
        echo ""
        printf "Selecciona una opción: "
        read -r choice || choice="0"

        if [[ "$choice" == "0" ]]; then
            info "ℹ️ Despliegue omitido; disponible luego en el módulo Deployment"
            return 0
        elif [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le "$count" ]]; then
            open_category "${categories[$((choice - 1))]}"
        elif [[ "$choice" == "$((count + 1))" ]]; then
            run_custom_flow
        else
            warn "⚠️ Opción inválida"
        fi

        # A deployment was executed (any recorded outcome except a
        # cancellation) → the wizard's question is answered
        if [[ -n "$TXN_RESULT" && "$TXN_RESULT" != "cancelled" ]]; then
            return 0
        fi

    done
}
