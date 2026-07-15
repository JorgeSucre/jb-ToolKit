#!/bin/bash

# =========================
# Deployment menus
# =========================
# Navigation is generated entirely from catalog data via the hierarchy
# queries in catalog.sh — no profile, bundle, or category name is
# hardcoded here. Every screen answers one question and stays at ~7
# visible entries; growth is absorbed by the catalog, not by menu code.

# =========================
# Profile selection
# =========================

select_profile() {

    build_deployment_plan "$1" || return 0

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
        read -r choice

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
    read -r choice

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

    build_custom_plan "$selected"

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
    read -r _
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
        read -r choice

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
