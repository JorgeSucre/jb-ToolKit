#!/bin/bash

# =========================
# Adopted Data Volume
# =========================
# An external APFS volume becomes "managed storage" the first time JB
# Toolkit writes its identity onto it: a namespace folder for migrated data,
# plus a hidden .jbtoolkit directory holding the volume's own identity and
# history. Every later run recognizes that volume on sight — it is presented
# as managed storage, not a generic external disk — instead of re-asking the
# technician to pick a destination from scratch.
#
# .jbtoolkit/ layout:
#   metadata.env   immutable identity: TOOLKIT_UUID, DISK_UUID,
#                  APFS_VOLUME_UUID, ADOPTED_BY, CREATED_AT,
#                  CREATED_BY_VERSION, SCHEMA_VERSION, LABEL
#   state.env      mutable: MIGRATION_COUNT, LAST_MIGRATION_AT
#   plans/         storage_plan_<id>.env (see plan.sh)
#   transactions/  storage_txn_<id>.env (see transaction.sh)
#
# These live on the volume itself, not the toolkit's own logs/, because the
# same drive plausibly shuttles data across many different Macs over time —
# a future "was there an interrupted migration" check needs to find the
# record by re-plugging the volume, not by trusting whichever Mac happened
# to run the operation.
#
# Nothing here knows about migration profiles, plans, or rsync; this file's
# only job is "which external volumes exist, which are ours, and how do we
# make one ours." engine.sh builds on top of it. Nothing outside this
# directory should read metadata.env/state.env directly — go through
# api.sh's storage:: functions instead.

STORAGE_SCHEMA_VERSION=2
STORAGE_NAMESPACE="JB Toolkit"
STORAGE_METADATA_DIRNAME=".jbtoolkit"
STORAGE_METADATA_FILE="metadata.env"
STORAGE_STATE_FILE="state.env"
STORAGE_PLANS_SUBDIR="plans"
STORAGE_TRANSACTIONS_SUBDIR="transactions"

STORAGE_VOLUME_CACHE=""          # mount|name|free_human|adopted(0/1)|writable(0/1)
STORAGE_VOLUME_MOUNT=""
STORAGE_VOLUME_UUID=""
STORAGE_VOLUME_NAMESPACE_ROOT=""

# =========================
# Console user (shared by adoption and every profile that needs "whose
# Home/Photos/Downloads is this" — the technician running JB Toolkit is not
# necessarily the account being migrated)
# =========================

detect_console_user() {

    local console_user

    console_user="$(stat -f%Su /dev/console 2>/dev/null || true)"

    if [[ -z "$console_user" || "$console_user" == "root" ]]; then
        console_user="${SUDO_USER:-$USER}"
    fi

    printf "%s\n" "$console_user"
}

resolve_user_home() {

    local user="$1" home

    home="$(dscl . -read "/Users/$user" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"

    if [[ -z "$home" || ! -d "$home" ]]; then
        home="$HOME"
    fi

    printf "%s\n" "$home"
}

# =========================
# Eligibility checks
# =========================

is_external_apfs_volume() {

    local mount="$1"
    local info

    [[ -d "$mount" ]] || return 1

    info="$(diskutil info "$mount" 2>/dev/null)" || return 1

    echo "$info" | grep -qi "Personality:.*APFS" || return 1
    echo "$info" | grep -Eqi "(Device Location|Internal):[[:space:]]*(External|No)" || return 1

    return 0
}

is_writable_volume() {

    local mount="$1"
    local probe="$mount/.jb_storage_write_test.$$"

    touch "$probe" 2>/dev/null || return 1
    rm -f "$probe" 2>/dev/null

    return 0
}

is_time_machine_volume() {

    local mount="$1"

    [[ -e "$mount/.com.apple.timemachine.donotpresent" ]] && return 0
    [[ -d "$mount/Backups.backupdb" ]] && return 0

    return 1
}

# =========================
# diskutil identity fields
# =========================

_diskutil_field() {

    local mount="$1" label="$2"
    local value

    value="$(diskutil info "$mount" 2>/dev/null \
        | grep "^[[:space:]]*${label}:" \
        | head -1 \
        | sed -E "s|^[[:space:]]*${label}:[[:space:]]*||")"

    printf "%s\n" "${value:-unknown}"
}

storage_volume_free_space() {
    df -H "$1" 2>/dev/null | awk 'NR==2 {print $4}'
}

# =========================
# Adoption
# =========================

# A directory (current schema) or a plain file at the same path (schema 1,
# pre-dating the metadata-directory format) both count as adopted — the
# distinction only matters when a volume is actually selected for use
# (see _upgrade_legacy_volume_metadata), never for mere discovery/listing.
is_adopted_volume() {

    local mount="$1"
    local root="$mount/$STORAGE_METADATA_DIRNAME"

    if [[ -d "$root" ]]; then
        [[ "$(volume_metadata_value "$mount" JBTOOLKIT_VOLUME)" == "true" ]]
        return $?
    fi

    if [[ -f "$root" ]]; then
        [[ "$(read_kv_value "$root" JBTOOLKIT_VOLUME "false")" == "true" ]]
        return $?
    fi

    return 1
}

is_legacy_flat_metadata() {
    [[ -f "$1/$STORAGE_METADATA_DIRNAME" ]]
}

volume_metadata_value() {
    local mount="$1" key="$2"
    read_kv_value "$mount/$STORAGE_METADATA_DIRNAME/$STORAGE_METADATA_FILE" "$key" "N/A"
}

volume_state_value() {
    local mount="$1" key="$2"
    read_kv_value "$mount/$STORAGE_METADATA_DIRNAME/$STORAGE_STATE_FILE" "$key" "N/A"
}

# initialize_managed_volume MOUNT — the only function that turns a generic
# external disk into managed storage. Creates the shared namespace folder
# (the "standard directory layout"; individual profiles create their own
# subfolder under it on first use), the hidden .jbtoolkit/ structure, and
# writes the volume's identity once.
initialize_managed_volume() {

    local mount="$1"
    local root="$mount/$STORAGE_METADATA_DIRNAME"
    local uuid owner disk_uuid apfs_uuid

    mkdir -p "$mount/$STORAGE_NAMESPACE" \
             "$root/$STORAGE_PLANS_SUBDIR" \
             "$root/$STORAGE_TRANSACTIONS_SUBDIR" 2>/dev/null \
        || { error_msg "❌ No se pudo inicializar el disco"; return 1; }

    uuid="$(uuidgen 2>/dev/null || echo "unknown")"
    owner="$(detect_console_user)"
    disk_uuid="$(_diskutil_field "$mount" "Disk / Partition UUID")"
    apfs_uuid="$(_diskutil_field "$mount" "Volume UUID")"

    {
        echo "JBTOOLKIT_VOLUME=true"
        echo "SCHEMA_VERSION=$STORAGE_SCHEMA_VERSION"
        echo "TOOLKIT_UUID=$uuid"
        echo "DISK_UUID=$disk_uuid"
        echo "APFS_VOLUME_UUID=$apfs_uuid"
        echo "CREATED_BY_VERSION=$JB_VERSION"
        echo "CREATED_AT=$(session_timestamp)"
        echo "ADOPTED_BY=$owner"
        echo "LABEL=$(basename "$mount")"
    } > "$root/$STORAGE_METADATA_FILE"

    {
        echo "MIGRATION_COUNT=0"
        echo "LAST_MIGRATION_AT=N/A"
    } > "$root/$STORAGE_STATE_FILE"

    success "✔ Disco inicializado como almacenamiento gestionado por JB Toolkit"
}

# _upgrade_legacy_volume_metadata MOUNT — a schema-1 volume has a single
# flat .jbtoolkit FILE (VOLUME_UUID, CREATED_AT, ADOPTED_BY,
# CREATED_BY_VERSION, MIGRATION_COUNT, LAST_MIGRATION_AT). Preserve every
# field that still has a home, add the two identity fields schema 1 never
# captured, then remove the old file. Never invoked by discovery/listing —
# only when a legacy volume is actually selected for use.
_upgrade_legacy_volume_metadata() {

    local mount="$1"
    local legacy="$mount/$STORAGE_METADATA_DIRNAME"
    local root="$mount/$STORAGE_METADATA_DIRNAME.upgrading"
    local toolkit_uuid created_by_version created_at adopted_by label
    local migration_count last_migration_at disk_uuid apfs_uuid

    toolkit_uuid="$(read_kv_value "$legacy" VOLUME_UUID unknown)"
    created_by_version="$(read_kv_value "$legacy" CREATED_BY_VERSION unknown)"
    created_at="$(read_kv_value "$legacy" CREATED_AT unknown)"
    adopted_by="$(read_kv_value "$legacy" ADOPTED_BY unknown)"
    label="$(read_kv_value "$legacy" LABEL "$(basename "$mount")")"
    migration_count="$(read_kv_value "$legacy" MIGRATION_COUNT 0)"
    last_migration_at="$(read_kv_value "$legacy" LAST_MIGRATION_AT N/A)"
    disk_uuid="$(_diskutil_field "$mount" "Disk / Partition UUID")"
    apfs_uuid="$(_diskutil_field "$mount" "Volume UUID")"

    mkdir -p "$root/$STORAGE_PLANS_SUBDIR" "$root/$STORAGE_TRANSACTIONS_SUBDIR" 2>/dev/null \
        || { error_msg "❌ No se pudo actualizar el formato de metadatos del disco"; return 1; }

    {
        echo "JBTOOLKIT_VOLUME=true"
        echo "SCHEMA_VERSION=$STORAGE_SCHEMA_VERSION"
        echo "TOOLKIT_UUID=$toolkit_uuid"
        echo "DISK_UUID=$disk_uuid"
        echo "APFS_VOLUME_UUID=$apfs_uuid"
        echo "CREATED_BY_VERSION=$created_by_version"
        echo "CREATED_AT=$created_at"
        echo "ADOPTED_BY=$adopted_by"
        echo "LABEL=$label"
    } > "$root/$STORAGE_METADATA_FILE"

    {
        echo "MIGRATION_COUNT=$migration_count"
        echo "LAST_MIGRATION_AT=$last_migration_at"
    } > "$root/$STORAGE_STATE_FILE"

    rm -f "$legacy"
    mv "$root" "$mount/$STORAGE_METADATA_DIRNAME"

    info "ℹ️ Metadatos del disco actualizados al formato actual (historial preservado)"
}

# touch_volume_usage MOUNT — called once per completed migration so the
# volume's own metadata becomes a small usage history, not just a birth
# certificate. Silently does nothing on an unmanaged/missing volume.
touch_volume_usage() {

    local mount="$1"
    local state_file="$mount/$STORAGE_METADATA_DIRNAME/$STORAGE_STATE_FILE"
    local count

    [[ -f "$state_file" ]] || return 0

    count="$(volume_state_value "$mount" MIGRATION_COUNT)"
    [[ "$count" =~ ^[0-9]+$ ]] || count=0
    count=$((count + 1))

    write_kv_values "$state_file" \
        "MIGRATION_COUNT=$count" \
        "LAST_MIGRATION_AT=$(session_timestamp)"
}

# check_volume_schema_compat MOUNT — a volume adopted by a newer JB Toolkit
# writes a SCHEMA_VERSION we may not understand; warn rather than guess.
check_volume_schema_compat() {

    local mount="$1" schema

    schema="$(volume_metadata_value "$mount" SCHEMA_VERSION)"
    [[ "$schema" =~ ^[0-9]+$ ]] || return 0

    if (( schema > STORAGE_SCHEMA_VERSION )); then
        warn "⚠️ Este disco fue adoptado por una versión más reciente de JB Toolkit; procede con precaución"
    fi
}

# forget_volume MOUNT — the inverse of adoption. Renames .jbtoolkit instead
# of deleting it: the volume is reported as unmanaged again, but migration
# history is recoverable rather than destroyed by a moment's misclick.
# Never touches migrated data, only adoption status.
forget_volume() {

    local mount="$1"
    local root="$mount/$STORAGE_METADATA_DIRNAME"
    local archived

    archived="$root.forgotten-$(date '+%Y%m%d%H%M%S')"

    [[ -e "$root" ]] || return 1

    mv "$root" "$archived" 2>/dev/null || return 1

    success "✔ Disco olvidado; el historial se conserva en $(basename "$archived")"
}

# =========================
# Discovery + selection
# =========================

discover_storage_volumes() {

    local vol free adopted writable

    STORAGE_VOLUME_CACHE=""

    for vol in /Volumes/*; do

        [[ -d "$vol" ]] || continue
        is_external_apfs_volume "$vol" || continue
        is_time_machine_volume "$vol" && continue

        free="$(storage_volume_free_space "$vol")"

        if is_adopted_volume "$vol"; then
            adopted=1
        else
            adopted=0
        fi

        # Writability is a per-volume STATUS, not a listing filter: a
        # perfectly real external disk (root:wheel-owned, ownership
        # enforcement on — a normal state for a drive formatted or
        # previously used elsewhere) fails the write probe for a non-root
        # technician. Silently dropping it from the list is indistinguishable
        # from "no external disks attached" — exactly the symptom this was
        # shipped to fix. It stays listed with an honest reason instead.
        if is_writable_volume "$vol"; then
            writable=1
        else
            writable=0
        fi

        STORAGE_VOLUME_CACHE+="$vol|$(basename "$vol")|${free:-N/A}|$adopted|$writable"$'\n'

    done
}

# select_storage_volume — presents every eligible external volume, marking
# adopted ones as managed storage. Picking an unmanaged volume offers to
# adopt it on the spot; declining returns to the list rather than failing
# outright. A legacy (schema-1) volume is transparently upgraded in place.
# Sets STORAGE_VOLUME_MOUNT / STORAGE_VOLUME_UUID /
# STORAGE_VOLUME_NAMESPACE_ROOT on success.
select_storage_volume() {

    local mount name free adopted writable choice index count status
    local -a mounts=()
    local -a names=()
    local -a frees=()
    local -a adopteds=()
    local -a writables=()

    while IFS='|' read -r mount name free adopted writable; do
        [[ -z "$mount" ]] && continue
        mounts+=("$mount")
        names+=("$name")
        frees+=("${free:-N/A}")
        adopteds+=("${adopted:-0}")
        writables+=("${writable:-1}")
    done <<< "$STORAGE_VOLUME_CACHE"

    count="${#mounts[@]}"

    while true; do

        print_section "💽 Discos externos disponibles"

        for ((index=0; index<count; index++)); do
            if [[ "${writables[$index]}" -eq 0 ]]; then
                status="⛔ Sin permisos de escritura"
            elif [[ "${adopteds[$index]}" -eq 1 ]]; then
                status="✅ Gestionado por JB Toolkit"
            else
                status="⚪ No gestionado"
            fi
            printf "%s) %s (%s libres) — %s\n" "$((index + 1))" \
                "${names[$index]}" "${frees[$index]}" "$status"
        done

        echo "0) Cancelar"
        echo ""
        printf "Selecciona el disco de destino: "
        read -r choice || choice="0"

        if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > count )); then
            return 1
        fi

        index=$((choice - 1))
        mount="${mounts[$index]}"

        if [[ "${writables[$index]}" -eq 0 ]]; then
            error_msg "❌ Sin permisos de escritura en la raíz de este disco"
            info "ℹ️ En Utilidad de Discos: selecciona el disco → Archivo → Activar 'Ignorar la propiedad en este volumen', o corrige los permisos del volumen"
            continue
        fi

        if [[ "${adopteds[$index]}" -eq 0 ]]; then

            warn "⚠️ Este disco no ha sido inicializado por JB Toolkit"

            if ! ask_yes_no "¿Deseas adoptarlo ahora como almacenamiento gestionado?"; then
                info "ℹ️ Selección cancelada"
                continue
            fi

            initialize_managed_volume "$mount" || continue

        elif is_legacy_flat_metadata "$mount"; then

            _upgrade_legacy_volume_metadata "$mount" || continue
        fi

        STORAGE_VOLUME_MOUNT="$mount"
        STORAGE_VOLUME_UUID="$(volume_metadata_value "$mount" TOOLKIT_UUID)"
        STORAGE_VOLUME_NAMESPACE_ROOT="$mount/$STORAGE_NAMESPACE"

        check_volume_schema_compat "$mount"

        return 0

    done
}
