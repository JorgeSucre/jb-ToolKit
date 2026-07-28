#!/bin/bash

# =========================
# Storage Platform — Public API
# =========================
# The only surface anything outside core/platform/storage/ should call.
# volume.sh / plan.sh / transaction.sh / engine.sh are this service's
# private implementation — no module outside this directory should read
# metadata.env/state.env directly, inspect STORAGE_* globals, or call a
# non-storage:: function from here on. These are thin wrappers; the
# implementation stays where it already lives.

# --- Volumes ---

# storage::discover_volumes — refreshes STORAGE_VOLUME_CACHE from what's
# actually plugged in right now.
storage::discover_volumes() {
    discover_storage_volumes
}

# storage::list_volumes — the current cache as data
# (mount|name|free|adopted|writable per line). Does not refresh; call
# discover_volumes first if freshness matters.
storage::list_volumes() {
    printf "%s" "$STORAGE_VOLUME_CACHE"
}

# storage::get_default_volume — first adopted volume found, if any. Refreshes
# discovery itself since "the default" only makes sense against current state.
storage::get_default_volume() {

    local mount name free adopted writable

    discover_storage_volumes

    while IFS='|' read -r mount name free adopted writable; do
        [[ -z "$mount" ]] && continue
        if [[ "$adopted" -eq 1 ]]; then
            printf "%s\n" "$mount"
            return 0
        fi
    done <<< "$STORAGE_VOLUME_CACHE"

    return 1
}

storage::is_managed() {
    is_adopted_volume "$1"
}

storage::adopt_volume() {
    initialize_managed_volume "$1"
}

# storage::forget_volume MOUNT — the inverse of adopt_volume. Archives
# .jbtoolkit rather than deleting it; never touches migrated data.
storage::forget_volume() {
    forget_volume "$1"
}

storage::free_space() {
    storage_volume_free_space "$1"
}

# storage::health MOUNT — a pure, read-only composite snapshot. Not wired
# into any menu; ready for a future Diagnostics integration to consume.
storage::health() {

    local mount="$1"
    local managed healthy free uuid last_verify
    local pending=0 last_txn="N/A"
    local txn_dir f state

    if is_adopted_volume "$mount"; then
        managed=true
    else
        managed=false
    fi

    if [[ "$managed" == "true" ]] && is_writable_volume "$mount"; then
        healthy=true
    else
        healthy=false
    fi

    free="$(storage_volume_free_space "$mount")"
    uuid="$(volume_metadata_value "$mount" TOOLKIT_UUID)"
    last_verify="$(volume_state_value "$mount" LAST_MIGRATION_AT)"

    txn_dir="$mount/$STORAGE_METADATA_DIRNAME/$STORAGE_TRANSACTIONS_SUBDIR"

    if [[ -d "$txn_dir" ]]; then
        while IFS= read -r f; do
            [[ -z "$f" ]] && continue
            state="$(read_kv_value "$f" STATE "")"
            case "$state" in
                committed|failed|cancelled) ;;
                *) pending=$((pending + 1)) ;;
            esac
            last_txn="$(basename "$f")"
        done < <(find "$txn_dir" -maxdepth 1 -name "*.env" 2>/dev/null | sort)
    fi

    echo "MANAGED=$managed"
    echo "HEALTHY=$healthy"
    echo "FREE_SPACE=${free:-N/A}"
    echo "VOLUME_UUID=$uuid"
    echo "PENDING_TRANSACTIONS=$pending"
    echo "LAST_TRANSACTION=$last_txn"
    echo "LAST_VERIFY=$last_verify"
}

# --- Transactions ---

# storage::verify SRC DST — the same checksum-diff check the engine uses
# before ever offering to delete a source.
storage::verify() {
    storage_verify_item "$1" "$2"
}

# storage::rollback DST — removes a partial/failed destination copy.
# Per-item only: there is no whole-transaction rollback. Once a transaction
# reaches "committed" and a disposal decision is made, this does not undo it.
storage::rollback() {
    storage_rollback_item "$1"
}

# storage::transactions MOUNT — lists this volume's transaction records as
# "id|state|result|start" lines, oldest first. Data only, not a browser.
storage::transactions() {

    local mount="$1"
    local dir="$mount/$STORAGE_METADATA_DIRNAME/$STORAGE_TRANSACTIONS_SUBDIR"
    local f id state result start

    [[ -d "$dir" ]] || return 0

    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        id="$(read_kv_value "$f" TXN_ID "")"
        state="$(read_kv_value "$f" STATE "")"
        result="$(read_kv_value "$f" RESULT "")"
        start="$(read_kv_value "$f" START "")"
        printf "%s|%s|%s|%s\n" "$id" "$state" "$result" "$start"
    done < <(find "$dir" -maxdepth 1 -name "*.env" 2>/dev/null | sort)
}

# --- Migration ---

# storage::run_profile — the interactive entry point: adopt/select volume,
# pick a profile, scan/plan/preview/execute/verify/commit. Everything else
# in this file is a query; this is the only one that changes anything.
storage::run_profile() {
    run_storage_management
}
