#!/bin/bash

# =========================
# Deployment menus
# =========================
# One workflow, one selection model. Navigation is generated entirely from
# catalog data (list_presets_ordered, list_app_categories) — no preset or
# category name is hardcoded here.
#
# Flow: Quick Presets (optional) -> Application Catalog -> confirm.sh's
# review/confirmation screen -> install. Whether an application entered the
# selection via a preset, a hardware recommendation, or a manual toggle,
# it is the exact same kind of member of SELECTED_APPS by the time the
# Application Catalog screen (or the plan) sees it — see selection.sh.

# =========================
# Application Catalog — the one screen everything else feeds into. Groups
# applications by CATEGORY for browsing; toggling is a flat, continuously
# numbered list so parse_selection's "1,3-5" syntax works across the whole
# screen regardless of category boundaries. An incompatible application is
# shown with its reason instead of a checkbox — never selectable, never a
# silent gap in the numbering scheme technicians rely on.
# =========================

# run_application_catalog — interactive toggle loop over SELECTED_APPS.
# Returns 1 if the technician cancels (0), 0 otherwise (Enter to continue).
run_application_catalog() {

    local tag id reason selection item mark note pick provenance
    local -a categories=()
    local -a app_ids=()

    while IFS= read -r tag; do
        [[ -n "$tag" ]] && categories+=("$tag")
    done < <(list_app_categories)

    while true; do

        app_ids=()

        print_section "🗂️ Catálogo de aplicaciones"
        printf "Seleccionadas: %s\n" "$(selection_count)"

        for tag in "${categories[@]}"; do

            local -a cat_apps=()
            while IFS= read -r id; do
                [[ -n "$id" ]] && cat_apps+=("$id")
            done < <(apps_in_category "$tag")

            [[ "${#cat_apps[@]}" -eq 0 ]] && continue

            echo ""
            printf -- "── %s ──\n" "$tag"

            for id in "${cat_apps[@]}"; do

                if reason="$(app_incompatibility_reason "$id")"; then

                    app_ids+=("$id")

                    mark=" "
                    note=""
                    if selection_contains "$id"; then
                        mark="✓"
                        provenance="$(selection_provenance "$id")"
                        case "$provenance" in
                            preset:*) note="  · de la plantilla" ;;
                            hardware) note="  · recomendado para tu equipo ★" ;;
                        esac
                    fi

                    pick=""
                    [[ "$(app_field "$id" JB_PICK)" == "true" ]] && pick="  · JB Pick ⭐"

                    printf "[%s] %2d) %s%s%s\n" "$mark" "${#app_ids[@]}" \
                        "$(app_field "$id" NAME)" "$pick" "$note"
                else
                    printf "    ⛔ %s — %s\n" "$(app_field "$id" NAME)" "$reason"
                fi

            done

        done

        echo ""
        echo "Números para incluir/excluir (ej: 1,3-5) · Enter para continuar · 0 para cancelar"
        printf "Selección: "
        read -r selection || selection="0"

        if [[ "$selection" == "0" ]]; then
            return 1
        fi

        [[ -z "$selection" ]] && return 0

        while IFS= read -r item; do
            id="${app_ids[$((item - 1))]}"
            selection_toggle "$id" manual
        done < <(parse_selection "$selection" "${#app_ids[@]}")

    done
}

# =========================
# Quick Presets (optional) -> Application Catalog -> confirmation
# =========================

# start_deployment_flow [PRESET_ID] — PRESET_ID empty means "start empty".
# Every path (preset or empty) goes through the exact same catalog and
# confirmation screens; there is no separate preset-execution path.
start_deployment_flow() {

    local preset_id="${1:-}"

    if [[ -n "$preset_id" ]]; then
        load_preset_into_selection "$preset_id"
    else
        reset_selection
    fi

    apply_hardware_recommendations

    run_application_catalog || {
        info "ℹ️ Selección cancelada"
        return 0
    }

    if [[ "$(selection_count)" -eq 0 ]]; then
        warn "⚠️ No se seleccionó ninguna aplicación"
        return 0
    fi

    build_plan_from_selection "$preset_id"

    run_plan_confirmation
}

# =========================
# Main deployment menu — one flat screen, no category/profile nesting.
# JB Picks are not a separate screen or workflow: a JB_PICK=true application
# is annotated inline wherever it appears in the Application Catalog (see
# run_application_catalog) and in the plan's explain view — the same catalog
# flag, surfaced where selection actually happens, not a special case.
# =========================

run_deployment_menu() {

    local preset_id choice index count
    local -a preset_ids=()

    while true; do

        preset_ids=()
        while IFS= read -r preset_id; do
            [[ -n "$preset_id" ]] && preset_ids+=("$preset_id")
        done < <(list_presets_ordered)

        count="${#preset_ids[@]}"

        print_section "🚀 Deployment"
        echo "Plantillas rápidas (opcional) — podrás revisar y modificar la"
        echo "selección antes de instalar:"
        echo ""

        for ((index=0; index<count; index++)); do
            render_category "$((index + 1))" "$(render_preset "${preset_ids[$index]}")" 0
        done

        render_category "$((count + 1))" "Empezar vacío" 0
        echo "0) Volver"
        echo ""
        printf "Selecciona una opción: "
        read -r choice || choice="0"

        if [[ "$choice" == "0" ]]; then
            return 0
        elif [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le "$count" ]]; then
            start_deployment_flow "${preset_ids[$((choice - 1))]}"
            return 0
        elif [[ "$choice" == "$((count + 1))" ]]; then
            start_deployment_flow ""
            return 0
        else
            warn "⚠️ Opción inválida"
        fi

    done
}
