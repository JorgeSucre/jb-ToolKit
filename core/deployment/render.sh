#!/bin/bash

# =========================
# Deployment render layer
# =========================
# Pure presentation. Every function renders catalog, selection, or plan
# data and performs no resolution, no validation, and no mutation, so
# future interfaces can reuse the planner without touching this file.

# plan_source_label PROVENANCE — human label for a plan record's
# provenance ("preset:<id>", "hardware", or "manual" — see selection.sh)
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
        hardware) printf "recomendación para este Mac\n" ;;
        *)        printf "selección manual\n" ;;
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

# =========================
# Plan renderers
# =========================

# Explain view: the full plan with provenance and reasons
render_plan() {

    [[ "$PLAN_READY" -eq 1 ]] || return 0

    local id name provenance reason

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
# step. count / estimated installs / compatibility exclusions, then confirm.
render_confirmation() {

    [[ "$PLAN_READY" -eq 1 ]] || return 0

    print_section "🚀 Confirmación del despliegue"

    printf "Plantilla: %s\n" "$PLAN_PRESET_NAME"

    echo ""
    printf "Aplicaciones seleccionadas:  %s\n" "$((PLAN_APP_COUNT + PLAN_MANUAL_COUNT))"
    printf "Instalación automática:      %s\n" "$PLAN_APP_COUNT"
    printf "Instalación manual:          %s\n" "$PLAN_MANUAL_COUNT"
    printf "JB Picks incluidos:          %s\n" "$PLAN_PICK_COUNT"

    if [[ "$PLAN_SKIP_COUNT" -gt 0 ]]; then
        printf "No compatibles (excluidas):  %s\n" "$PLAN_SKIP_COUNT"
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
