#!/bin/bash

# =========================
# Deployment planner
# =========================
# Builds the Deployment Plan — the OFFICIAL CONTRACT between every layer.
# The planner is the only decision-making layer: it classifies whatever is
# in SELECTED_APPS (built by selection.sh, from a preset and/or manual
# toggles and/or hardware recommendations — the planner does not care which)
# into automatic/manual tracks, counts JB Picks, and freezes a plan.
# Everything after (renderer, installer, transaction, reports) only
# consumes the plan. Nothing in this file modifies the system, and nothing
# in this file resolves presets, bundles, or categories — that happened
# already, in selection.sh, before the plan is ever built.
#
# Plan contract (module-level globals, populated by the builder below):
#   PLAN_READY          1 when a plan is loaded
#   PLAN_ID             unique plan identifier (<preset-or-custom>_<stamp>)
#   PLAN_CREATED        creation timestamp
#   PLAN_PRESET_ID      preset ID the selection started from, or "custom"
#   PLAN_PRESET_NAME    display name ("Personalizado" for custom)
#   PLAN_ARCH           uname -m of this machine (compatibility context)
#   PLAN_MACOS          macOS version of this machine
#   PLAN_APPS           "id|name|provenance|method|package" — install order;
#                       method is brew|cask (the automated engine). The
#                       installer consumes these records verbatim and never
#                       reads the catalog. provenance is "preset:<id>",
#                       "hardware", or "manual" — display only.
#   PLAN_MANUAL         "id|name|provenance|method|download-url" — applications
#                       whose INSTALL_METHOD the toolkit cannot automate
#                       (mas, pkg, dmg, manual). First-class plan members,
#                       never failures: reported as manual steps.
#   PLAN_SKIPPED        "id|name|reason", one per line — applications the
#                       loaded preset wanted but that are incompatible with
#                       this machine. A technician simply not selecting an
#                       app is NOT a skip; it never enters SELECTED_APPS in
#                       the first place, so there is nothing to record.
#   PLAN_PICKS          app IDs within the plan marked JB_PICK=true
#   PLAN_APP_COUNT / PLAN_MANUAL_COUNT / PLAN_SKIP_COUNT / PLAN_PICK_COUNT

PLAN_READY=0
PLAN_ID=""
PLAN_CREATED=""
PLAN_PRESET_ID=""
PLAN_PRESET_NAME=""
PLAN_ARCH=""
PLAN_MACOS=""
PLAN_APPS=""
PLAN_MANUAL=""
PLAN_SKIPPED=""
PLAN_PICKS=""
PLAN_APP_COUNT=0
PLAN_MANUAL_COUNT=0
PLAN_SKIP_COUNT=0
PLAN_PICK_COUNT=0

reset_deployment_plan() {
    PLAN_READY=0
    PLAN_ID=""
    PLAN_CREATED=""
    PLAN_PRESET_ID=""
    PLAN_PRESET_NAME=""
    PLAN_ARCH=""
    PLAN_MACOS=""
    PLAN_APPS=""
    PLAN_MANUAL=""
    PLAN_SKIPPED=""
    PLAN_PICKS=""
    PLAN_APP_COUNT=0
    PLAN_MANUAL_COUNT=0
    PLAN_SKIP_COUNT=0
    PLAN_PICK_COUNT=0
}

# =========================
# Plan builder
# =========================

# _plan_add_app APP PROVENANCE — classifies one application into the
# automatic track (brew/cask) or the manual track (mas/pkg/dmg/manual) and
# counts it. PROVENANCE is opaque display text; this function never
# branches on it.
_plan_add_app() {
    local app="$1" provenance="$2"
    local app_name method

    app_name="$(app_field "$app" NAME)"
    method="$(app_field "$app" INSTALL_METHOD)"

    case "$method" in
        brew|cask)
            PLAN_APPS+="$app|$app_name|$provenance|$method|$(app_field "$app" PACKAGE_NAME)"$'\n'
            PLAN_APP_COUNT=$((PLAN_APP_COUNT + 1))
            ;;
        *)
            PLAN_MANUAL+="$app|$app_name|$provenance|$method|$(app_field "$app" DOWNLOAD_URL)"$'\n'
            PLAN_MANUAL_COUNT=$((PLAN_MANUAL_COUNT + 1))
            ;;
    esac

    if [[ "$(app_field "$app" JB_PICK)" == "true" ]]; then
        PLAN_PICKS+="$app"$'\n'
        PLAN_PICK_COUNT=$((PLAN_PICK_COUNT + 1))
    fi
}

_plan_add_skip() {
    local app="$1" reason="$2"

    PLAN_SKIPPED+="$app|$(app_field "$app" NAME)|$reason"$'\n'
    PLAN_SKIP_COUNT=$((PLAN_SKIP_COUNT + 1))
}

# build_plan_from_selection [PRESET_ID] — freezes the current SELECTED_APPS
# (and SELECTION_LOAD_SKIPPED) into a plan. PRESET_ID is purely identity —
# "which preset, if any, did this selection start from" — never re-read to
# decide membership; SELECTED_APPS already IS the final membership.
build_plan_from_selection() {
    local preset_id="${1:-}"
    local preset_name app provenance reason

    reset_deployment_plan

    if [[ -n "$preset_id" ]] && preset_exists "$preset_id"; then
        preset_name="$(preset_field "$preset_id" NAME)"
    else
        preset_id="custom"
        preset_name="Personalizado"
    fi

    PLAN_ID="${preset_id}_$(date '+%Y-%m-%d_%H-%M-%S')"
    PLAN_CREATED="$(session_timestamp)"
    PLAN_PRESET_ID="$preset_id"
    PLAN_PRESET_NAME="$preset_name"
    PLAN_ARCH="$(uname -m)"
    PLAN_MACOS="$(sw_vers -productVersion 2>/dev/null || echo "desconocido")"

    while IFS='|' read -r app provenance; do
        [[ -z "$app" ]] && continue
        _plan_add_app "$app" "$provenance"
    done <<< "$SELECTED_APPS"

    while IFS='|' read -r app reason; do
        [[ -z "$app" ]] && continue
        _plan_add_skip "$app" "$reason"
    done <<< "$SELECTION_LOAD_SKIPPED"

    PLAN_READY=1
}

# =========================
# Plan export
# =========================

# Serializes the current plan to logs/deployment_plan_<PLAN_ID>.env —
# human-readable, state.env-style. The installer executes exactly the plan
# this file describes; it exists for debugging, support, dry runs, and
# future report generation. Prints the file path on success.
export_deployment_plan() {

    [[ "$PLAN_READY" -eq 1 ]] || return 1

    local file="$BASE_DIR/logs/deployment_plan_${PLAN_ID}.env"
    local line

    {
        echo "# JB Toolkit — Deployment Plan"
        echo "# Formato: APP=id|nombre|origen|método|paquete · MANUAL=id|nombre|origen|método|url"
        echo "#          SKIP=id|nombre|motivo · PICK=id"
        echo "PLAN_ID=$PLAN_ID"
        echo "CREATED=$PLAN_CREATED"
        echo "PRESET_ID=$PLAN_PRESET_ID"
        echo "PRESET_NAME=$PLAN_PRESET_NAME"
        echo "ARCH=$PLAN_ARCH"
        echo "MACOS=$PLAN_MACOS"
        echo "APP_COUNT=$PLAN_APP_COUNT"
        echo "MANUAL_COUNT=$PLAN_MANUAL_COUNT"
        echo "SKIP_COUNT=$PLAN_SKIP_COUNT"
        echo "PICK_COUNT=$PLAN_PICK_COUNT"

        while IFS= read -r line; do
            [[ -n "$line" ]] && echo "APP=$line"
        done <<< "$PLAN_APPS"

        while IFS= read -r line; do
            [[ -n "$line" ]] && echo "MANUAL=$line"
        done <<< "$PLAN_MANUAL"

        while IFS= read -r line; do
            [[ -n "$line" ]] && echo "SKIP=$line"
        done <<< "$PLAN_SKIPPED"

        while IFS= read -r line; do
            [[ -n "$line" ]] && echo "PICK=$line"
        done <<< "$PLAN_PICKS"

    } > "$file"

    write_state_values "LAST_DEPLOYMENT_PLAN=$(basename "$file")"
    retain_recent_artifacts 'deployment_plan_*.env' 20

    printf "%s\n" "$file"
}
