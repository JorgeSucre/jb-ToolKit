#!/bin/bash

# =========================
# Catalog Doctor
# =========================
# Advisory diagnostics for catalog maintainability. Everything reported
# here is a SUGGESTION, never a validation failure — the catalog remains
# valid and usable. Hard rules (including the JB_PICK note requirement,
# rule V5) live in the validator in catalog.sh; the doctor runs after it
# and only adds maintainability observations on a valid catalog.

CATALOG_ADVICE_COUNT=0

catalog_advice() {
    CATALOG_ADVICE_COUNT=$((CATALOG_ADVICE_COUNT + 1))
    warn "• $1"
}

# All application IDs referenced by at least one bundle (with duplicates)
_all_bundle_references() {
    local bundle

    for bundle in $(list_bundles); do
        bundle_apps "$bundle"
    done
}

run_catalog_doctor() {

    local id count refs line

    CATALOG_ADVICE_COUNT=0

    print_section "🩺 Catalog Doctor — sugerencias de mantenimiento"

    refs="$(_all_bundle_references)"

    # A1 — applications never referenced by any bundle
    for id in $(list_applications); do
        if ! grep -qx "$id" <<< "$refs"; then
            catalog_advice "La aplicación '$id' no está referenciada por ningún bundle"
        fi
    done

    # A2 — bundles with a single application
    for id in $(list_bundles); do
        count=$(bundle_apps "$id" | sed '/^$/d' | wc -l | tr -d ' ')
        if [[ "$count" -eq 1 ]]; then
            catalog_advice "El bundle '$id' contiene una sola aplicación"
        fi
    done

    # A3 — applications appearing in multiple bundles (legitimate, but worth knowing)
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        count=$(grep -cx "$line" <<< "$refs")
        catalog_advice "La aplicación '$line' aparece en $count bundles"
    done < <(printf "%s\n" "$refs" | sed '/^$/d' | sort | uniq -d)

    # A4 — profiles composed of a single bundle
    for id in $(list_profiles); do
        count=$(profile_bundles "$id" | sed '/^$/d' | wc -l | tr -d ' ')
        if [[ "$count" -eq 1 ]]; then
            catalog_advice "El perfil '$id' referencia un solo bundle"
        fi
    done

    # A5 — categories with a single profile (render as direct entries)
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        count=$(profiles_in_category "$line" | sed '/^$/d' | wc -l | tr -d ' ')
        if [[ "$count" -eq 1 ]]; then
            catalog_advice "La categoría '$line' contiene un solo perfil (se muestra como entrada directa)"
        fi
    done < <(list_categories)

    echo ""

    if [[ "$CATALOG_ADVICE_COUNT" -eq 0 ]]; then
        success "✔ Sin sugerencias: el catálogo está en buen estado"
    else
        info "ℹ️ $CATALOG_ADVICE_COUNT sugerencias (el catálogo sigue siendo válido)"
    fi

    return 0
}
