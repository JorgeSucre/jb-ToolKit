#!/bin/bash

# =========================
# Deployment menus
# =========================
# Navigation is generated entirely from catalog data via the hierarchy
# queries in catalog.sh — no profile, bundle, or category name is
# hardcoded here. Every screen answers one question and stays at ~7
# visible entries; growth is absorbed by the catalog, not by menu code.

# =========================
# Bundle review — every bundle offers three choices before planning:
# install everything, customize (per-app toggle), or skip the bundle.
# The review only COLLECTS decisions; the planner applies them, so
# nothing is ever filtered at installation time.
# =========================

REVIEW_BUNDLES=""    # bundle IDs kept by the technician
REVIEW_EXCLUDED=""   # app IDs deselected during customization

# _customize_bundle BUNDLE — per-app toggle loop; deselected apps are
# appended to REVIEW_EXCLUDED (the planner records them as named skips)
_customize_bundle() {

    local bundle="$1"
    local app index count selection item mark
    local -a apps=()
    local -a states=()

    while IFS= read -r app; do
        [[ -z "$app" ]] && continue
        apps+=("$app")
        states+=(1)
    done < <(bundle_apps "$bundle")

    count="${#apps[@]}"

    while true; do

        print_section "🧩 Personalizar: $(bundle_display_name "$bundle")"
        echo "Aplicaciones incluidas en este bundle:"
        echo ""

        for ((index=0; index<count; index++)); do
            if [[ "${states[$index]}" -eq 1 ]]; then
                mark="✓"
            else
                mark=" "
            fi
            printf "[%s] %s) %s\n" "$mark" "$((index + 1))" \
                "$(app_field "${apps[$index]}" NAME)"
        done

        echo ""
        printf "Números para activar/desactivar (ej: 1,3) · Enter para confirmar: "
        read -r selection || break

        [[ -z "$selection" ]] && break

        while IFS= read -r item; do
            index=$((item - 1))
            states[$index]=$((1 - states[$index]))
        done < <(parse_selection "$selection" "$count")

    done

    for ((index=0; index<count; index++)); do
        if [[ "${states[$index]}" -eq 0 ]]; then
            REVIEW_EXCLUDED+="${apps[$index]}"$'\n'
        fi
    done
}

# run_bundle_review BUNDLES(newline-separated IDs)
# Populates REVIEW_BUNDLES / REVIEW_EXCLUDED. Returns 1 when the
# technician skipped every bundle (nothing left to plan).
run_bundle_review() {

    local bundle app choice index
    local -a review_queue=()

    REVIEW_BUNDLES=""
    REVIEW_EXCLUDED=""

    # Collected first so the interactive reads below keep stdin
    while IFS= read -r bundle; do
        [[ -n "$bundle" ]] && review_queue+=("$bundle")
    done <<< "$1"

    for ((index=0; index<${#review_queue[@]}; index++)); do
        bundle="${review_queue[$index]}"

        while true; do

            print_section "📦 $(render_bundle "$bundle")"

            while IFS= read -r app; do
                [[ -z "$app" ]] && continue
                printf "   • %s\n" "$(app_field "$app" NAME)"
            done < <(bundle_apps "$bundle")

            echo ""
            echo "1) Instalar todo"
            echo "2) Personalizar"
            echo "3) Omitir bundle"
            printf "Selecciona una opción: "
            read -r choice || choice="3"

            case "$choice" in
                1)
                    REVIEW_BUNDLES+="$bundle"$'\n'
                    break
                    ;;
                2)
                    REVIEW_BUNDLES+="$bundle"$'\n'
                    _customize_bundle "$bundle"
                    break
                    ;;
                3)
                    info "ℹ️ Bundle omitido: $(bundle_display_name "$bundle")"
                    break
                    ;;
                *)
                    warn "⚠️ Opción inválida"
                    ;;
            esac

        done

    done

    [[ -n "$REVIEW_BUNDLES" ]]
}

# =========================
# Hardware recommendations — catalog applications whose HW_RECOMMEND
# matches this machine, offered as plan extras (provenance "hardware")
# =========================

HW_EXTRAS=""    # app IDs the technician accepted

offer_hardware_extras() {

    local family has_ext=0
    local id selection item index
    local -a ids=()

    HW_EXTRAS=""

    detect_machine_family
    family="$MACHINE_FAMILY"
    has_external_display && has_ext=1

    while IFS= read -r id; do
        [[ -z "$id" ]] && continue

        # Verified as installed → nothing to recommend
        case "$(app_field "$id" INSTALL_METHOD)" in
            brew) brew_formula_installed "$(app_field "$id" PACKAGE)" && continue ;;
            cask) brew_cask_installed "$(app_field "$id" PACKAGE)" && continue ;;
        esac

        ids+=("$id")
    done < <(apps_recommended_for_hardware "$family" "$has_ext")

    [[ "${#ids[@]}" -eq 0 ]] && return 0

    print_section "🧠 Recomendaciones para este Mac"

    for ((index=0; index<${#ids[@]}; index++)); do
        printf "%s) %s — %s\n" "$((index + 1))" \
            "$(app_field "${ids[$index]}" NAME)" \
            "$(app_field "${ids[$index]}" DESCRIPTION)"
    done

    echo ""
    echo "[a] Añadir todas   [0] Omitir"
    printf "Selecciona recomendaciones (ej: 1,2): "
    read -r selection || selection="0"

    selection="${selection// /}"

    if [[ "$selection" == "a" || "$selection" == "all" ]]; then
        for id in "${ids[@]}"; do
            HW_EXTRAS+="$id"$'\n'
        done
    elif [[ -n "$selection" && "$selection" != "0" ]]; then
        while IFS= read -r item; do
            HW_EXTRAS+="${ids[$((item - 1))]}"$'\n'
        done < <(parse_selection "$selection" "${#ids[@]}")
    fi

    return 0
}

# =========================
# Profile selection
# =========================

select_profile() {

    run_bundle_review "$(profile_bundles "$1")" || {
        warn "⚠️ Todos los bundles fueron omitidos; no hay nada que desplegar"
        return 0
    }

    offer_hardware_extras

    build_deployment_plan "$1" "$REVIEW_EXCLUDED" "$HW_EXTRAS" "$REVIEW_BUNDLES" \
        || return 0

    run_plan_confirmation
}

# Category submenu (multi-profile categories); collapse handled by caller
open_category() {

    local category="$1"
    local direct choice index count label
    local profiles=()

    direct="$(category_direct_profile "$category")"

    if [[ -n "$direct" ]]; then
        select_profile "$direct"
        return 0
    fi

    while true; do

        profiles=()
        while IFS= read -r index; do
            [[ -n "$index" ]] && profiles+=("$index")
        done < <(profiles_in_category "$category")

        count="${#profiles[@]}"

        print_section "🧭 $category"
        echo "Selecciona un perfil:"
        echo ""

        for ((index=0; index<count; index++)); do
            label="$(profile_field "${profiles[$index]}" SUBCATEGORY)"
            [[ -z "$label" ]] && label="$(profile_field "${profiles[$index]}" NAME)"
            render_category "$((index + 1))" "$label" 0
        done

        echo "0) Volver"
        echo ""
        printf "Selecciona una opción: "
        read -r choice || choice="0"

        if [[ "$choice" == "0" ]]; then
            return 0
        elif [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le "$count" ]]; then
            select_profile "${profiles[$((choice - 1))]}"
        else
            warn "⚠️ Opción inválida"
        fi

    done
}

# =========================
# Custom flow — compose bundles
# =========================

run_custom_flow() {

    local bundle choice index count item selected=""
    local bundles=()

    bundles=()
    while IFS= read -r bundle; do
        [[ -n "$bundle" ]] && bundles+=("$bundle")
    done < <(list_bundles)

    count="${#bundles[@]}"

    print_section "🧩 Perfil personalizado"
    echo "Selecciona los bundles a combinar:"
    echo ""

    for ((index=0; index<count; index++)); do
        render_category "$((index + 1))" "$(render_bundle "${bundles[$index]}")" 0
    done

    echo "0) Volver"
    echo ""
    printf "Selecciona bundles (ej: 1,3): "
    read -r choice || choice="0"

    [[ -z "$choice" || "$choice" == "0" ]] && return 0

    while IFS= read -r item; do
        bundle="${bundles[$((item - 1))]}"
        if ! grep -qx "$bundle" <<< "$selected"; then
            selected+="$bundle"$'\n'
        fi
    done < <(parse_selection "$choice" "$count")

    if [[ -z "$selected" ]]; then
        warn "⚠️ No se seleccionó ningún bundle"
        return 0
    fi

    run_bundle_review "$selected" || {
        warn "⚠️ Todos los bundles fueron omitidos; no hay nada que desplegar"
        return 0
    }

    offer_hardware_extras

    build_custom_plan "$REVIEW_BUNDLES" "$REVIEW_EXCLUDED" "$HW_EXTRAS"

    run_plan_confirmation
}

# =========================
# JB Picks browser (read-only, educational)
# =========================

show_jb_picks() {

    local id

    print_section "⭐ JB Picks — Recomendados por JB Repair"
    info "ℹ️ Aplicaciones respaldadas por años de soporte a clientes"
    echo ""

    for id in $(list_jb_picks); do
        render_jb_pick "$id"
        echo ""
    done

    printf "Presiona Enter para volver... "
    read -r _ || true
}

# =========================
# Main deployment menu
# =========================

run_deployment_menu() {

    local category choice index count
    local categories=()

    while true; do

        categories=()
        while IFS= read -r category; do
            [[ -n "$category" ]] && categories+=("$category")
        done < <(list_categories)

        count="${#categories[@]}"

        print_section "🚀 Deployment"
        echo "¿Qué tipo de equipo preparamos?"
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
        render_category "$((count + 2))" "JB Picks ⭐" 0
        echo "0) Volver"
        echo ""
        printf "Selecciona una opción: "
        read -r choice || choice="0"

        if [[ "$choice" == "0" ]]; then
            return 0
        elif [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le "$count" ]]; then
            open_category "${categories[$((choice - 1))]}"
        elif [[ "$choice" == "$((count + 1))" ]]; then
            run_custom_flow
        elif [[ "$choice" == "$((count + 2))" ]]; then
            show_jb_picks
        else
            warn "⚠️ Opción inválida"
        fi

    done
}
