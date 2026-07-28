#!/bin/bash

# =========================
# Onboarding wizard
# =========================
# Bootstrap's software step. The wizard owns NO software selection logic:
# it asks one question — how will this Mac be used? — and hands the answer
# to the same Deployment pipeline (catalog -> selection -> plan ->
# installer) the Deployment module uses standalone. There is one catalog,
# one selection model, one planner, and one installer in the toolkit; this
# screen only supplies its own framing text and exit wording, then calls
# straight into start_deployment_flow — the same function the Deployment
# menu's preset picker calls.

run_onboarding_wizard() {

    local preset_id choice index count
    local -a preset_ids=()

    if ! validate_catalog; then
        warn "⚠️ Catálogo inválido; se omite el despliegue de software"
        info "ℹ️ Corrige el catálogo y usa el módulo Deployment más tarde"
        return 0
    fi

    while true; do

        preset_ids=()
        while IFS= read -r preset_id; do
            [[ -n "$preset_id" ]] && preset_ids+=("$preset_id")
        done < <(list_presets_ordered)

        count="${#preset_ids[@]}"

        print_section "🚀 ¿Cómo se usará este Mac?"
        echo ""

        for ((index=0; index<count; index++)); do
            render_category "$((index + 1))" "$(render_preset "${preset_ids[$index]}")" 0
        done

        render_category "$((count + 1))" "Empezar vacío" 0
        echo "0) Omitir despliegue de software"
        echo ""
        printf "Selecciona una opción: "
        read -r choice || choice="0"

        if [[ "$choice" == "0" ]]; then
            info "ℹ️ Despliegue omitido; disponible luego en el módulo Deployment"
            return 0
        elif [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le "$count" ]]; then
            start_deployment_flow "${preset_ids[$((choice - 1))]}"
        elif [[ "$choice" == "$((count + 1))" ]]; then
            start_deployment_flow ""
        else
            warn "⚠️ Opción inválida"
        fi

        # A deployment was executed (any recorded outcome except a
        # cancellation) → the wizard's question is answered
        if [[ -n "${TXN_RESULT:-}" && "$TXN_RESULT" != "cancelled" ]]; then
            return 0
        fi

    done
}
