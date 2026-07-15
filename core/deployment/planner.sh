#!/bin/bash

# =========================
# Deployment planner
# =========================
# Builds the Deployment Plan — the OFFICIAL CONTRACT between every layer.
# The planner is the only decision-making layer: profile, bundles,
# application order, compatibility filtering, skips and reasons, JB Picks,
# provenance, and package specs are all decided here. Everything after
# (renderer, installer, transaction, reports) only consumes the plan.
# Nothing in this file modifies the system.
#
# Plan contract (module-level globals, populated by the builders below):
#   PLAN_READY          1 when a plan is loaded
#   PLAN_ID             unique plan identifier (<profile>_<stamp>)
#   PLAN_CREATED        creation timestamp
#   PLAN_PROFILE_ID     profile ID ("custom" for user-composed plans)
#   PLAN_PROFILE_NAME   display name
#   PLAN_PROFILE_DESC   one-line description
#   PLAN_ARCH           uname -m of this machine (compatibility context)
#   PLAN_MACOS          macOS version of this machine
#   PLAN_BUNDLES        bundle IDs, resolution order, one per line
#   PLAN_APPS           "id|name|source-bundle|pkg-type|pkg-name" — install
#                       order; pkg-type is brew|cask. The installer consumes
#                       these records verbatim and never reads the catalog.
#   PLAN_SKIPPED        "id|name|source-bundle|reason", one per line
#   PLAN_PICKS          app IDs within the plan marked JB_PICK=true
#   PLAN_APP_COUNT / PLAN_SKIP_COUNT / PLAN_PICK_COUNT

PLAN_READY=0
PLAN_ID=""
PLAN_CREATED=""
PLAN_PROFILE_ID=""
PLAN_PROFILE_NAME=""
PLAN_PROFILE_DESC=""
PLAN_ARCH=""
PLAN_MACOS=""
PLAN_BUNDLES=""
PLAN_APPS=""
PLAN_SKIPPED=""
PLAN_PICKS=""
PLAN_APP_COUNT=0
PLAN_SKIP_COUNT=0
PLAN_PICK_COUNT=0

reset_deployment_plan() {
    PLAN_READY=0
    PLAN_ID=""
    PLAN_CREATED=""
    PLAN_PROFILE_ID=""
    PLAN_PROFILE_NAME=""
    PLAN_PROFILE_DESC=""
    PLAN_ARCH=""
    PLAN_MACOS=""
    PLAN_BUNDLES=""
    PLAN_APPS=""
    PLAN_SKIPPED=""
    PLAN_PICKS=""
    PLAN_APP_COUNT=0
    PLAN_SKIP_COUNT=0
    PLAN_PICK_COUNT=0
}

# =========================
# Plan builders
# =========================

# build_plan_for_bundles ID NAME DESC BUNDLES(newline-separated IDs)
build_plan_for_bundles() {
    local id="$1" name="$2" desc="$3" bundles="$4"
    local app bundle reason app_name pkg_type pkg_name

    reset_deployment_plan

    PLAN_ID="${id}_$(date '+%Y-%m-%d_%H-%M-%S')"
    PLAN_CREATED="$(session_timestamp)"
    PLAN_PROFILE_ID="$id"
    PLAN_PROFILE_NAME="$name"
    PLAN_PROFILE_DESC="$desc"
    PLAN_ARCH="$(uname -m)"
    PLAN_MACOS="$(sw_vers -productVersion 2>/dev/null || echo "desconocido")"
    PLAN_BUNDLES="$bundles"

    resolve_install_set_for_bundles "$bundles"

    while IFS='|' read -r app bundle; do
        [[ -z "$app" ]] && continue

        app_name="$(app_field "$app" NAME)"

        pkg_name="$(app_field "$app" BREW)"
        if [[ -n "$pkg_name" ]]; then
            pkg_type="brew"
        else
            pkg_type="cask"
            pkg_name="$(app_field "$app" CASK)"
        fi

        PLAN_APPS+="$app|$app_name|$bundle|$pkg_type|$pkg_name"$'\n'
        PLAN_APP_COUNT=$((PLAN_APP_COUNT + 1))

        if [[ "$(app_field "$app" JB_PICK)" == "true" ]]; then
            PLAN_PICKS+="$app"$'\n'
            PLAN_PICK_COUNT=$((PLAN_PICK_COUNT + 1))
        fi

    done <<< "$RESOLVED_APPS"

    while IFS='|' read -r app bundle reason; do
        [[ -z "$app" ]] && continue

        app_name="$(app_field "$app" NAME)"
        PLAN_SKIPPED+="$app|$app_name|$bundle|$reason"$'\n'
        PLAN_SKIP_COUNT=$((PLAN_SKIP_COUNT + 1))

    done <<< "$RESOLVED_SKIPPED"

    PLAN_READY=1
}

build_deployment_plan() {
    local profile="$1"

    if ! profile_exists "$profile"; then
        error_msg "❌ El perfil no existe: $profile"
        return 1
    fi

    build_plan_for_bundles \
        "$profile" \
        "$(profile_field "$profile" NAME)" \
        "$(profile_field "$profile" DESCRIPTION)" \
        "$(profile_bundles "$profile")"
}

# build_custom_plan BUNDLES(newline-separated IDs)
build_custom_plan() {
    build_plan_for_bundles \
        "custom" \
        "Personalizado" \
        "Perfil personalizado compuesto por bundles seleccionados" \
        "$1"
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
    local bundle line

    {
        echo "# JB Toolkit — Deployment Plan"
        echo "# Formato: APP=id|nombre|bundle|tipo|paquete · SKIP=id|nombre|bundle|motivo · PICK=id"
        echo "PLAN_ID=$PLAN_ID"
        echo "CREATED=$PLAN_CREATED"
        echo "PROFILE_ID=$PLAN_PROFILE_ID"
        echo "PROFILE_NAME=$PLAN_PROFILE_NAME"
        echo "PROFILE_DESC=$PLAN_PROFILE_DESC"
        echo "ARCH=$PLAN_ARCH"
        echo "MACOS=$PLAN_MACOS"
        printf "BUNDLES="
        printf "%s" "$PLAN_BUNDLES" | tr '\n' ' ' | sed 's/ $//'
        echo ""
        echo "APP_COUNT=$PLAN_APP_COUNT"
        echo "SKIP_COUNT=$PLAN_SKIP_COUNT"
        echo "PICK_COUNT=$PLAN_PICK_COUNT"

        while IFS= read -r line; do
            [[ -n "$line" ]] && echo "APP=$line"
        done <<< "$PLAN_APPS"

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
