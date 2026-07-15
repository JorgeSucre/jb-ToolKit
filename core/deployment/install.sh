#!/bin/bash

# =========================
# Deployment installer (Phase 5)
# =========================
# Executes an already-built Deployment Plan. This layer makes NO decisions:
# no resolution, no compatibility rules, no catalog reads — the plan records
# carry everything (id|name|bundle|pkg-type|pkg-name). The engine is the
# same proven pattern Bootstrap uses (temporary Brewfile + retry +
# run_cmd --visible brew bundle), followed by per-app verification against
# a fresh Homebrew query. Results are recorded in the Installation
# Transaction and state.env — confirmed outcomes only, never estimates.

# Populated by _partition_plan_apps:
INSTALL_PENDING=""    # "id|name|pkg-type|pkg-name" — not yet installed
INSTALL_ALREADY=0     # count already present before execution

_partition_plan_apps() {

    local id name bundle ptype ppkg

    INSTALL_PENDING=""
    INSTALL_ALREADY=0

    while IFS='|' read -r id name bundle ptype ppkg; do
        [[ -z "$id" ]] && continue

        if [[ "$ptype" == "brew" ]] && brew_formula_installed "$ppkg"; then
            INSTALL_ALREADY=$((INSTALL_ALREADY + 1))
        elif [[ "$ptype" == "cask" ]] && brew_cask_installed "$ppkg"; then
            INSTALL_ALREADY=$((INSTALL_ALREADY + 1))
        else
            INSTALL_PENDING+="$id|$name|$ptype|$ppkg"$'\n'
        fi

    done <<< "$PLAN_APPS"
}

_compile_plan_brewfile() {

    local file="$1"
    local id name ptype ppkg

    : > "$file"

    while IFS='|' read -r id name ptype ppkg; do
        [[ -z "$id" ]] && continue

        if [[ "$ptype" == "brew" ]]; then
            printf 'brew "%s"\n' "$ppkg" >> "$file"
        else
            printf 'cask "%s"\n' "$ppkg" >> "$file"
        fi

    done <<< "$INSTALL_PENDING"
}

run_plan_installation() {

    [[ "$PLAN_READY" -eq 1 ]] || return 0

    local plan_file txn_file brewfile
    local id name ptype ppkg pending_count result

    if ! brew_available; then
        error_msg "❌ Homebrew no está disponible; ejecuta Initial Setup primero"
        return 1
    fi

    echo ""
    if ! ask_yes_no "¿Preparar este equipo con el perfil $PLAN_PROFILE_NAME?"; then
        plan_file="$(export_deployment_plan)"
        txn_begin "$(basename "$plan_file")"
        TXN_CANCELLED="true"
        txn_finish "cancelled"
        txn_file="$(txn_export)"
        info "ℹ️ Despliegue cancelado; no se realizaron cambios"
        return 0
    fi

    plan_file="$(export_deployment_plan)"
    txn_begin "$(basename "$plan_file")"

    _partition_plan_apps
    TXN_ALREADY="$INSTALL_ALREADY"

    pending_count=$(printf "%s" "$INSTALL_PENDING" | grep -c . || true)
    TXN_ATTEMPTED="$pending_count"

    if [[ "$pending_count" -eq 0 ]]; then

        txn_finish "success"
        txn_export >/dev/null

        write_state_values \
            "DEPLOYED_PROFILE=$PLAN_PROFILE_ID" \
            "LAST_DEPLOYMENT=$TXN_END" \
            "DEPLOYMENT_APPS_INSTALLED=0" \
            "DEPLOYMENT_APPS_FAILED=0"

        render_transaction
        return 0
    fi

    echo ""
    log "📦 Instalando $pending_count aplicaciones (esto puede tardar varios minutos)..."
    info "ℹ️ Homebrew mostrará progreso automáticamente"
    echo ""

    brewfile="${TMPDIR:-/tmp}/jb_deploy_brewfile.$$"
    _compile_plan_brewfile "$brewfile"

    # Same engine pattern Bootstrap uses for sync_brewfile
    if ! HOMEBREW_NO_ENV_HINTS=1 retry 3 5 run_cmd --visible brew bundle --file="$brewfile"; then
        warn "⚠️ brew bundle encontró problemas; verificando qué quedó instalado"
    fi

    rm -f "$brewfile" 2>/dev/null || true

    # Verification: confirmed outcomes only
    brew_cache_reset

    while IFS='|' read -r id name ptype ppkg; do
        [[ -z "$id" ]] && continue

        if { [[ "$ptype" == "brew" ]] && brew_formula_installed "$ppkg"; } \
            || { [[ "$ptype" == "cask" ]] && brew_cask_installed "$ppkg"; }; then
            TXN_INSTALLED_APPS+="$id|$name"$'\n'
            TXN_INSTALLED=$((TXN_INSTALLED + 1))
        else
            TXN_FAILED_APPS+="$id|$name"$'\n'
            TXN_FAILED=$((TXN_FAILED + 1))
        fi

    done <<< "$INSTALL_PENDING"

    if [[ "$TXN_FAILED" -eq 0 ]]; then
        result="success"
    elif [[ "$TXN_INSTALLED" -gt 0 ]]; then
        result="partial"
    else
        result="failed"
    fi

    txn_finish "$result"
    txn_file="$(txn_export)"

    write_state_values \
        "DEPLOYED_PROFILE=$PLAN_PROFILE_ID" \
        "LAST_DEPLOYMENT=$TXN_END" \
        "DEPLOYMENT_APPS_INSTALLED=$TXN_INSTALLED" \
        "DEPLOYMENT_APPS_FAILED=$TXN_FAILED"

    render_transaction
}
