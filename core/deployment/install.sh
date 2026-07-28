#!/bin/bash

# =========================
# Deployment installer
# =========================
# Executes an already-built Deployment Plan. This layer makes NO decisions:
# no resolution, no compatibility rules, no catalog reads — the plan records
# carry everything (id|name|source|method|package and the manual track).
# The engine is the same proven pattern Bootstrap uses (retry +
# run_cmd --visible + post-run verification against a fresh Homebrew
# query), applied PER APPLICATION so one failed or unavailable app never
# prevents the rest from installing. Before anything is modified, a
# read-only pre-flight verifies every pending package against Homebrew.
# Results are recorded in the Installation Transaction and state.env —
# confirmed outcomes only, never estimates.

# Populated by _partition_plan_apps / _preflight_plan:
INSTALL_PENDING=""       # "id|name|method|package" — automatic, not installed
INSTALL_AVAILABLE=""     # pending records confirmed available in Homebrew
INSTALL_UNAVAILABLE=""   # pending records Homebrew does not know

# Sorts every plan record into its verified starting state: automatic apps
# into already-installed (Homebrew query) or pending; manual-track apps into
# already-installed (app bundle present in /Applications) or a named manual
# step. Purely mechanical — every rule was decided by the planner.
_partition_plan_apps() {

    local id name _source method pkg url

    INSTALL_PENDING=""

    while IFS='|' read -r id name _source method pkg; do
        [[ -z "$id" ]] && continue

        if { [[ "$method" == "brew" ]] && brew_formula_installed "$pkg"; } \
            || { [[ "$method" == "cask" ]] && brew_cask_installed "$pkg"; }; then
            TXN_ALREADY_APPS+="$id|$name"$'\n'
            TXN_ALREADY=$((TXN_ALREADY + 1))
        else
            INSTALL_PENDING+="$id|$name|$method|$pkg"$'\n'
        fi

    done <<< "$PLAN_APPS"

    while IFS='|' read -r id name _source method url; do
        [[ -z "$id" ]] && continue

        if [[ -d "/Applications/$name.app" ]]; then
            TXN_ALREADY_APPS+="$id|$name"$'\n'
            TXN_ALREADY=$((TXN_ALREADY + 1))
        else
            TXN_MANUAL_APPS+="$id|$name"$'\n'
            TXN_MANUAL=$((TXN_MANUAL + 1))
        fi

    done <<< "$PLAN_MANUAL"
}

# Read-only availability check against Homebrew's index
_package_available() {
    if [[ "$1" == "brew" ]]; then
        brew info --formula "$2" >/dev/null 2>&1
    else
        brew info --cask "$2" >/dev/null 2>&1
    fi
}

# Pre-flight: verify every pending package before any system modification.
# Splits INSTALL_PENDING into INSTALL_AVAILABLE / INSTALL_UNAVAILABLE and
# shows the technician exactly what will happen.
_preflight_plan() {

    local id name method pkg

    INSTALL_AVAILABLE=""
    INSTALL_UNAVAILABLE=""

    print_section "🔎 Comprobando el despliegue"
    info "ℹ️ Verificación previa; todavía no se ha modificado nada"
    echo ""

    while IFS='|' read -r id name method pkg; do
        [[ -z "$id" ]] && continue

        if _package_available "$method" "$pkg"; then
            success "   ✓ $name"
            INSTALL_AVAILABLE+="$id|$name|$method|$pkg"$'\n'
        else
            error_msg "   ❌ $name — no disponible en Homebrew ($method: $pkg)"
            INSTALL_UNAVAILABLE+="$id|$name|$method|$pkg"$'\n'
        fi

    done <<< "$INSTALL_PENDING"

    while IFS='|' read -r id name; do
        [[ -z "$id" ]] && continue
        warn "   ✋ $name — instalación manual requerida"
    done <<< "$TXN_MANUAL_APPS"

    while IFS='|' read -r id name; do
        [[ -z "$id" ]] && continue
        info "   • $name — ya instalada"
    done <<< "$TXN_ALREADY_APPS"
}

# After the result screen: offer to open each manual app's download page.
# Declining still prints the URL — the technician always leaves knowing
# where to get the app.
_offer_manual_downloads() {

    [[ "$TXN_MANUAL" -gt 0 ]] || return 0

    local record id name line url
    local -a manual=()

    while IFS= read -r record; do
        [[ -n "$record" ]] && manual+=("$record")
    done <<< "$TXN_MANUAL_APPS"

    echo ""

    for record in "${manual[@]}"; do
        id="${record%%|*}"
        name="${record#*|}"

        line="$(grep -m1 "^$id|" <<< "$PLAN_MANUAL" || true)"
        url="${line##*|}"
        [[ -z "$url" ]] && continue

        if ask_yes_no "¿Abrir la página de descarga de $name?"; then
            run_cmd open "$url" || warn "⚠️ No se pudo abrir $url"
        else
            info "ℹ️ Página de $name: $url"
        fi
    done
}

run_plan_installation() {

    [[ "$PLAN_READY" -eq 1 ]] || return 0

    local plan_file record id name method pkg result
    local available_count=0 index=0 total=0
    local -a queue=()

    if [[ "$PLAN_APP_COUNT" -gt 0 ]] && ! brew_available; then
        error_msg "❌ Homebrew no está disponible; ejecuta Initial Setup primero"
        return 1
    fi

    echo ""
    if ! ask_yes_no "¿Preparar este equipo con la plantilla $PLAN_PRESET_NAME?"; then
        plan_file="$(export_deployment_plan)"
        txn_begin "$(basename "$plan_file")"
        TXN_CANCELLED="true"
        txn_finish "cancelled"
        txn_export >/dev/null
        info "ℹ️ Despliegue cancelado; no se realizaron cambios"
        return 0
    fi

    plan_file="$(export_deployment_plan)"
    txn_begin "$(basename "$plan_file")"

    _partition_plan_apps
    _preflight_plan

    # Unavailable packages are named failures decided before execution —
    # they never block the rest of the deployment.
    while IFS='|' read -r id name method pkg; do
        [[ -z "$id" ]] && continue
        TXN_FAILED_APPS+="$id|$name|no disponible en Homebrew"$'\n'
        TXN_FAILED=$((TXN_FAILED + 1))
    done <<< "$INSTALL_UNAVAILABLE"

    if [[ "$TXN_FAILED" -gt 0 ]]; then
        echo ""
        if ! ask_yes_no "¿Continuar sin las aplicaciones no disponibles?"; then
            TXN_CANCELLED="true"
            txn_finish "cancelled"
            txn_export >/dev/null
            info "ℹ️ Despliegue cancelado; no se realizaron cambios"
            return 0
        fi
    fi

    while IFS= read -r record; do
        [[ -n "$record" ]] && queue+=("$record")
    done <<< "$INSTALL_AVAILABLE"

    available_count="${#queue[@]}"
    TXN_ATTEMPTED="$available_count"

    if [[ "$available_count" -gt 0 ]]; then

        echo ""
        log "📦 Instalando $available_count aplicaciones (esto puede tardar varios minutos)..."
        info "ℹ️ Cada aplicación se instala por separado; un fallo no detiene al resto"
        echo ""

        # The engine pattern, per application: retry + run_cmd --visible,
        # verified afterward. A failure here is only noted; the verdict
        # comes from the post-run verification below.
        total="$available_count"
        for ((index=0; index<total; index++)); do
            IFS='|' read -r id name method pkg <<< "${queue[$index]}"

            echo ""
            log "📦 [$((index + 1))/$total] $name"

            if [[ "$method" == "brew" ]]; then
                HOMEBREW_NO_ENV_HINTS=1 retry 3 5 run_cmd --visible brew install "$pkg" \
                    || warn "⚠️ La instalación de $name reportó errores; se verificará al final"
            else
                HOMEBREW_NO_ENV_HINTS=1 retry 3 5 run_cmd --visible brew install --cask "$pkg" \
                    || warn "⚠️ La instalación de $name reportó errores; se verificará al final"
            fi
        done

        # Verification: confirmed outcomes only, from a fresh query
        brew_cache_reset

        while IFS='|' read -r id name method pkg; do
            [[ -z "$id" ]] && continue

            if { [[ "$method" == "brew" ]] && brew_formula_installed "$pkg"; } \
                || { [[ "$method" == "cask" ]] && brew_cask_installed "$pkg"; }; then
                TXN_INSTALLED_APPS+="$id|$name"$'\n'
                TXN_INSTALLED=$((TXN_INSTALLED + 1))
            else
                TXN_FAILED_APPS+="$id|$name|no quedó instalada tras la instalación"$'\n'
                TXN_FAILED=$((TXN_FAILED + 1))
            fi

        done <<< "$INSTALL_AVAILABLE"
    fi

    # Manual steps are honest outcomes, never deployment failures
    if [[ "$TXN_FAILED" -eq 0 ]]; then
        result="success"
    elif [[ "$TXN_INSTALLED" -gt 0 ]]; then
        result="partial"
    else
        result="failed"
    fi

    txn_finish "$result"
    txn_export >/dev/null

    write_state_values \
        "DEPLOYED_PRESET=$PLAN_PRESET_ID" \
        "LAST_DEPLOYMENT=$TXN_END" \
        "DEPLOYMENT_APPS_INSTALLED=$TXN_INSTALLED" \
        "DEPLOYMENT_APPS_MANUAL=$TXN_MANUAL" \
        "DEPLOYMENT_APPS_FAILED=$TXN_FAILED"

    render_transaction

    _offer_manual_downloads
}
