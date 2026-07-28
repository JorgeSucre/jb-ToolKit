#!/bin/bash

# =========================
# Storage Management Engine
# =========================
# Generic planning primitives — scan, plan, preview, execute, verify,
# rollback, commit — shared by every migration profile. This file knows
# nothing about Home, Photos, Steam, Docker, or any other concrete source;
# it only knows the profile *contract* below. A profile is a directory under
# profiles/ with a declarative profile.env (id, label, destination subdir —
# always static) plus one dynamic callback (scan), so a Photos Library or
# Steam Library profile is two small files, never a change here.
#
# Profile contract — each profiles/<id>/profile.env declares PROFILE_ID,
# PROFILE_LABEL, DEST_SUBDIR (plain KEY=value); load_storage_profiles()
# reads it and calls register_storage_profile on the profile's behalf, then
# sources profiles/<id>/scan.sh, which must define:
#   storage_profile_<id>_source_root            → echoes the source root
#   storage_profile_<id>_scan <source_root>     → fills STORAGE_SCAN_CACHE
#                                                  with "name|size_mb|excluded"
#                                                  lines, source-relative
# Everything past scan (selection, planning, copy, verification, rollback,
# disposal) is entirely generic and never touches profile internals again.

STORAGE_PROFILE_REGISTRY=""      # id|label|dest_subdir, one per line
STORAGE_ACTIVE_PROFILE=""

STORAGE_SCAN_CACHE=""            # name|size_mb|excluded(0/1)
STORAGE_SOURCE_ROOT=""
STORAGE_DEST_ROOT=""

STORAGE_SELECTED_ITEMS=()
STORAGE_SELECTED_SIZES_MB=()

STORAGE_RSYNC_BIN=""
STORAGE_RSYNC_FLAGS=()

# =========================
# Profile registry
# =========================

register_storage_profile() {
    local id="$1" label="$2" dest_subdir="$3"
    STORAGE_PROFILE_REGISTRY+="$id|$label|$dest_subdir"$'\n'
}

# load_storage_profiles — discovers profiles/<id>/ directories next to this
# file (path is relative to engine.sh itself, so moving the whole storage
# subsystem never requires touching this). Adding a profile is a new
# directory; this function never changes.
load_storage_profiles() {

    local dir profiles_dir
    local PROFILE_ID PROFILE_LABEL DEST_SUBDIR

    profiles_dir="$(dirname "${BASH_SOURCE[0]}")/profiles"

    for dir in "$profiles_dir"/*/; do

        [[ -f "$dir/profile.env" ]] || continue

        PROFILE_ID=""
        PROFILE_LABEL=""
        DEST_SUBDIR=""

        source "$dir/profile.env"

        [[ -z "$PROFILE_ID" ]] && continue

        register_storage_profile "$PROFILE_ID" "$PROFILE_LABEL" "$DEST_SUBDIR"

        [[ -f "$dir/scan.sh" ]] && source "$dir/scan.sh"

    done
}

storage_profile_label() {

    local id="$1" pid label dest_subdir

    while IFS='|' read -r pid label dest_subdir; do
        [[ "$pid" == "$id" ]] && { printf "%s\n" "$label"; return 0; }
    done <<< "$STORAGE_PROFILE_REGISTRY"

    printf "%s\n" "$id"
}

storage_profile_dest_subdir() {

    local id="$1" pid label dest_subdir

    while IFS='|' read -r pid label dest_subdir; do
        [[ "$pid" == "$id" ]] && { printf "%s\n" "$dest_subdir"; return 0; }
    done <<< "$STORAGE_PROFILE_REGISTRY"

    printf "%s\n" ""
}

# select_storage_profile — auto-selects when exactly one profile is
# registered (today: only "home" is real; once a second profile exists
# this becomes a real menu with zero changes here). Sets
# STORAGE_ACTIVE_PROFILE.
select_storage_profile() {

    local id label dest_subdir choice index count
    local -a ids=()
    local -a labels=()

    while IFS='|' read -r id label dest_subdir; do
        [[ -z "$id" ]] && continue
        ids+=("$id")
        labels+=("$label")
    done <<< "$STORAGE_PROFILE_REGISTRY"

    count="${#ids[@]}"
    [[ "$count" -eq 0 ]] && return 1

    if [[ "$count" -eq 1 ]]; then
        STORAGE_ACTIVE_PROFILE="${ids[0]}"
        return 0
    fi

    print_section "🗄️ Perfiles de migración disponibles"

    for ((index=0; index<count; index++)); do
        printf "%s) %s\n" "$((index + 1))" "${labels[$index]}"
    done

    echo "0) Cancelar"
    echo ""
    printf "Selecciona un perfil: "
    read -r choice || choice="0"

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > count )); then
        return 1
    fi

    STORAGE_ACTIVE_PROFILE="${ids[$((choice - 1))]}"
    return 0
}

# =========================
# Scan (delegates to the active profile)
# =========================

storage_scan() {

    local profile_id="$1"
    local dest_subdir

    STORAGE_ACTIVE_PROFILE="$profile_id"
    STORAGE_SOURCE_ROOT="$("storage_profile_${profile_id}_source_root")"
    dest_subdir="$(storage_profile_dest_subdir "$profile_id")"
    STORAGE_DEST_ROOT="$STORAGE_VOLUME_NAMESPACE_ROOT/$dest_subdir"

    "storage_profile_${profile_id}_scan" "$STORAGE_SOURCE_ROOT"
}

# =========================
# Selection (generic — sizes + an editable exclusion list)
# =========================

toggle_storage_selection() {

    local name size_mb excluded index count selection item mark
    local -a names=()
    local -a sizes=()
    local -a states=()

    while IFS='|' read -r name size_mb excluded; do
        [[ -z "$name" ]] && continue
        names+=("$name")
        sizes+=("$size_mb")
        if [[ "$excluded" -eq 1 ]]; then
            states+=(0)
        else
            states+=(1)
        fi
    done <<< "$STORAGE_SCAN_CACHE"

    count="${#names[@]}"

    while true; do

        print_section "🗂️ Selección de elementos a migrar"
        echo "Perfil: $(storage_profile_label "$STORAGE_ACTIVE_PROFILE")"
        echo "Origen: $STORAGE_SOURCE_ROOT"
        echo ""

        for ((index=0; index<count; index++)); do
            if [[ "${states[$index]}" -eq 1 ]]; then
                mark="✓"
            else
                mark=" "
            fi
            printf "[%s] %s) %s (%s)\n" "$mark" "$((index + 1))" \
                "${names[$index]}" "$(human_size "${sizes[$index]}")"
        done

        echo ""
        printf "Números para incluir/excluir (ej: 1,3) · Enter para confirmar: "
        read -r selection || break

        [[ -z "$selection" ]] && break

        while IFS= read -r item; do
            index=$((item - 1))
            states[$index]=$((1 - states[$index]))
        done < <(parse_selection "$selection" "$count")

    done

    STORAGE_SELECTED_ITEMS=()
    STORAGE_SELECTED_SIZES_MB=()

    for ((index=0; index<count; index++)); do
        if [[ "${states[$index]}" -eq 1 ]]; then
            STORAGE_SELECTED_ITEMS+=("${names[$index]}")
            STORAGE_SELECTED_SIZES_MB+=("${sizes[$index]}")
        fi
    done
}

# =========================
# Preview (pure presentation over the plan — never mutates it)
# =========================

storage_preview() {

    local name size_mb

    print_section "📋 Resumen de migración"

    echo "Perfil: $STORAGE_PLAN_PROFILE_LABEL"
    echo "Origen: $STORAGE_PLAN_SOURCE_ROOT"
    echo "Destino: $STORAGE_PLAN_DEST_ROOT"
    echo ""

    if [[ "$STORAGE_PLAN_READY" -ne 1 ]]; then
        warn "⚠️ No se seleccionó ningún elemento para migrar"
        return 1
    fi

    echo "Elementos a migrar:"

    while IFS='|' read -r name size_mb; do
        [[ -z "$name" ]] && continue
        printf "  • %s (%s)\n" "$name" "$(human_size "$size_mb")"
    done <<< "$STORAGE_PLAN_ITEMS"

    echo ""
    printf "Tamaño total estimado: ~%s\n" "$(human_size "$STORAGE_PLAN_TOTAL_MB")"

    return 0
}

# =========================
# rsync capability detection
# =========================
# macOS ships an old rsync (no ACL/xattr support); Homebrew's rsync 3.x
# supports both. Detect what is actually installed instead of assuming.

resolve_rsync_binary() {

    if [[ -x /opt/homebrew/bin/rsync ]]; then
        printf "%s\n" "/opt/homebrew/bin/rsync"
    elif [[ -x /usr/local/bin/rsync ]]; then
        printf "%s\n" "/usr/local/bin/rsync"
    else
        printf "%s\n" "rsync"
    fi
}

rsync_supports_flag() {

    local bin="$1" flag="$2"

    "$bin" --help 2>&1 | grep -qe "$flag"
}

build_rsync_flags() {

    local bin="$1"

    STORAGE_RSYNC_FLAGS=(-a -H -E)

    rsync_supports_flag "$bin" "--acls" && STORAGE_RSYNC_FLAGS+=(-A)
    rsync_supports_flag "$bin" "--xattrs" && STORAGE_RSYNC_FLAGS+=(-X)
}

# =========================
# Execute + verify + rollback
# =========================

# Deliberately -a -H only, not $STORAGE_RSYNC_FLAGS: on modern macOS
# (openrsync), adding -E/-A/-X to a --checksum --dry-run pass reports a
# checksum mismatch on files that are byte-identical (verified against
# sha256 directly). Content + permissions + hardlinks is the safety-critical
# check before deletion; xattr fidelity was already the copy pass's job.
storage_verify_item() {

    local src="$1" dst="$2"
    local diff_count

    diff_count=$("$STORAGE_RSYNC_BIN" -a -H --checksum --dry-run -i \
        --exclude=".DS_Store" --exclude="*.icloud" \
        "$src/" "$dst/" 2>/dev/null \
        | wc -l | tr -d ' ')

    [[ "${diff_count:-1}" -eq 0 ]]
}

# storage_rollback_item DST — the only response to a copy failure. Source
# was never touched, so "rollback" here means erasing the partial,
# untrustworthy destination copy rather than leaving it to confuse a retry
# or a future verify pass.
storage_rollback_item() {

    local dst="$1"

    rm -rf "$dst" 2>/dev/null || true
    STORAGE_TXN_ROLLED_BACK=$((STORAGE_TXN_ROLLED_BACK + 1))
}

# storage_execute — copies every planned item, verifying and (on copy
# failure) rolling back each one individually. Source is never modified.
storage_execute() {

    local name size_mb src dst

    mkdir -p "$STORAGE_PLAN_DEST_ROOT" 2>/dev/null || {
        error_msg "❌ No se pudo crear la estructura en el destino"
        return 1
    }

    while IFS='|' read -r name size_mb; do

        [[ -z "$name" ]] && continue

        src="$STORAGE_PLAN_SOURCE_ROOT/$name"
        dst="$STORAGE_PLAN_DEST_ROOT/$name"

        mkdir -p "$dst" 2>/dev/null || true

        STORAGE_TXN_ATTEMPTED=$((STORAGE_TXN_ATTEMPTED + 1))

        print_section "📤 Copiando: $name"

        if ! run_cmd --visible "$STORAGE_RSYNC_BIN" "${STORAGE_RSYNC_FLAGS[@]}" \
            --exclude=".DS_Store" --exclude="*.icloud" \
            "$src/" "$dst/"; then

            warn "⚠️ rsync reportó errores al copiar $name; revirtiendo copia parcial"
            storage_rollback_item "$dst"
            STORAGE_TXN_FAILED=$((STORAGE_TXN_FAILED + 1))
            STORAGE_TXN_FAILED_ITEMS+="$name|copy_failed"$'\n'
            continue
        fi

        info "ℹ️ Verificando integridad de $name..."

        if storage_verify_item "$src" "$dst"; then
            success "✔ $name copiado y verificado"
            STORAGE_TXN_VERIFIED=$((STORAGE_TXN_VERIFIED + 1))
            STORAGE_TXN_VERIFIED_ITEMS+="$name|$size_mb"$'\n'
        else
            warn "⚠️ $name no pudo verificarse; ambas copias se conservan para revisión manual"
            STORAGE_TXN_FAILED=$((STORAGE_TXN_FAILED + 1))
            STORAGE_TXN_FAILED_ITEMS+="$name|verify_failed"$'\n'
        fi

    done <<< "$STORAGE_PLAN_ITEMS"

    return 0
}

finalize_storage_result() {

    if [[ "$STORAGE_TXN_ATTEMPTED" -eq 0 ]]; then
        STORAGE_TXN_RESULT="cancelled"
    elif [[ "$STORAGE_TXN_FAILED" -eq 0 ]]; then
        STORAGE_TXN_RESULT="success"
    elif [[ "$STORAGE_TXN_VERIFIED" -eq 0 ]]; then
        STORAGE_TXN_RESULT="failed"
    else
        STORAGE_TXN_RESULT="partial"
    fi
}

print_storage_results() {

    local name size_mb reason

    print_section "🧾 Resultado de la migración"

    while IFS='|' read -r name size_mb; do
        [[ -z "$name" ]] && continue
        success "✔ $name: copiado y verificado"
    done <<< "$STORAGE_TXN_VERIFIED_ITEMS"

    while IFS='|' read -r name reason; do
        [[ -z "$name" ]] && continue
        case "$reason" in
            copy_failed) error_msg "❌ $name: la copia falló y fue revertida (origen conservado)" ;;
            verify_failed) warn "⚠️ $name: copiado, verificación falló (ambas copias conservadas)" ;;
        esac
    done <<< "$STORAGE_TXN_FAILED_ITEMS"
}

# =========================
# Commit (disposal decision — the only path that removes source data)
# =========================

remove_verified_source() {

    local src="$1"
    local remaining

    find "$src" -mindepth 1 -exec rm -rf {} + 2>/dev/null || true
    mkdir -p "$src" 2>/dev/null || true

    remaining=$(find "$src" -mindepth 1 2>/dev/null | wc -l | tr -d ' ')

    [[ "${remaining:-1}" -eq 0 ]]
}

confirm_and_delete_verified_sources() {

    local name size_mb src

    warn "⚠️ Esta acción elimina permanentemente los elementos de origen ya verificados"

    ask_yes_no "¿Confirmas la eliminación del origen?" || {
        info "ℹ️ Eliminación cancelada; se conservan ambas copias"
        return 0
    }

    while IFS='|' read -r name size_mb; do

        [[ -z "$name" ]] && continue

        src="$STORAGE_PLAN_SOURCE_ROOT/$name"

        if remove_verified_source "$src"; then
            success "✔ Origen eliminado: $name"
            STORAGE_TXN_DELETED=$((STORAGE_TXN_DELETED + 1))
            TOTAL_FREED_MB=$((TOTAL_FREED_MB + size_mb))
            FILES_REMOVED=$((FILES_REMOVED + 1))
        else
            warn "⚠️ No se pudo eliminar completamente el origen: $name"
        fi

    done <<< "$STORAGE_TXN_VERIFIED_ITEMS"
}

storage_commit() {

    local choice

    if [[ "$STORAGE_TXN_VERIFIED" -eq 0 ]]; then
        warn "⚠️ Ningún elemento se verificó correctamente; no se eliminará nada del origen"
        STORAGE_TXN_DISPOSAL="none"
        return 0
    fi

    echo ""
    echo "1) Conservar ambas copias (recomendado)"
    echo "2) Eliminar del origen los elementos ya verificados"
    echo "3) Cancelar (no hacer nada más)"
    printf "Selecciona una opción: "
    read -r choice || choice="1"

    if [[ "$choice" == "2" ]]; then
        confirm_and_delete_verified_sources
        if [[ "$STORAGE_TXN_DELETED" -gt 0 ]]; then
            STORAGE_TXN_DISPOSAL="deleted"
        else
            STORAGE_TXN_DISPOSAL="kept"
        fi
    else
        info "ℹ️ Se conservan ambas copias"
        STORAGE_TXN_DISPOSAL="kept"
    fi
}

# =========================
# Top-level orchestrator
# =========================
# adopt/select volume -> pick profile -> scan -> plan -> preview -> confirm
# -> execute (+ verify + rollback per item) -> commit. Every early exit is a
# clean no-op: nothing is written to the destination and nothing is removed
# from the source until the technician has confirmed twice (the plan, then
# disposal).

run_storage_management() {

    print_section "🗄️ Storage Management"

    discover_storage_volumes

    if [[ -z "$STORAGE_VOLUME_CACHE" ]]; then
        info "ℹ️ No se detectaron discos externos disponibles"
        return 0
    fi

    if ! ask_yes_no "¿Deseas gestionar almacenamiento en un disco externo?"; then
        info "ℹ️ Gestión de almacenamiento omitida"
        return 0
    fi

    select_storage_volume || { info "ℹ️ Operación cancelada"; return 0; }

    select_storage_profile || { info "ℹ️ Operación cancelada"; return 0; }

    storage_scan "$STORAGE_ACTIVE_PROFILE"

    if [[ -z "$STORAGE_SCAN_CACHE" ]]; then
        info "ℹ️ No se encontraron elementos elegibles para este perfil"
        return 0
    fi

    toggle_storage_selection

    build_storage_plan "$STORAGE_ACTIVE_PROFILE"

    if ! storage_preview; then
        info "ℹ️ Migración cancelada"
        return 0
    fi

    ask_yes_no "¿Confirmas esta migración?" || { info "ℹ️ Migración cancelada"; return 0; }

    STORAGE_RSYNC_BIN="$(resolve_rsync_binary)"

    if ! command_exists "$STORAGE_RSYNC_BIN"; then
        error_msg "❌ rsync no está disponible en este sistema"
        return 0
    fi

    build_rsync_flags "$STORAGE_RSYNC_BIN"

    local plan_file
    plan_file="$(export_storage_plan)"

    txn_begin "$plan_file"
    txn_export >/dev/null   # checkpoint: planned — a record now exists even
                             # if nothing further ever runs

    STORAGE_TXN_STATE="executing"
    txn_export >/dev/null   # checkpoint: executing — the real crash window

    if ! storage_execute; then
        txn_finish "failed"
        STORAGE_TXN_STATE="failed"
        txn_export >/dev/null
        txn_record_summary_in_state
        return 0
    fi

    finalize_storage_result

    print_storage_results

    # Checkpoint the terminal STATE before disposal: "committed" means
    # execution concluded and a verdict exists, independent of whether the
    # technician chooses to keep or delete the source afterward.
    case "$STORAGE_TXN_RESULT" in
        cancelled) STORAGE_TXN_STATE="cancelled" ;;
        failed) STORAGE_TXN_STATE="failed" ;;
        *) STORAGE_TXN_STATE="committed" ;;
    esac
    txn_export >/dev/null

    storage_commit

    touch_volume_usage "$STORAGE_PLAN_VOLUME_MOUNT"

    txn_finish "$STORAGE_TXN_RESULT"
    txn_export >/dev/null
    txn_record_summary_in_state
}
