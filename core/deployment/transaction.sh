#!/bin/bash

# =========================
# Installation Transaction
# =========================
# The execution record — separate from the Deployment Plan. The plan says
# what WOULD happen; the transaction records what ACTUALLY happened. It
# makes no decisions. Future Reports, Support Bundles, and History consume
# this record instead of reconstructing events.
#
# Transaction contract (module-level globals):
#   TXN_ID              unique identifier (txn_<stamp>)
#   TXN_SESSION         session log basename (links to full CMD/EXIT evidence)
#   TXN_PROFILE         profile ID from the executed plan
#   TXN_PLAN_ID         plan identifier
#   TXN_PLAN_FILE       exported plan file basename
#   TXN_START / TXN_END / TXN_DURATION
#   TXN_ATTEMPTED       apps handed to the engine
#   TXN_INSTALLED       apps CONFIRMED installed afterward (verified count)
#   TXN_ALREADY         apps verified present before execution
#   TXN_SKIPPED         plan-level skips (compatibility + deselections)
#   TXN_MANUAL          apps that require a manual installation step
#   TXN_FAILED          apps that did not verify, or were unavailable
#   TXN_CANCELLED       true when the user backed out at a gate
#   TXN_RESULT          success | partial | failed | cancelled
#   TXN_INSTALLED_APPS / TXN_ALREADY_APPS / TXN_MANUAL_APPS  "id|name"
#   TXN_FAILED_APPS     "id|name|reason" — every failure carries its cause

TXN_ID=""
TXN_SESSION=""
TXN_PROFILE=""
TXN_PLAN_ID=""
TXN_PLAN_FILE=""
TXN_START=""
TXN_END=""
TXN_DURATION=0
TXN_ATTEMPTED=0
TXN_INSTALLED=0
TXN_ALREADY=0
TXN_SKIPPED=0
TXN_MANUAL=0
TXN_FAILED=0
TXN_CANCELLED="false"
TXN_RESULT=""
TXN_INSTALLED_APPS=""
TXN_ALREADY_APPS=""
TXN_MANUAL_APPS=""
TXN_FAILED_APPS=""

_TXN_START_EPOCH=0

# txn_begin PLAN_FILE_BASENAME — snapshots plan identity and start time
txn_begin() {

    TXN_ID="txn_$(date '+%Y-%m-%d_%H-%M-%S')"
    TXN_SESSION="$(basename "${JB_SESSION_LOG:-desconocido}")"
    TXN_PROFILE="$PLAN_PROFILE_ID"
    TXN_PLAN_ID="$PLAN_ID"
    TXN_PLAN_FILE="${1:-}"
    TXN_START="$(session_timestamp)"
    TXN_END=""
    TXN_DURATION=0
    TXN_ATTEMPTED=0
    TXN_INSTALLED=0
    TXN_ALREADY=0
    TXN_SKIPPED="$PLAN_SKIP_COUNT"
    TXN_MANUAL=0
    TXN_FAILED=0
    TXN_CANCELLED="false"
    TXN_RESULT=""
    TXN_INSTALLED_APPS=""
    TXN_ALREADY_APPS=""
    TXN_MANUAL_APPS=""
    TXN_FAILED_APPS=""

    _TXN_START_EPOCH=$(date +%s)

    session_write INFO "Deployment transaction started: $TXN_ID (plan $TXN_PLAN_ID)"
}

# txn_finish RESULT — stamps end time, duration, and outcome
txn_finish() {

    TXN_RESULT="$1"
    TXN_END="$(session_timestamp)"
    TXN_DURATION=$(( $(date +%s) - _TXN_START_EPOCH ))

    session_write INFO "Deployment transaction finished: $TXN_ID ($TXN_RESULT)"
}

# Persists the record to logs/deployment_txn_<TXN_ID>.env and points
# state.env at it. Prints the file path.
txn_export() {

    local file="$BASE_DIR/logs/deployment_${TXN_ID}.env"
    local line

    {
        echo "# JB Toolkit — Installation Transaction"
        echo "# Formato: INSTALLED_APP/ALREADY_APP/MANUAL_APP=id|nombre"
        echo "#          FAILED_APP=id|nombre|motivo"
        echo "TXN_ID=$TXN_ID"
        echo "SESSION=$TXN_SESSION"
        echo "PROFILE=$TXN_PROFILE"
        echo "PLAN_ID=$TXN_PLAN_ID"
        echo "PLAN_FILE=$TXN_PLAN_FILE"
        echo "START=$TXN_START"
        echo "END=$TXN_END"
        echo "DURATION_SECONDS=$TXN_DURATION"
        echo "ATTEMPTED=$TXN_ATTEMPTED"
        echo "INSTALLED=$TXN_INSTALLED"
        echo "ALREADY_INSTALLED=$TXN_ALREADY"
        echo "SKIPPED=$TXN_SKIPPED"
        echo "MANUAL=$TXN_MANUAL"
        echo "FAILED=$TXN_FAILED"
        echo "CANCELLED=$TXN_CANCELLED"
        echo "RESULT=$TXN_RESULT"

        while IFS= read -r line; do
            [[ -n "$line" ]] && echo "INSTALLED_APP=$line"
        done <<< "$TXN_INSTALLED_APPS"

        while IFS= read -r line; do
            [[ -n "$line" ]] && echo "ALREADY_APP=$line"
        done <<< "$TXN_ALREADY_APPS"

        while IFS= read -r line; do
            [[ -n "$line" ]] && echo "MANUAL_APP=$line"
        done <<< "$TXN_MANUAL_APPS"

        while IFS= read -r line; do
            [[ -n "$line" ]] && echo "FAILED_APP=$line"
        done <<< "$TXN_FAILED_APPS"

    } > "$file"

    write_state_values "LAST_DEPLOYMENT_TRANSACTION=$(basename "$file")"
    retain_recent_artifacts 'deployment_txn_*.env' 20

    printf "%s\n" "$file"
}
