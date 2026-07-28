#!/bin/bash

# =========================
# Selected Applications
# =========================
# The ONE selection model. Whether an application enters the selection via a
# preset, a hardware recommendation, or a manual toggle in the Application
# Catalog, it ends up as exactly the same kind of record here — there is no
# separate code path for "preset apps" vs "manually chosen apps" past this
# point. Presets are shortcuts that populate this set; they are not a
# parallel execution model.
#
# SELECTED_APPS: "id|provenance" one per line, first-occurrence-wins on
# duplicates. provenance is display-only (never branched on downstream):
#   preset:<id>   added by loading a preset
#   hardware      added because HW_RECOMMEND matched this machine
#   manual        added directly in the Application Catalog
#
# SELECTION_LOAD_SKIPPED: "id|reason" — applications a preset wanted to
# include but that are incompatible with this machine (ARCHS/MIN_MACOS).
# Recorded, never silent, same principle as before this simplification.

SELECTED_APPS=""
SELECTION_LOAD_SKIPPED=""

reset_selection() {
    SELECTED_APPS=""
    SELECTION_LOAD_SKIPPED=""
}

selection_contains() {
    local app="$1"
    grep -q "^$app|" <<< "$SELECTED_APPS"
}

selection_provenance() {
    local app="$1"
    awk -F'|' -v id="$app" '$1 == id {print $2; exit}' <<< "$SELECTED_APPS"
}

# selection_add APP PROVENANCE — no-op if already selected (first
# provenance wins, so a hardware/manual add never overwrites a preset's claim)
selection_add() {
    local app="$1" provenance="$2"

    selection_contains "$app" && return 0

    SELECTED_APPS+="$app|$provenance"$'\n'
}

selection_remove() {
    local app="$1"
    SELECTED_APPS="$(grep -v "^$app|" <<< "$SELECTED_APPS")"$'\n'
}

# selection_toggle APP PROVENANCE_IF_ADDING — the only entry point the
# Application Catalog's toggle screen needs
selection_toggle() {
    local app="$1" provenance="${2:-manual}"

    if selection_contains "$app"; then
        selection_remove "$app"
    else
        selection_add "$app" "$provenance"
    fi
}

# Application IDs currently selected, one per line
selection_list() {
    awk -F'|' '{print $1}' <<< "$SELECTED_APPS" | sed '/^$/d'
}

selection_count() {
    selection_list | grep -c . || true
}

# =========================
# Compatibility (moved here from the former resolve.sh — this is exactly
# "can this application be added to the selection," which belongs where the
# selection itself is owned)
# =========================

macos_major_version() {
    sw_vers -productVersion 2>/dev/null | cut -d. -f1
}

# Prints the Spanish skip reason and returns 1 when incompatible;
# prints nothing and returns 0 when the app can be installed here.
app_incompatibility_reason() {
    local id="$1"
    local archs min arch major

    archs="$(app_field "$id" ARCHS)"
    if [[ -n "$archs" ]]; then
        arch="$(uname -m)"
        if [[ " $archs " != *" $arch "* ]]; then
            printf "no compatible con %s\n" "$arch"
            return 1
        fi
    fi

    min="$(app_field "$id" MIN_MACOS)"
    if [[ -n "$min" ]]; then
        major="$(macos_major_version)"
        if [[ -n "$major" && "$major" -lt "$min" ]]; then
            printf "requiere macOS %s+\n" "$min"
            return 1
        fi
    fi

    return 0
}

# =========================
# Preset loading
# =========================

# load_preset_into_selection PRESET_ID — replaces the current selection
# with the preset's APPS list, filtering out anything incompatible with
# this machine (recorded in SELECTION_LOAD_SKIPPED, never silently dropped).
load_preset_into_selection() {
    local preset_id="$1"
    local app reason

    reset_selection

    while IFS= read -r app; do
        [[ -z "$app" ]] && continue

        if reason="$(app_incompatibility_reason "$app")"; then
            selection_add "$app" "preset:$preset_id"
        else
            SELECTION_LOAD_SKIPPED+="$app|$reason"$'\n'
        fi

    done < <(preset_apps "$preset_id")
}

# =========================
# Hardware recommendations
# =========================
# Folded into the same selection the technician reviews — not a separate
# offer screen. Only apps not already installed are added (mirrors the
# previous offer_hardware_extras filter); already-installed apps are
# neither offered nor need to be, since install.sh's partition step is
# idempotent regardless.

apply_hardware_recommendations() {
    local family has_ext=0 id reason

    detect_machine_family
    family="$MACHINE_FAMILY"
    has_external_display && has_ext=1

    while IFS= read -r id; do
        [[ -z "$id" ]] && continue

        case "$(app_field "$id" INSTALL_METHOD)" in
            brew) brew_formula_installed "$(app_field "$id" PACKAGE)" && continue ;;
            cask) brew_cask_installed "$(app_field "$id" PACKAGE)" && continue ;;
        esac

        if reason="$(app_incompatibility_reason "$id")"; then
            selection_add "$id" "hardware"
        else
            SELECTION_LOAD_SKIPPED+="$id|$reason"$'\n'
        fi

    done < <(apps_recommended_for_hardware "$family" "$has_ext")
}
