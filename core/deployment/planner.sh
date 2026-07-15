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
#   PLAN_APPS           "id|name|source|method|package" — install order;
#                       method is brew|cask (the automated engine). The
#                       installer consumes these records verbatim and never
#                       reads the catalog. source is a bundle ID, or the
#                       literal "hardware" for hardware recommendations.
#   PLAN_MANUAL         "id|name|source|method|download-url" — applications
#                       whose INSTALL_METHOD the toolkit cannot automate
#                       (mas, pkg, dmg, manual). First-class plan members,
#                       never failures: reported as manual steps.
#   PLAN_SKIPPED        "id|name|source|reason", one per line — includes
#                       compatibility skips AND technician deselections
#   PLAN_PICKS          app IDs within the plan marked JB_PICK=true
#   PLAN_APP_COUNT / PLAN_MANUAL_COUNT / PLAN_SKIP_COUNT / PLAN_PICK_COUNT

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
    PLAN_PROFILE_ID=""
    PLAN_PROFILE_NAME=""
    PLAN_PROFILE_DESC=""
    PLAN_ARCH=""
    PLAN_MACOS=""
    PLAN_BUNDLES=""
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
# Plan builders
# =========================

# _plan_add_app APP SOURCE — classifies one application into the automatic
# track (brew/cask) or the manual track (mas/pkg/dmg/manual) and counts it
_plan_add_app() {
    local app="$1" source="$2"
    local app_name method

    app_name="$(app_field "$app" NAME)"
    method="$(app_field "$app" INSTALL_METHOD)"

    case "$method" in
        brew|cask)
            PLAN_APPS+="$app|$app_name|$source|$method|$(app_field "$app" PACKAGE)"$'\n'
            PLAN_APP_COUNT=$((PLAN_APP_COUNT + 1))
            ;;
        *)
            PLAN_MANUAL+="$app|$app_name|$source|$method|$(app_field "$app" DOWNLOAD_URL)"$'\n'
            PLAN_MANUAL_COUNT=$((PLAN_MANUAL_COUNT + 1))
            ;;
    esac

    if [[ "$(app_field "$app" JB_PICK)" == "true" ]]; then
        PLAN_PICKS+="$app"$'\n'
        PLAN_PICK_COUNT=$((PLAN_PICK_COUNT + 1))
    fi
}

_plan_add_skip() {
    local app="$1" source="$2" reason="$3"

    PLAN_SKIPPED+="$app|$(app_field "$app" NAME)|$source|$reason"$'\n'
    PLAN_SKIP_COUNT=$((PLAN_SKIP_COUNT + 1))
}

# build_plan_for_bundles ID NAME DESC BUNDLES [EXCLUDED] [EXTRAS]
#   BUNDLES   newline-separated bundle IDs (resolution order)
#   EXCLUDED  newline-separated app IDs the technician deselected during
#             bundle review — recorded as named skips, never silent
#   EXTRAS    newline-separated app IDs added outside the bundles
#             (hardware recommendations) — provenance "hardware"
build_plan_for_bundles() {
    local id="$1" name="$2" desc="$3" bundles="$4"
    local excluded="${5:-}" extras="${6:-}"
    local app bundle reason

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

        if [[ -n "$excluded" ]] && grep -qx "$app" <<< "$excluded"; then
            _plan_add_skip "$app" "$bundle" "deseleccionada por el técnico"
            continue
        fi

        _plan_add_app "$app" "$bundle"

    done <<< "$RESOLVED_APPS"

    while IFS='|' read -r app bundle reason; do
        [[ -z "$app" ]] && continue
        _plan_add_skip "$app" "$bundle" "$reason"
    done <<< "$RESOLVED_SKIPPED"

    while IFS= read -r app; do
        [[ -z "$app" ]] && continue

        # Already decided through a bundle (any track) → nothing to add
        if grep -q "^$app|" <<< "$PLAN_APPS$PLAN_MANUAL$PLAN_SKIPPED"; then
            continue
        fi

        if reason="$(app_incompatibility_reason "$app")"; then
            _plan_add_app "$app" "hardware"
        else
            _plan_add_skip "$app" "hardware" "$reason"
        fi

    done <<< "$extras"

    PLAN_READY=1
}

# build_deployment_plan PROFILE [EXCLUDED] [EXTRAS] [BUNDLES]
# BUNDLES overrides the profile's bundle list (bundle review may drop some);
# omitted or empty = every bundle the profile references.
build_deployment_plan() {
    local profile="$1"
    local bundles="${4:-}"

    if ! profile_exists "$profile"; then
        error_msg "❌ El perfil no existe: $profile"
        return 1
    fi

    [[ -n "$bundles" ]] || bundles="$(profile_bundles "$profile")"

    build_plan_for_bundles \
        "$profile" \
        "$(profile_field "$profile" NAME)" \
        "$(profile_field "$profile" DESCRIPTION)" \
        "$bundles" \
        "${2:-}" \
        "${3:-}"
}

# build_custom_plan BUNDLES [EXCLUDED] [EXTRAS]
build_custom_plan() {
    build_plan_for_bundles \
        "custom" \
        "Personalizado" \
        "Perfil personalizado compuesto por bundles seleccionados" \
        "$1" \
        "${2:-}" \
        "${3:-}"
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
        echo "# Formato: APP=id|nombre|origen|método|paquete · MANUAL=id|nombre|origen|método|url"
        echo "#          SKIP=id|nombre|origen|motivo · PICK=id"
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
