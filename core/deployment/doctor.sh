#!/bin/bash

# =========================
# Catalog Doctor
# =========================
# Advisory diagnostics for catalog maintainability. Everything reported
# here is a SUGGESTION, never a validation failure — the catalog remains
# valid and usable. Hard rules (including the JB_PICK note requirement,
# rule V5) live in the validator in catalog.sh; the doctor runs after it
# and only adds maintainability observations on a valid catalog.
#
# Two layers only (applications, presets) means most of the old bundle/
# profile-shaped advisories (single-app bundle, single-bundle profile,
# single-profile category) no longer apply — there is no indirection layer
# left to advise about. What replaces them: flat presets accept real
# duplication for reuse (see docs/architecture/0006-deployment-flattening.md),
# so D2 exists specifically to keep that trade-off visible.

CATALOG_ADVICE_COUNT=0
DOCTOR_SHARED_APP_THRESHOLD=4

catalog_advice() {
    CATALOG_ADVICE_COUNT=$((CATALOG_ADVICE_COUNT + 1))
    warn "• $1"
}

# All application IDs referenced by at least one preset (with duplicates)
_all_preset_references() {
    local preset

    for preset in $(list_presets); do
        preset_apps "$preset"
    done
}

run_catalog_doctor() {

    local id count refs

    CATALOG_ADVICE_COUNT=0

    print_section "🩺 Catalog Doctor — sugerencias de mantenimiento"

    refs="$(_all_preset_references)"

    # D1 — applications never referenced by any preset (hardware
    # recommendations are reachable through the Application Catalog's
    # hardware surfacing instead)
    for id in $(list_applications); do
        [[ -n "$(app_field "$id" HW_RECOMMEND)" ]] && continue
        if ! grep -qx "$id" <<< "$refs"; then
            catalog_advice "La aplicación '$id' no está referenciada por ningún preset"
        fi
    done

    # D2 — applications referenced by many presets: flat presets mean
    # editing one of these means touching every preset that lists it.
    # Informational, not a problem — just keeps that fact visible.
    while IFS= read -r id; do
        [[ -z "$id" ]] && continue
        count=$(grep -cx "$id" <<< "$refs")
        if [[ "$count" -ge "$DOCTOR_SHARED_APP_THRESHOLD" ]]; then
            catalog_advice "La aplicación '$id' está en $count presets — edítala con cuidado, el cambio no se propaga solo"
        fi
    done < <(printf "%s\n" "$refs" | sed '/^$/d' | sort -u)

    echo ""

    if [[ "$CATALOG_ADVICE_COUNT" -eq 0 ]]; then
        success "✔ Sin sugerencias: el catálogo está en buen estado"
    else
        info "ℹ️ $CATALOG_ADVICE_COUNT sugerencias (el catálogo sigue siendo válido)"
    fi

    return 0
}
