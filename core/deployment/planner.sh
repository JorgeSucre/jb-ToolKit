#!/bin/bash

# =========================
# Deployment planner
# =========================
# Builds the Deployment Plan — the single source of truth for what a
# deployment WOULD do on this machine. The plan is fully renderable and
# reviewable without any installer existing; the future installer (Phase 5)
# executes an already-built plan and never makes decisions of its own.
# Nothing in this file modifies the system.
#
# Plan contract (module-level globals, populated by the builders below):
#   PLAN_READY          1 when a plan is loaded
#   PLAN_PROFILE_ID     profile ID ("custom" for user-composed plans)
#   PLAN_PROFILE_NAME   display name
#   PLAN_PROFILE_DESC   one-line description
#   PLAN_ARCH           uname -m of this machine (compatibility context)
#   PLAN_MACOS          macOS version of this machine
#   PLAN_BUNDLES        bundle IDs, resolution order, one per line
#   PLAN_APPS           "id|name|source-bundle", install order, one per line
#   PLAN_SKIPPED        "id|name|source-bundle|reason", one per line
#   PLAN_PICKS          app IDs within the plan marked JB_PICK=true
#   PLAN_APP_COUNT / PLAN_SKIP_COUNT / PLAN_PICK_COUNT

PLAN_READY=0
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
    local app bundle reason app_name

    reset_deployment_plan

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
        PLAN_APPS+="$app|$app_name|$bundle"$'\n'
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
