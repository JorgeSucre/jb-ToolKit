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

# render_application ID [SOURCE_BUNDLE_ID] — checked line with provenance
render_application() {
    printf "   ✓ %s\n" "$(app_field "$1" NAME)"

    if [[ -n "${2:-}" ]]; then
        printf "       desde %s\n" "$(bundle_display_name "$2")"
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

    while IFS='|' read -r id name bundle; do
        [[ -z "$id" ]] && continue
        printf "   ✓ %s\n" "$name"
        printf "       desde %s\n" "$(bundle_display_name "$bundle")"
    done <<< "$PLAN_APPS"

    if [[ "$PLAN_SKIP_COUNT" -gt 0 ]]; then
        echo ""
        echo "Omitidas ($PLAN_SKIP_COUNT):"

        while IFS='|' read -r id name bundle reason; do
            [[ -z "$id" ]] && continue
            printf "   ⚠️ %s\n" "$name"
            printf "       %s (desde %s)\n" "$reason" "$(bundle_display_name "$bundle")"
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
            if grep -q "^$app|.*|$bundle\$" <<< "$PLAN_APPS"; then
                :   # provided by this bundle — no annotation
            elif grep -q "^$app|" <<< "$PLAN_APPS"; then
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

# Confirmation summary: the final Phase 4 screen
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
    printf "Aplicaciones a instalar:  %s\n" "$PLAN_APP_COUNT"
    printf "JB Picks incluidos:       %s\n" "$PLAN_PICK_COUNT"
    printf "Omitidas:                 %s\n" "$PLAN_SKIP_COUNT"
    printf "Descarga estimada:        disponible en la próxima fase\n"

    echo ""
    success "✔ Planificación completa"
    info "ℹ️ La instalación se habilitará en la próxima fase"
}
