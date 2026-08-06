#!/bin/bash

# =========================
# Deployment menus
# =========================
# One workflow, one selection model. Navigation is generated entirely from
# catalog data (list_app_categories) — no category name is hardcoded here.
#
# As of v2.4.1, presets are gone from this file entirely — real-world use
# showed technicians always end up hand-picking from the catalog anyway, so
# the v2.4.0 in-catalog `l` command was cut as a concept nobody reached for
# (see ADR-0012). The standalone Deployment entry (run_deployment_menu)
# still goes straight to the Application Catalog with nothing pre-loaded.
# start_deployment_flow's PRESET_ID parameter is kept for Bootstrap's
# onboarding wizard (core/bootstrap/wizard.sh), which still asks its own
# "how will this Mac be used?" question up front as part of first-run setup
# — a different, deliberately-kept screen in a different module; presets
# remain fully real for it and for the CLI (--resolve/--explain/--tree/
# --plan), just not reachable from this file's own interactive screen.
#
# Flow: Application Catalog -> confirm.sh's review/confirmation screen ->
# install. Whether an application entered the selection via a preset
# (wizard-only now) or a manual toggle, it is the exact same kind of member
# of SELECTED_APPS by the time the Application Catalog screen (or the plan)
# sees it — see selection.sh. Hardware recommendations never enter
# SELECTED_APPS at all — they are advisory-only (a ★ badge), see below.

# =========================
# Application Catalog — the one screen everything else feeds into. Groups
# applications by CATEGORY for browsing, rendered as a responsive grid (1-3
# columns by terminal width, see _catalog_terminal_columns) so wide
# terminals show far more of the catalog per screen. Toggling is a flat,
# continuously numbered list (row-major across the grid) so parse_selection's
# "1,3-5" syntax works across the whole screen regardless of column or
# category boundaries. An incompatible application is shown with its reason
# on its own full-width line instead of a grid cell — never selectable,
# never a silent gap in the numbering scheme technicians rely on.
# =========================

# CATALOG_MENU_HW_IDS: app IDs recommended for this machine, cached once per
# run_application_catalog call — read by the ★ badge (always shown, never
# tied to selection) and by _app_matches_filter's "hardware" filter.
CATALOG_MENU_HW_IDS=""

# _app_matches_filters ID FILTER_MODE — true iff ID passes the active
# filter ("" | "picks" | "hardware"). Search is checked separately
# (catalog_matches_query) so the two narrow independently.
_app_matches_filter() {
    local id="$1" filter_mode="$2"

    case "$filter_mode" in
        "")        return 0 ;;
        picks)     [[ "$(app_field "$id" JB_PICK)" == "true" ]] ;;
        hardware)  grep -qx "$id" <<< "$CATALOG_MENU_HW_IDS" ;;
    esac
}

# _catalog_sorted_category_apps TAG — apps_in_category's app IDs, re-ordered
# JB Picks first, then hardware-recommended, then everything else,
# alphabetical within each tier — so the highest-relevance apps in a
# category are visible first regardless of column layout. Selection state
# is deliberately NOT a sort key: re-sorting a list the technician is
# actively toggling through would shift item numbers out from under them
# mid-selection.
_catalog_sorted_category_apps() {
    local tag="$1" id tier name

    for id in $(apps_in_category "$tag"); do
        if [[ "$(app_field "$id" JB_PICK)" == "true" ]]; then
            tier=0
        elif grep -qx "$id" <<< "$CATALOG_MENU_HW_IDS"; then
            tier=1
        else
            tier=2
        fi
        name="$(app_field "$id" NAME)"
        printf "%d|%s|%s\n" "$tier" "$name" "$id"
    done | sort -t'|' -k1,1n -k2,2 | cut -d'|' -f3
}

# CATALOG_NAME_WIDTH: static padding cap for the name field in a grid cell.
# Empirically 173 of 181 current catalog names are <= 28 chars; the rare
# longer name just overflows its own row by a few characters (self-
# contained, never affects other rows) rather than being truncated and
# hiding real information. A deliberate fixed constant, not a per-render
# scan of every app name — see ADR-0012.
CATALOG_NAME_WIDTH=28

# _catalog_terminal_columns — column count from the real terminal width,
# re-read on every screen render so a live resize is reflected immediately.
#
# This is always called as `cols="$(_catalog_terminal_columns)"`, so its
# own stdout is a pipe, not the terminal — `tput cols` can survive that by
# falling back to whichever of stdout/stderr is still a real tty, but not
# once BOTH are non-terminals, which is exactly what `tput cols
# 2>/dev/null` used to produce here. That silently returns tput's
# terminfo-default column count (80 on this system) instead of the real
# width, landing on the "1 column" breakpoint regardless of actual size —
# proven with `h() { local x; x="$(tput cols 2>/dev/null)"; echo "$x"; };
# echo "$(h)"` returning the wrong value in a real pty (see
# ADR-0012-followup / commit history for the full trace).
#
# `stty size </dev/tty` reads the controlling terminal directly instead —
# immune to which of the process's own fds happens to be piped, and immune
# to $TERM/terminfo entirely (raw ioctl, not a capability lookup). `tput
# cols` and `$COLUMNS` remain as fallbacks for when there's no controlling
# terminal at all (non-interactive/CI use).
_catalog_terminal_columns() {
    local width

    width="$(stty size </dev/tty 2>/dev/null | awk '{print $2}')"
    [[ "$width" =~ ^[0-9]+$ ]] || width="$(tput cols 2>/dev/null)"
    [[ "$width" =~ ^[0-9]+$ ]] || width="${COLUMNS:-80}"

    if [[ "$width" -ge 150 ]]; then
        printf "3\n"
    elif [[ "$width" -ge 100 ]]; then
        printf "2\n"
    else
        printf "1\n"
    fi
}

# _catalog_render_entry ID NUM SELECTED(0|1) PAD(0|1) — one grid cell.
# Every badge lives in a fixed-width slot (glyph+space, or two plain spaces
# when absent) instead of being conditionally appended, so a row's
# alignment never depends on WHICH badges happen to be present — only on
# whether a glyph happens to render 1 or 2 terminal columns wide in a given
# font, a small, bounded, self-contained risk instead of a compounding one
# (see ADR-0012). PAD=0 (the last cell in a row, or single-column mode)
# omits the trailing name padding and gutter (keeping a single separating
# space before any badge), so a lone/last entry stays unpadded and
# single-column mode looks like a plain list.
_catalog_render_entry() {
    local id="$1" num="$2" selected="$3" pad="$4"
    local mark=" " installed_slot="  " pick_slot="  " rec_slot="  " name

    [[ "$selected" -eq 1 ]] && mark="✓"
    app_already_installed "$id" && installed_slot="✔ "
    [[ "$(app_field "$id" JB_PICK)" == "true" ]] && pick_slot="⭐ "
    grep -qx "$id" <<< "$CATALOG_MENU_HW_IDS" && rec_slot="★ "
    name="$(app_field "$id" NAME)"

    if [[ "$pad" -eq 1 ]]; then
        printf "[%s] %3d) ${GREEN}%s${NC}%-${CATALOG_NAME_WIDTH}s%s%s  " \
            "$mark" "$num" "$installed_slot" "$name" "$pick_slot" "$rec_slot"
    else
        printf "[%s] %3d) ${GREEN}%s${NC}%s %s%s" \
            "$mark" "$num" "$installed_slot" "$name" "$pick_slot" "$rec_slot"
    fi
}

# _catalog_print_grid COLS ENTRY... — row-major grid over "id|num" strings
# (encoding two values per bash-3.2-safe array element — no namerefs).
# Consecutive numbers run left-to-right so a typed range ("3-5") stays
# visually adjacent — deliberately not the column-major order `ls -C`
# uses, which would scatter a typed range across the screen.
_catalog_print_grid() {
    local cols="$1"; shift
    local -a entries=("$@")
    local n="${#entries[@]}" i col pad line id num selected

    for ((i = 0; i < n; i += cols)); do
        line=""
        for ((col = 0; col < cols && i + col < n; col++)); do
            IFS='|' read -r id num <<< "${entries[$((i + col))]}"
            pad=1
            [[ "$((col + 1))" -eq "$cols" || "$((i + col + 1))" -eq "$n" ]] && pad=0
            selected=0
            selection_contains "$id" && selected=1
            line+="$(_catalog_render_entry "$id" "$num" "$selected" "$pad")"
        done
        printf "%s\n" "$line"
    done
}

# run_application_catalog — interactive toggle loop over SELECTED_APPS.
# Search (/query) and filters (p: JB Picks, h: recommended for this Mac)
# narrow the same flat numbered list in place — no separate screen, so
# parse_selection's "1,3-5" syntax and the toggle behavior stay identical
# to the unfiltered view. d<n> opens the Application View for item n.
# Returns 1 if the technician cancels (0), 0 otherwise (Enter to continue).
run_application_catalog() {

    local tag id reason selection item detail_num detail_ack entry
    local search_query="" filter_mode="" filter_label match_count cols
    local family has_ext=0
    local -a categories=()
    local -a app_ids=()

    while IFS= read -r tag; do
        [[ -n "$tag" ]] && categories+=("$tag")
    done < <(list_app_categories)

    detect_machine_family
    family="$MACHINE_FAMILY"
    has_external_display && has_ext=1
    CATALOG_MENU_HW_IDS="$(apps_recommended_for_hardware "$family" "$has_ext")"

    while true; do

        app_ids=()
        match_count=0
        cols="$(_catalog_terminal_columns)"

        print_section "🗂️ Catálogo de aplicaciones"
        printf "Seleccionadas: %s\n" "$(selection_count)"

        filter_label=""
        [[ -n "$search_query" ]] && filter_label+="Buscando: \"$search_query\"  "
        case "$filter_mode" in
            picks)    filter_label+="Filtro: JB Picks" ;;
            hardware) filter_label+="Filtro: recomendadas para este Mac" ;;
        esac
        [[ -n "$filter_label" ]] && printf "%s\n" "$filter_label"

        for tag in "${categories[@]}"; do

            local -a cat_apps=() cat_compat=() cat_incompat=()
            while IFS= read -r id; do
                [[ -n "$id" ]] || continue
                _app_matches_filter "$id" "$filter_mode" || continue
                catalog_matches_query "$id" "$search_query" || continue
                cat_apps+=("$id")
            done < <(_catalog_sorted_category_apps "$tag")

            [[ "${#cat_apps[@]}" -eq 0 ]] && continue

            for id in "${cat_apps[@]}"; do

                match_count=$((match_count + 1))

                if reason="$(app_incompatibility_reason "$id")"; then
                    app_ids+=("$id")
                    cat_compat+=("$id|${#app_ids[@]}")
                else
                    cat_incompat+=("$id|$reason")
                fi

            done

            echo ""
            printf -- "── %s (%d) ──\n" "$tag" "${#cat_apps[@]}"
            [[ "${#cat_compat[@]}" -gt 0 ]] && _catalog_print_grid "$cols" "${cat_compat[@]}"

            # Bash 3.2 (this project's floor) treats "${arr[@]}" on a
            # zero-element array as an unbound-variable error under `set
            # -u`, unlike later bash — ${#arr[@]} is always safe, so the
            # loop is guarded on count rather than iterated directly.
            [[ "${#cat_incompat[@]}" -eq 0 ]] && continue
            for entry in "${cat_incompat[@]}"; do
                IFS='|' read -r id reason <<< "$entry"
                printf "    ⛔ %s — %s\n" "$(app_field "$id" NAME)" "$reason"
            done

        done

        if [[ "$match_count" -eq 0 ]]; then
            echo ""
            warn "⚠️ Sin resultados"
        fi

        echo ""
        echo "Números para incluir/excluir (ej: 1,3-5) · [/texto] buscar · [/] limpiar búsqueda"
        echo "[P] Solo JB Picks · [H] Recomendadas para este Mac · [D#] Ver detalle · Enter continuar · 0 cancelar"
        printf "Selección: "
        read -r selection || selection="0"

        if [[ "$selection" == "0" ]]; then
            return 1
        fi

        if [[ -z "$selection" ]]; then
            return 0
        elif [[ "$selection" == /* ]]; then
            search_query="${selection#/}"
            continue
        elif [[ "$selection" =~ ^[Pp]$ ]]; then
            [[ "$filter_mode" == "picks" ]] && filter_mode="" || filter_mode="picks"
            continue
        elif [[ "$selection" =~ ^[Hh]$ ]]; then
            [[ "$filter_mode" == "hardware" ]] && filter_mode="" || filter_mode="hardware"
            continue
        elif [[ "$selection" =~ ^[Dd]([0-9]+)$ ]]; then
            detail_num="${BASH_REMATCH[1]}"
            if [[ "$detail_num" -ge 1 && "$detail_num" -le "${#app_ids[@]}" ]]; then
                render_application_detail "${app_ids[$((detail_num - 1))]}"
                echo ""
                printf "Enter para volver: "
                read -r detail_ack || true
            else
                warn "⚠️ Número de detalle inválido"
            fi
            continue
        fi

        # parse_selection's warnings (utils.sh's warn()) print to stdout,
        # the same stream this reads from via process substitution — an
        # unrecognized token (e.g. a stray letter) can otherwise leak its
        # warning text in as a fake "item" and crash the arithmetic below.
        # Validated here rather than in the shared warn()/parse_selection
        # functions, which are used far beyond Deployment.
        while IFS= read -r item; do
            [[ "$item" =~ ^[0-9]+$ ]] || continue
            id="${app_ids[$((item - 1))]}"
            selection_toggle "$id" manual
        done < <(parse_selection "$selection" "${#app_ids[@]}")

    done
}

# =========================
# Application Catalog -> confirmation
# =========================

# start_deployment_flow [PRESET_ID] — PRESET_ID empty means "start empty".
# Every path goes through the exact same catalog and confirmation screens;
# there is no separate preset-execution path. The parameter exists for
# core/bootstrap/wizard.sh's own onboarding question, which still picks a
# preset before calling in — the standalone Deployment entry below always
# calls this with "" (no interactive way to load a preset once inside the
# catalog as of v2.4.1, see ADR-0012).
start_deployment_flow() {

    local preset_id="${1:-}"

    if [[ -n "$preset_id" ]]; then
        load_preset_into_selection "$preset_id"
    else
        reset_selection
    fi

    run_application_catalog || {
        info "ℹ️ Selección cancelada"
        return 0
    }

    if [[ "$(selection_count)" -eq 0 ]]; then
        warn "⚠️ No se seleccionó ninguna aplicación"
        return 0
    fi

    build_plan_from_selection "$preset_id"

    run_plan_confirmation
}

# =========================
# Main deployment menu: a direct forward into the Application Catalog —
# no preset-picker screen first, and (as of v2.4.1) no in-catalog way to
# load one either. JB Picks are, as before, not a separate screen either:
# a JB_PICK=true application is annotated inline wherever it appears in the
# Application Catalog and in the plan's explain view — the same catalog
# flag, surfaced where selection actually happens.
# =========================

run_deployment_menu() {
    start_deployment_flow ""
}
