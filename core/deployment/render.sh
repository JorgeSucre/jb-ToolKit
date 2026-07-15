#!/bin/bash

# =========================
# Deployment render layer
# =========================
# Pure presentation. Every function renders catalog or plan data and
# performs no resolution, no validation, and no mutation, so future
# interfaces can reuse the planner without touching this file.

# Non-empty line count of a variable (command substitution strips the
# trailing newline, so wc -l on printf "%s" undercounts by one)
_count_lines() {
    printf "%s\n" "$1" | sed '/^$/d' | wc -l | tr -d ' '
}

# plan_source_label SOURCE — human label for a plan record's provenance
# (a bundle ID, or the literal "hardware" for hardware recommendations)
plan_source_label() {
    if bundle_exists "$1"; then
        bundle_display_name "$1"
    else
        printf "recomendación para este Mac\n"
    fi
}

# manual_step_label METHOD — what the technician must do for a
# non-automated INSTALL_METHOD
manual_step_label() {
    case "$1" in
        mas) printf "instalar desde App Store\n" ;;
        *)   printf "instalación manual requerida\n" ;;
    esac
}

# =========================
# Element renderers
# =========================

# render_category INDEX LABEL HAS_SUBMENU(0|1)
render_category() {
    if [[ "${3:-0}" -eq 1 ]]; then
        printf "%s) %s …\n" "$1" "$2"
    else
        printf "%s) %s\n" "$1" "$2"
    fi
}

# render_profile ID — one-line summary
render_profile() {
    printf "%s — %s\n" \
        "$(profile_field "$1" NAME)" \
        "$(profile_field "$1" DESCRIPTION)"
}

# render_bundle ID — display name with content count
render_bundle() {
    local count
    count=$(bundle_apps "$1" | sed '/^$/d' | wc -l | tr -d ' ')

    printf "%s (%s aplicaciones)\n" "$(bundle_display_name "$1")" "$count"
}

# render_application ID [SOURCE] — checked line with provenance
render_application() {
    printf "   ✓ %s\n" "$(app_field "$1" NAME)"

    if [[ -n "${2:-}" ]]; then
        printf "       desde %s\n" "$(plan_source_label "$2")"
    fi
}

# render_jb_pick ID — starred recommendation with its mandatory reasoning
render_jb_pick() {
    printf "★★★★★ %s\n" "$(app_field "$1" NAME)"
    printf "   %s\n" "$(app_field "$1" DESCRIPTION)"
    printf "   %s\n" "$(app_field "$1" JB_PICK_NOTE)"
}

# =========================
# Plan renderers
# =========================

# Explain view: the full plan with provenance and reasons
render_plan() {

    [[ "$PLAN_READY" -eq 1 ]] || return 0

    local bundle id name reason

    print_section "🧭 Plan de despliegue: $PLAN_PROFILE_NAME"

    printf "%s\n" "$PLAN_PROFILE_DESC"
    printf "Equipo: %s · macOS %s\n" "$PLAN_ARCH" "$PLAN_MACOS"

    echo ""
    echo "Bundles:"

    while IFS= read -r bundle; do
        [[ -z "$bundle" ]] && continue
        printf "   ✓ %s\n" "$(render_bundle "$bundle")"
    done <<< "$PLAN_BUNDLES"

    echo ""
    echo "Aplicaciones ($PLAN_APP_COUNT):"

    while IFS='|' read -r id name bundle _method _pkg; do
        [[ -z "$id" ]] && continue
        render_application "$id" "$bundle"
    done <<< "$PLAN_APPS"

    if [[ "$PLAN_MANUAL_COUNT" -gt 0 ]]; then
        echo ""
        echo "Instalación manual ($PLAN_MANUAL_COUNT):"

        while IFS='|' read -r id name bundle method url; do
            [[ -z "$id" ]] && continue
            printf "   ✋ %s — %s\n" "$name" "$(manual_step_label "$method")"
            [[ -n "$url" ]] && printf "       %s\n" "$url"
            printf "       desde %s\n" "$(plan_source_label "$bundle")"
        done <<< "$PLAN_MANUAL"
    fi

    if [[ "$PLAN_SKIP_COUNT" -gt 0 ]]; then
        echo ""
        echo "Omitidas ($PLAN_SKIP_COUNT):"

        while IFS='|' read -r id name bundle reason; do
            [[ -z "$id" ]] && continue
            printf "   ⚠️ %s\n" "$name"
            printf "       %s (desde %s)\n" "$reason" "$(plan_source_label "$bundle")"
        done <<< "$PLAN_SKIPPED"
    fi

    if [[ "$PLAN_PICK_COUNT" -gt 0 ]]; then
        echo ""
        echo "JB Picks incluidos ($PLAN_PICK_COUNT):"

        while IFS= read -r id; do
            [[ -z "$id" ]] && continue
            printf "   ★ %s\n" "$(app_field "$id" NAME)"
            printf "       %s\n" "$(app_field "$id" JB_PICK_NOTE)"
        done <<< "$PLAN_PICKS"
    fi
}

# Developer tree view: bundles as defined in the catalog, annotated with
# what the plan actually does (dedup and skips are visible, never silent)
render_plan_tree() {

    [[ "$PLAN_READY" -eq 1 ]] || return 0

    local bundle bundles_total bundle_index
    local app apps apps_total app_index
    local branch child_indent annotation line

    print_section "🌳 Árbol del plan: $PLAN_PROFILE_NAME"

    printf "%s\n" "$PLAN_PROFILE_NAME"

    bundles_total=$(_count_lines "$PLAN_BUNDLES")
    bundle_index=0

    while IFS= read -r bundle; do
        [[ -z "$bundle" ]] && continue

        bundle_index=$((bundle_index + 1))

        if [[ "$bundle_index" -eq "$bundles_total" ]]; then
            branch="└──"
            child_indent="    "
        else
            branch="├──"
            child_indent="│   "
        fi

        printf "%s %s\n" "$branch" "$(bundle_display_name "$bundle")"

        apps="$(bundle_apps "$bundle")"
        apps_total=$(_count_lines "$apps")
        app_index=0

        while IFS= read -r app; do
            [[ -z "$app" ]] && continue

            app_index=$((app_index + 1))

            annotation=""
            if grep -q "^$app|[^|]*|$bundle|" <<< "$PLAN_APPS"; then
                :   # provided by this bundle — no annotation
            elif grep -q "^$app|[^|]*|$bundle|" <<< "$PLAN_MANUAL"; then
                annotation=" (instalación manual)"
            elif grep -q "^$app|" <<< "$PLAN_APPS$PLAN_MANUAL"; then
                annotation=" (ya incluido por otro bundle)"
            else
                line="$(grep -m1 "^$app|" <<< "$PLAN_SKIPPED" || true)"
                annotation=" (omitida: ${line##*|})"
            fi

            if [[ "$app_index" -eq "$apps_total" ]]; then
                printf "%s└── %s%s\n" "$child_indent" "$(app_field "$app" NAME)" "$annotation"
            else
                printf "%s├── %s%s\n" "$child_indent" "$(app_field "$app" NAME)" "$annotation"
            fi

        done <<< "$apps"

    done <<< "$PLAN_BUNDLES"
}

# Concise resolution summary (--resolve): what would happen, no provenance
render_plan_summary() {

    [[ "$PLAN_READY" -eq 1 ]] || return 0

    local id name bundle reason method url _pkg

    print_section "📦 Resolución: $PLAN_PROFILE_NAME"

    printf "%s\n" "$PLAN_PROFILE_DESC"
    printf "Equipo: %s · macOS %s\n" "$PLAN_ARCH" "$PLAN_MACOS"

    echo ""
    echo "Instalaría ($PLAN_APP_COUNT):"

    while IFS='|' read -r id name bundle method _pkg; do
        [[ -z "$id" ]] && continue
        printf "   • %s\n" "$name"
    done <<< "$PLAN_APPS"

    if [[ "$PLAN_MANUAL_COUNT" -gt 0 ]]; then
        echo ""
        echo "Requeriría acción manual ($PLAN_MANUAL_COUNT):"

        while IFS='|' read -r id name bundle method url; do
            [[ -z "$id" ]] && continue
            printf "   • %s — %s\n" "$name" "$(manual_step_label "$method")"
        done <<< "$PLAN_MANUAL"
    fi

    if [[ "$PLAN_SKIP_COUNT" -gt 0 ]]; then
        echo ""
        echo "Omitiría ($PLAN_SKIP_COUNT):"

        while IFS='|' read -r id name bundle reason; do
            [[ -z "$id" ]] && continue
            printf "   • %s — %s\n" "$name" "$reason"
        done <<< "$PLAN_SKIPPED"
    fi
}

# Confirmation summary: the final planning screen
render_confirmation() {

    [[ "$PLAN_READY" -eq 1 ]] || return 0

    local bundle

    print_section "🚀 Confirmación del despliegue"

    printf "Perfil: %s\n" "$PLAN_PROFILE_NAME"
    printf "%s\n" "$PLAN_PROFILE_DESC"

    echo ""
    echo "Bundles:"

    while IFS= read -r bundle; do
        [[ -z "$bundle" ]] && continue
        printf "   ✓ %s\n" "$(render_bundle "$bundle")"
    done <<< "$PLAN_BUNDLES"

    echo ""
    printf "Instalación automática:   %s\n" "$PLAN_APP_COUNT"
    printf "Instalación manual:       %s\n" "$PLAN_MANUAL_COUNT"
    printf "JB Picks incluidos:       %s\n" "$PLAN_PICK_COUNT"
    printf "Omitidas:                 %s\n" "$PLAN_SKIP_COUNT"

    echo ""
    success "✔ Planificación completa"
}

# Result screen: consumes the Installation Transaction (verified outcomes
# only — the plan said what would happen; this shows what actually did).
# Every application has a named outcome: installed, already installed,
# skipped, manual, or failed (with its reason). Nothing is silent.
render_transaction() {

    local id name bundle reason

    print_section "📦 Resultado del despliegue"

    printf "Perfil: %s\n" "$PLAN_PROFILE_NAME"

    echo ""

    if [[ "$TXN_ATTEMPTED" -eq 0 && "$TXN_ALREADY" -gt 0 && "$TXN_MANUAL" -eq 0 ]]; then
        success "✔ Todas las aplicaciones del plan ya estaban instaladas"
    elif [[ "$TXN_ATTEMPTED" -gt 0 ]]; then
        printf "Instaladas: %s de %s\n" "$TXN_INSTALLED" "$TXN_ATTEMPTED"
    fi

    if [[ "$TXN_INSTALLED" -gt 0 ]]; then
        echo ""
        echo "Instaladas:"
        while IFS='|' read -r id name; do
            [[ -z "$id" ]] && continue
            printf "   ✓ %s\n" "$name"
        done <<< "$TXN_INSTALLED_APPS"
    fi

    if [[ "$TXN_ALREADY" -gt 0 ]]; then
        echo ""
        echo "Ya estaban instaladas:"
        while IFS='|' read -r id name; do
            [[ -z "$id" ]] && continue
            printf "   ✓ %s\n" "$name"
        done <<< "$TXN_ALREADY_APPS"
    fi

    if [[ "$TXN_MANUAL" -gt 0 ]]; then
        echo ""
        echo "Requieren instalación manual (no es un fallo del despliegue):"
        while IFS='|' read -r id name; do
            [[ -z "$id" ]] && continue
            printf "   ✋ %s\n" "$name"
        done <<< "$TXN_MANUAL_APPS"
    fi

    if [[ "$PLAN_SKIP_COUNT" -gt 0 ]]; then
        echo ""
        echo "Omitidas:"
        while IFS='|' read -r id name bundle reason; do
            [[ -z "$id" ]] && continue
            printf "   • %s — %s\n" "$name" "$reason"
        done <<< "$PLAN_SKIPPED"
    fi

    if [[ "$TXN_FAILED" -gt 0 ]]; then
        echo ""
        echo "Fallidas:"
        while IFS='|' read -r id name reason; do
            [[ -z "$id" ]] && continue
            printf "   ❌ %s — %s\n" "$name" "${reason:-no quedó instalada}"
        done <<< "$TXN_FAILED_APPS"
    fi

    echo ""
    print_elapsed_time "$TXN_DURATION"

    echo ""
    case "$TXN_RESULT" in
        success)
            if [[ "$TXN_MANUAL" -gt 0 ]]; then
                success "✔ Despliegue automático completado; quedan pasos manuales listados arriba"
            else
                success "✔ Despliegue completado correctamente"
            fi
            ;;
        partial) warn "⚠️ Despliegue completado con fallos; revisa las aplicaciones fallidas" ;;
        failed)  error_msg "❌ El despliegue no pudo instalar aplicaciones" ;;
    esac

    info "ℹ️ Registro: logs/deployment_${TXN_ID}.env"
}
