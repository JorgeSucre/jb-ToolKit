#!/bin/bash

# =========================
# Deployment render layer
# =========================
# Pure presentation. Every function renders catalog, selection, or plan
# data and performs no resolution, no validation, and no mutation, so
# future interfaces can reuse the planner without touching this file.

# plan_source_label PROVENANCE — human label for a plan record's
# provenance ("preset:<id>" or "manual" — see selection.sh). As of v2.4.0
# there is no "hardware" provenance: recommendations are advisory-only (a
# ★ badge) and never add anything to the selection themselves, so a
# manually-added recommended app is indistinguishable from any other
# manual pick here, same as it always was for non-recommended apps.
plan_source_label() {
    local provenance="$1" preset_id

    case "$provenance" in
        preset:*)
            preset_id="${provenance#preset:}"
            if preset_exists "$preset_id"; then
                preset_field "$preset_id" NAME
            else
                printf "plantilla\n"
            fi
            ;;
        *) printf "selección manual\n" ;;
    esac
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

# render_preset ID — one-line summary for the Quick Presets screen
render_preset() {
    printf "%s — %s\n" \
        "$(preset_field "$1" NAME)" \
        "$(preset_field "$1" DESCRIPTION)"
}

# render_application ID [PROVENANCE] — checked line with provenance
render_application() {
    printf "   ✓ %s\n" "$(app_field "$1" NAME)"

    if [[ -n "${2:-}" ]]; then
        printf "       desde %s\n" "$(plan_source_label "$2")"
    fi
}

# install_method_label METHOD — friendly Spanish label for the detail view
install_method_label() {
    case "$1" in
        brew)   printf "Homebrew (formula)\n" ;;
        cask)   printf "Homebrew (cask)\n" ;;
        mas)    printf "Mac App Store\n" ;;
        pkg)    printf "Instalador .pkg\n" ;;
        dmg)    printf "Imagen .dmg\n" ;;
        manual) printf "Descarga manual\n" ;;
        *)      printf "%s\n" "$1" ;;
    esac
}

# render_application_detail ID — the Application View, optimized for fast
# installation decisions (v2.4.1): status leads, everything else is either
# collapsed into one compact metadata line or shown only when it carries
# real information. Pure presentation over app_field reads — same "no
# resolution here" contract as the rest of this file.
#
# ARCHITECTURE is deliberately not shown: it's documented as purely
# descriptive ("never gates anything," CATALOG_STANDARD.md), reads
# "universal" for nearly every catalog entry, and the one thing that DOES
# gate compatibility (ARCHS) is already reflected in Estado above. Zero
# decision value for a line of screen space.
render_application_detail() {
    local id="$1"
    local value related_id reason

    print_section "📋 $(app_field "$id" NAME)"

    # Status first — "do I even need to install this?" is the single most
    # decision-relevant fact this screen can show, so it leads rather than
    # sitting buried among static metadata (v2.4.0).
    if ! reason="$(app_incompatibility_reason "$id")"; then
        printf "Estado: ⛔ %s\n" "$reason"
    elif app_already_installed "$id"; then
        printf "Estado: ${GREEN}✔ Ya instalada${NC}\n"
    elif grep -qx "$id" <<< "$CATALOG_MENU_HW_IDS"; then
        printf "Estado: ★ Recomendada para tu equipo\n"
    else
        printf "Estado: Disponible para instalar\n"
    fi

    echo ""
    echo "$(app_field "$id" DESCRIPTION)"

    echo ""
    printf "%s · %s · %s\n" \
        "$(app_field "$id" CATEGORY)" \
        "$(app_field "$id" LICENSE)" \
        "$(install_method_label "$(app_field "$id" INSTALL_METHOD)")"
    printf "Homepage: %s\n" "$(app_field "$id" HOMEPAGE)"

    value="$(app_field "$id" REQUIREMENTS)"
    [[ -n "$value" ]] && printf "Requisitos: %s\n" "$value"

    value="$(app_field "$id" NOTES)"
    if [[ -n "$value" ]]; then
        echo ""
        printf "ℹ️ %s\n" "$value"
    fi

    if [[ "$(app_field "$id" JB_PICK)" == "true" ]]; then
        echo ""
        printf "⭐ Nota de JB: %s\n" "$(app_field "$id" JB_PICK_NOTE)"
    fi

    value="$(app_field "$id" ALTERNATIVES)"
    [[ -n "$value" ]] && { echo ""; printf "Alternativas: %s\n" "$value"; }

    value="$(app_field "$id" RELATED)"
    if [[ -n "$value" ]]; then
        echo ""
        echo "Relacionadas:"
        for related_id in $value; do
            if app_exists "$related_id"; then
                printf "   • %s\n" "$(app_field "$related_id" NAME)"
            fi
        done
    fi
}

# =========================
# Plan renderers
# =========================

# _plan_installed_count BLOCK — how many "id|..." records in BLOCK are
# already installed, checked fresh (app_already_installed) at render time.
# Used by render_confirmation so the automatic and manual tracks can each
# be counted without duplicating the check twice inline.
_plan_installed_count() {
    local block="$1" id _rest count=0

    while IFS='|' read -r id _rest; do
        [[ -z "$id" ]] && continue
        app_already_installed "$id" && count=$((count + 1))
    done <<< "$block"

    printf "%s\n" "$count"
}

# _plan_recommended_unselected — hardware-recommended app IDs for this
# machine that never made it into the current selection, one per line.
# Only meaningful now that recommendations are advisory-only (v2.4.0) — a
# technician can genuinely skip one, and the plan should say so before
# installing, not after. Freshly computed at render time from
# SELECTED_APPS (still the exact membership the plan was built from — see
# menu.sh) and apps_recommended_for_hardware, same "recompute, don't
# store" pattern render_plan_tree already uses rather than a new PLAN_*
# field.
_plan_recommended_unselected() {
    local family has_ext=0 id

    detect_machine_family
    family="$MACHINE_FAMILY"
    has_external_display && has_ext=1

    while IFS= read -r id; do
        [[ -z "$id" ]] && continue
        selection_contains "$id" || printf "%s\n" "$id"
    done < <(apps_recommended_for_hardware "$family" "$has_ext")
}

# Explain view: the full plan with provenance and reasons
render_plan() {

    [[ "$PLAN_READY" -eq 1 ]] || return 0

    local id name provenance reason recommended_unselected

    print_section "🧭 Plan de despliegue: $PLAN_PRESET_NAME"

    printf "Equipo: %s · macOS %s\n" "$PLAN_ARCH" "$PLAN_MACOS"

    echo ""
    echo "Aplicaciones ($PLAN_APP_COUNT):"

    while IFS='|' read -r id name provenance _method _pkg; do
        [[ -z "$id" ]] && continue
        render_application "$id" "$provenance"
    done <<< "$PLAN_APPS"

    if [[ "$PLAN_MANUAL_COUNT" -gt 0 ]]; then
        echo ""
        echo "Instalación manual ($PLAN_MANUAL_COUNT):"

        while IFS='|' read -r id name provenance method url; do
            [[ -z "$id" ]] && continue
            printf "   ✋ %s — %s\n" "$name" "$(manual_step_label "$method")"
            [[ -n "$url" ]] && printf "       %s\n" "$url"
            printf "       desde %s\n" "$(plan_source_label "$provenance")"
        done <<< "$PLAN_MANUAL"
    fi

    if [[ "$PLAN_SKIP_COUNT" -gt 0 ]]; then
        echo ""
        echo "No compatibles con este equipo ($PLAN_SKIP_COUNT):"

        while IFS='|' read -r id name reason; do
            [[ -z "$id" ]] && continue
            printf "   ⚠️ %s — %s\n" "$name" "$reason"
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

    recommended_unselected="$(_plan_recommended_unselected)"
    if [[ -n "$recommended_unselected" ]]; then
        echo ""
        echo "Recomendadas para este equipo, no seleccionadas:"
        while IFS= read -r id; do
            [[ -z "$id" ]] && continue
            printf "   ★ %s\n" "$(app_field "$id" NAME)"
        done <<< "$recommended_unselected"
    fi
}

# Diff view (--tree): what changed between the loaded preset and the final
# selection. Computed entirely from PLAN_APPS/PLAN_MANUAL plus a fresh
# preset_apps() lookup — no separate "what the technician changed" data is
# stored anywhere; it's a render-time comparison, same "never duplicate
# what can be derived" principle the rest of the catalog follows. A plan
# with no source preset (PLAN_PRESET_ID=custom) has nothing to diff against.
render_plan_tree() {

    [[ "$PLAN_READY" -eq 1 ]] || return 0

    local app final_ids original_ids
    local kept_count=0 added_count=0 removed_count=0

    print_section "🌳 Comparación con la plantilla: $PLAN_PRESET_NAME"

    if [[ "$PLAN_PRESET_ID" == "custom" ]] || ! preset_exists "$PLAN_PRESET_ID"; then
        info "ℹ️ Selección personalizada, sin plantilla de referencia"
        return 0
    fi

    final_ids="$(awk -F'|' '{print $1}' <<< "$PLAN_APPS"$'\n'"$PLAN_MANUAL" | sed '/^$/d')"
    original_ids="$(preset_apps "$PLAN_PRESET_ID")"

    echo "Desde la plantilla «${PLAN_PRESET_NAME}»:"
    echo ""

    while IFS= read -r app; do
        [[ -z "$app" ]] && continue
        if grep -qx "$app" <<< "$final_ids"; then
            printf "   = %s\n" "$(app_field "$app" NAME)"
            kept_count=$((kept_count + 1))
        else
            printf "   - %s (quitada)\n" "$(app_field "$app" NAME)"
            removed_count=$((removed_count + 1))
        fi
    done <<< "$original_ids"

    while IFS= read -r app; do
        [[ -z "$app" ]] && continue
        if ! grep -qx "$app" <<< "$original_ids"; then
            printf "   + %s (añadida)\n" "$(app_field "$app" NAME)"
            added_count=$((added_count + 1))
        fi
    done <<< "$final_ids"

    echo ""
    printf "Sin cambios: %s · Añadidas: %s · Quitadas: %s\n" \
        "$kept_count" "$added_count" "$removed_count"
}

# Concise resolution summary (--resolve): what would happen, no provenance
render_plan_summary() {

    [[ "$PLAN_READY" -eq 1 ]] || return 0

    local id name provenance reason method url _pkg

    print_section "📦 Resolución: $PLAN_PRESET_NAME"

    printf "Equipo: %s · macOS %s\n" "$PLAN_ARCH" "$PLAN_MACOS"

    echo ""
    echo "Instalaría ($PLAN_APP_COUNT):"

    while IFS='|' read -r id name provenance method _pkg; do
        [[ -z "$id" ]] && continue
        printf "   • %s\n" "$name"
    done <<< "$PLAN_APPS"

    if [[ "$PLAN_MANUAL_COUNT" -gt 0 ]]; then
        echo ""
        echo "Requeriría acción manual ($PLAN_MANUAL_COUNT):"

        while IFS='|' read -r id name provenance method url; do
            [[ -z "$id" ]] && continue
            printf "   • %s — %s\n" "$name" "$(manual_step_label "$method")"
        done <<< "$PLAN_MANUAL"
    fi

    if [[ "$PLAN_SKIP_COUNT" -gt 0 ]]; then
        echo ""
        echo "No compatible con este equipo ($PLAN_SKIP_COUNT):"

        while IFS='|' read -r id name reason; do
            [[ -z "$id" ]] && continue
            printf "   • %s — %s\n" "$name" "$reason"
        done <<< "$PLAN_SKIPPED"
    fi
}

# Confirmation summary: the final planning screen — the "Review Selection"
# step. As of v2.4.1 this is glyph-led, reusing the exact vocabulary the
# Application Catalog and the result screen already taught the technician
# (✔ installed, ⭐ picks, ★ recommended, ✋ manual) instead of six lines that
# all have to be read to be told apart — scannable by symbol, not by
# reading every label. Counts are unchanged from v2.4.0 (still computed
# fresh at render time, no new PLAN_* field): what will actually change on
# this machine (will install / already installed) vs. what won't be
# touched either way (manual steps, recommended-but-skipped, unavailable).
render_confirmation() {

    [[ "$PLAN_READY" -eq 1 ]] || return 0

    local auto_installed total_installed recommended_skipped

    auto_installed="$(_plan_installed_count "$PLAN_APPS")"
    total_installed=$((auto_installed + $(_plan_installed_count "$PLAN_MANUAL")))
    recommended_skipped="$(_plan_recommended_unselected | grep -c . || true)"

    print_section "🚀 Confirmación del despliegue"

    printf "Plantilla: %s\n" "$PLAN_PRESET_NAME"

    echo ""
    printf "   %2d  aplicaciones seleccionadas\n" "$((PLAN_APP_COUNT + PLAN_MANUAL_COUNT))"
    echo ""
    printf " → %2d  se instalarán\n" "$((PLAN_APP_COUNT - auto_installed))"
    printf " ${GREEN}✔${NC} %2d  ya instaladas\n" "$total_installed"
    printf " ✋ %2d  instalación manual\n" "$PLAN_MANUAL_COUNT"
    printf " ⭐ %2d  JB Picks incluidos\n" "$PLAN_PICK_COUNT"

    if [[ "$recommended_skipped" -gt 0 ]]; then
        printf " ★ %2d  recomendadas sin seleccionar\n" "$recommended_skipped"
    fi

    if [[ "$PLAN_SKIP_COUNT" -gt 0 ]]; then
        printf " ⚠️ %2d  no compatibles (excluidas)\n" "$PLAN_SKIP_COUNT"
    fi

    echo ""
    success "✔ Planificación completa"
}

# Result screen: consumes the Installation Transaction (verified outcomes
# only — the plan said what would happen; this shows what actually did).
# Every application has a named outcome: installed, already installed,
# skipped, manual, or failed (with its reason). Nothing is silent.
render_transaction() {

    local id name reason

    print_section "📦 Resultado del despliegue"

    printf "Plantilla: %s\n" "$PLAN_PRESET_NAME"

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
        echo "No compatibles con este equipo:"
        while IFS='|' read -r id name reason; do
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
