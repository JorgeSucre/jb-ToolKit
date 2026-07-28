#!/bin/bash

# =========================
# Storage Migration Plan
# =========================
# The official contract between the interactive selection screens and
# execution: what would happen, decided once, then only ever read — never
# recomputed mid-flight. Mirrors core/deployment/planner.sh's role for the
# Deployment subsystem.
#
# Plan contract (module-level globals):
#   STORAGE_PLAN_READY          1 when a plan is loaded
#   STORAGE_PLAN_ID             unique plan identifier (<profile>_<stamp>)
#   STORAGE_PLAN_CREATED        creation timestamp
#   STORAGE_PLAN_PROFILE_ID     profile ID ("home", "downloads", …)
#   STORAGE_PLAN_PROFILE_LABEL  display name
#   STORAGE_PLAN_VOLUME_MOUNT   destination volume mount point
#   STORAGE_PLAN_VOLUME_UUID    destination volume's adopted identity
#   STORAGE_PLAN_SOURCE_ROOT    profile source root (e.g. the user's Home)
#   STORAGE_PLAN_DEST_ROOT      destination root under the volume namespace
#   STORAGE_PLAN_ITEMS          "name|size_mb", one per line, source-relative
#   STORAGE_PLAN_ITEM_COUNT
#   STORAGE_PLAN_TOTAL_MB

STORAGE_PLAN_READY=0
STORAGE_PLAN_ID=""
STORAGE_PLAN_CREATED=""
STORAGE_PLAN_PROFILE_ID=""
STORAGE_PLAN_PROFILE_LABEL=""
STORAGE_PLAN_VOLUME_MOUNT=""
STORAGE_PLAN_VOLUME_UUID=""
STORAGE_PLAN_SOURCE_ROOT=""
STORAGE_PLAN_DEST_ROOT=""
STORAGE_PLAN_ITEMS=""
STORAGE_PLAN_ITEM_COUNT=0
STORAGE_PLAN_TOTAL_MB=0

reset_storage_plan() {
    STORAGE_PLAN_READY=0
    STORAGE_PLAN_ID=""
    STORAGE_PLAN_CREATED=""
    STORAGE_PLAN_PROFILE_ID=""
    STORAGE_PLAN_PROFILE_LABEL=""
    STORAGE_PLAN_VOLUME_MOUNT=""
    STORAGE_PLAN_VOLUME_UUID=""
    STORAGE_PLAN_SOURCE_ROOT=""
    STORAGE_PLAN_DEST_ROOT=""
    STORAGE_PLAN_ITEMS=""
    STORAGE_PLAN_ITEM_COUNT=0
    STORAGE_PLAN_TOTAL_MB=0
}

# build_storage_plan PROFILE_ID — consumes STORAGE_SELECTED_ITEMS /
# STORAGE_SELECTED_SIZES_MB (the toggled scan result) plus the
# volume/profile context the engine already resolved (STORAGE_VOLUME_*,
# STORAGE_SOURCE_ROOT, STORAGE_DEST_ROOT) and freezes them into a plan.
build_storage_plan() {

    local profile_id="$1"
    local i

    reset_storage_plan

    STORAGE_PLAN_ID="${profile_id}_$(date '+%Y-%m-%d_%H-%M-%S')"
    STORAGE_PLAN_CREATED="$(session_timestamp)"
    STORAGE_PLAN_PROFILE_ID="$profile_id"
    STORAGE_PLAN_PROFILE_LABEL="$(storage_profile_label "$profile_id")"
    STORAGE_PLAN_VOLUME_MOUNT="$STORAGE_VOLUME_MOUNT"
    STORAGE_PLAN_VOLUME_UUID="$STORAGE_VOLUME_UUID"
    STORAGE_PLAN_SOURCE_ROOT="$STORAGE_SOURCE_ROOT"
    STORAGE_PLAN_DEST_ROOT="$STORAGE_DEST_ROOT"

    for ((i=0; i<${#STORAGE_SELECTED_ITEMS[@]}; i++)); do
        STORAGE_PLAN_ITEMS+="${STORAGE_SELECTED_ITEMS[$i]}|${STORAGE_SELECTED_SIZES_MB[$i]}"$'\n'
        STORAGE_PLAN_TOTAL_MB=$((STORAGE_PLAN_TOTAL_MB + STORAGE_SELECTED_SIZES_MB[i]))
        STORAGE_PLAN_ITEM_COUNT=$((STORAGE_PLAN_ITEM_COUNT + 1))
    done

    [[ "$STORAGE_PLAN_ITEM_COUNT" -gt 0 ]] && STORAGE_PLAN_READY=1
}

# Serializes the current plan to <volume>/.jbtoolkit/plans/storage_plan_<ID>.env
# — human readable, state.env-style. Lives on the volume, not the toolkit's
# own logs/, so the record travels with the drive across machines (see
# volume.sh's header comment). Exists for debugging, support, and eventually
# a Storage History browser, same role as export_deployment_plan.
export_storage_plan() {

    [[ "$STORAGE_PLAN_READY" -eq 1 ]] || return 1

    local plans_dir="$STORAGE_PLAN_VOLUME_MOUNT/$STORAGE_METADATA_DIRNAME/$STORAGE_PLANS_SUBDIR"
    local file="$plans_dir/storage_plan_${STORAGE_PLAN_ID}.env"
    local line

    mkdir -p "$plans_dir" 2>/dev/null || return 1

    {
        echo "# JB Toolkit — Storage Migration Plan"
        echo "# Formato: ITEM=nombre|tamaño_mb"
        echo "PLAN_ID=$STORAGE_PLAN_ID"
        echo "CREATED=$STORAGE_PLAN_CREATED"
        echo "PROFILE_ID=$STORAGE_PLAN_PROFILE_ID"
        echo "PROFILE_LABEL=$STORAGE_PLAN_PROFILE_LABEL"
        echo "VOLUME_MOUNT=$STORAGE_PLAN_VOLUME_MOUNT"
        echo "VOLUME_UUID=$STORAGE_PLAN_VOLUME_UUID"
        echo "SOURCE_ROOT=$STORAGE_PLAN_SOURCE_ROOT"
        echo "DEST_ROOT=$STORAGE_PLAN_DEST_ROOT"
        echo "ITEM_COUNT=$STORAGE_PLAN_ITEM_COUNT"
        echo "TOTAL_MB=$STORAGE_PLAN_TOTAL_MB"

        while IFS= read -r line; do
            [[ -n "$line" ]] && echo "ITEM=$line"
        done <<< "$STORAGE_PLAN_ITEMS"

    } > "$file"

    # Full path, not a basename: unlike deployment plans, this file does not
    # live under $BASE_DIR/logs — it's only valid while this specific volume
    # is mounted at this path. A known, accepted limitation (see
    # docs/architecture/0004-transactions.md); nothing programmatic consumes
    # this key today.
    write_state_values "LAST_STORAGE_PLAN=$file"

    printf "%s\n" "$file"
}
