#!/bin/bash

# =========================
# Storage Migration Transaction
# =========================
# The execution record — separate from the plan. The plan says what WOULD
# happen; the transaction records what ACTUALLY happened (per-item copy,
# verify, rollback, and disposal outcomes). Mirrors
# core/deployment/transaction.sh's role for the Deployment subsystem.
#
# Persisted incrementally, not just once at the end: STORAGE_TXN_STATE is
# set and the record re-exported at each real phase boundary (planned →
# executing → committed/failed/cancelled). This is what makes "was there an
# interrupted migration" answerable in the future without implementing
# resume now — a transaction file whose STATE is stuck at "executing" with
# no later write is a crash, discoverable by re-plugging the volume.
#
# STATE deliberately does NOT include copied/verified/rolled_back as
# top-level values: storage_execute() copies and verifies each item
# synchronously, in the same loop iteration, so there is no code-observable
# moment between them to checkpoint, and rollback is a per-item automatic
# side effect, never a whole-transaction outcome. Writing a STATE value the
# code can't actually produce would be a state-machine version of the false
# success message this project's truthfulness principle exists to prevent.
# The real per-item facts are preserved as STORAGE_TXN_VERIFIED/FAILED/
# ROLLED_BACK — counts, not top-level states. See
# docs/architecture/0004-transactions.md.
#
# Transaction contract (module-level globals):
#   STORAGE_TXN_ID              unique identifier (txn_<stamp>, sortable filename)
#   STORAGE_TXN_UUID            unique identifier (uuidgen, the canonical one)
#   STORAGE_TXN_STATE           planned | executing | committed | failed | cancelled
#   STORAGE_TXN_SESSION         session log basename
#   STORAGE_TXN_PROFILE         profile ID from the executed plan
#   STORAGE_TXN_PLAN_ID         plan identifier
#   STORAGE_TXN_PLAN_FILE       exported plan file path
#   STORAGE_TXN_VOLUME_MOUNT    destination volume
#   STORAGE_TXN_START / END / DURATION
#   STORAGE_TXN_ATTEMPTED       items handed to the copy engine
#   STORAGE_TXN_VERIFIED        items confirmed identical after copy
#   STORAGE_TXN_FAILED          items that failed to copy or to verify
#   STORAGE_TXN_ROLLED_BACK     items whose partial destination was removed
#   STORAGE_TXN_DELETED         items whose verified source was removed
#   STORAGE_TXN_DISPOSAL        none | kept | deleted
#   STORAGE_TXN_RESULT          success | partial | failed | cancelled — set
#                                only at the true end, by txn_finish
#   STORAGE_TXN_VERIFIED_ITEMS  "name|size_mb"
#   STORAGE_TXN_FAILED_ITEMS    "name|reason" — copy_failed | verify_failed

STORAGE_TXN_ID=""
STORAGE_TXN_UUID=""
STORAGE_TXN_STATE=""
STORAGE_TXN_SESSION=""
STORAGE_TXN_PROFILE=""
STORAGE_TXN_PLAN_ID=""
STORAGE_TXN_PLAN_FILE=""
STORAGE_TXN_VOLUME_MOUNT=""
STORAGE_TXN_START=""
STORAGE_TXN_END=""
STORAGE_TXN_DURATION=0
STORAGE_TXN_ATTEMPTED=0
STORAGE_TXN_VERIFIED=0
STORAGE_TXN_FAILED=0
STORAGE_TXN_ROLLED_BACK=0
STORAGE_TXN_DELETED=0
STORAGE_TXN_DISPOSAL="none"
STORAGE_TXN_RESULT=""
STORAGE_TXN_VERIFIED_ITEMS=""
STORAGE_TXN_FAILED_ITEMS=""

_STORAGE_TXN_START_EPOCH=0

# txn_begin PLAN_FILE_PATH — snapshots plan identity and start time. Leaves
# STATE at "planned"; the caller exports immediately after (see engine.sh)
# so a transaction record exists on disk before any copying starts.
txn_begin() {

    STORAGE_TXN_ID="txn_$(date '+%Y-%m-%d_%H-%M-%S')"
    STORAGE_TXN_UUID="$(uuidgen 2>/dev/null || echo "unknown")"
    STORAGE_TXN_STATE="planned"
    STORAGE_TXN_SESSION="$(basename "${JB_SESSION_LOG:-desconocido}")"
    STORAGE_TXN_PROFILE="$STORAGE_PLAN_PROFILE_ID"
    STORAGE_TXN_PLAN_ID="$STORAGE_PLAN_ID"
    STORAGE_TXN_PLAN_FILE="${1:-}"
    STORAGE_TXN_VOLUME_MOUNT="$STORAGE_PLAN_VOLUME_MOUNT"
    STORAGE_TXN_START="$(session_timestamp)"
    STORAGE_TXN_END=""
    STORAGE_TXN_DURATION=0
    STORAGE_TXN_ATTEMPTED=0
    STORAGE_TXN_VERIFIED=0
    STORAGE_TXN_FAILED=0
    STORAGE_TXN_ROLLED_BACK=0
    STORAGE_TXN_DELETED=0
    STORAGE_TXN_DISPOSAL="none"
    STORAGE_TXN_RESULT=""
    STORAGE_TXN_VERIFIED_ITEMS=""
    STORAGE_TXN_FAILED_ITEMS=""

    _STORAGE_TXN_START_EPOCH=$(date +%s)

    session_write INFO "Storage transaction started: $STORAGE_TXN_ID (plan $STORAGE_TXN_PLAN_ID)"
}

# txn_finish RESULT — stamps end time, duration, and outcome. Does not
# itself write to disk; the caller still calls txn_export afterward.
txn_finish() {

    STORAGE_TXN_RESULT="$1"
    STORAGE_TXN_END="$(session_timestamp)"
    STORAGE_TXN_DURATION=$(( $(date +%s) - _STORAGE_TXN_START_EPOCH ))

    session_write INFO "Storage transaction finished: $STORAGE_TXN_ID ($STORAGE_TXN_RESULT)"
}

# Persists the record to <volume>/.jbtoolkit/transactions/<STORAGE_TXN_ID>.env.
# Idempotent (always overwrites the same file by ID) and safe to call
# repeatedly — the engine calls it at each STATE transition, not just once
# at the end, so the on-disk record always reflects the latest known state.
txn_export() {

    local txns_dir="$STORAGE_TXN_VOLUME_MOUNT/$STORAGE_METADATA_DIRNAME/$STORAGE_TRANSACTIONS_SUBDIR"
    local file="$txns_dir/${STORAGE_TXN_ID}.env"
    local line

    mkdir -p "$txns_dir" 2>/dev/null || return 1

    {
        echo "# JB Toolkit — Storage Migration Transaction"
        echo "# Formato: VERIFIED_ITEM=nombre|tamaño_mb · FAILED_ITEM=nombre|motivo"
        echo "TXN_ID=$STORAGE_TXN_ID"
        echo "TXN_UUID=$STORAGE_TXN_UUID"
        echo "STATE=$STORAGE_TXN_STATE"
        echo "SESSION=$STORAGE_TXN_SESSION"
        echo "PROFILE=$STORAGE_TXN_PROFILE"
        echo "PLAN_ID=$STORAGE_TXN_PLAN_ID"
        echo "PLAN_FILE=$STORAGE_TXN_PLAN_FILE"
        echo "VOLUME_MOUNT=$STORAGE_TXN_VOLUME_MOUNT"
        echo "START=$STORAGE_TXN_START"
        echo "END=$STORAGE_TXN_END"
        echo "DURATION_SECONDS=$STORAGE_TXN_DURATION"
        echo "ATTEMPTED=$STORAGE_TXN_ATTEMPTED"
        echo "VERIFIED=$STORAGE_TXN_VERIFIED"
        echo "FAILED=$STORAGE_TXN_FAILED"
        echo "ROLLED_BACK=$STORAGE_TXN_ROLLED_BACK"
        echo "DELETED=$STORAGE_TXN_DELETED"
        echo "DISPOSAL=$STORAGE_TXN_DISPOSAL"
        echo "RESULT=$STORAGE_TXN_RESULT"

        while IFS= read -r line; do
            [[ -n "$line" ]] && echo "VERIFIED_ITEM=$line"
        done <<< "$STORAGE_TXN_VERIFIED_ITEMS"

        while IFS= read -r line; do
            [[ -n "$line" ]] && echo "FAILED_ITEM=$line"
        done <<< "$STORAGE_TXN_FAILED_ITEMS"

    } > "$file"

    printf "%s\n" "$file"
}

# txn_record_summary_in_state — updates the toolkit's own local state.env
# with the generic "last migration" keys. Called once, by the caller, after
# the true final txn_export (not at every checkpoint — an in-progress
# checkpoint's empty END/RESULT would otherwise clobber the last real
# summary).
txn_record_summary_in_state() {

    write_state_values \
        "LAST_STORAGE_TRANSACTION=$STORAGE_TXN_VOLUME_MOUNT/$STORAGE_METADATA_DIRNAME/$STORAGE_TRANSACTIONS_SUBDIR/${STORAGE_TXN_ID}.env" \
        "LAST_STORAGE_MIGRATION=$STORAGE_TXN_END" \
        "STORAGE_MIGRATION_PROFILE=$STORAGE_TXN_PROFILE" \
        "STORAGE_MIGRATION_VOLUME=$STORAGE_TXN_VOLUME_MOUNT" \
        "STORAGE_MIGRATION_MB_COPIED=$STORAGE_PLAN_TOTAL_MB" \
        "STORAGE_MIGRATION_ITEMS_DELETED=$STORAGE_TXN_DELETED"
}
