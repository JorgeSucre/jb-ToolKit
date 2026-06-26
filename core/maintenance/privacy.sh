#!/bin/bash

# =========================
# Privacy / Telemetry Inventory — detection only
# =========================
# Read-only audit of known background services associated with vendor
# update/telemetry/analytics components (Google Keystone, Microsoft
# Office, Adobe, Zoom). This module never disables, removes, or modifies
# anything — it only reports what it finds. A future "offer to disable"
# capability would need the same detect -> report -> confirm -> act
# discipline already documented for manual-app migration in
# core/bootstrap/MIGRATION_FRAMEWORK.md; this file deliberately stops at
# detection + honest reporting.
#
# Detection method: case-insensitive substring match against LaunchAgent/
# LaunchDaemon plist filenames in user and system Library paths (never
# /System/Library, which is Apple's own and out of scope), plus a couple
# of well-known install-folder checks for Keystone. This is the same safe,
# standard way macOS admins inspect background services — filenames and
# directory existence only, no binary plist parsing, no private APIs.
#
# Because plist labels vary by vendor version, a match here is a
# heuristic, not a certainty — every "Detected" result prints the exact
# filename(s) matched so a technician can verify before drawing any
# conclusion. Never assert more precision than the pattern match supports.
#
# Dry Run (v1.1): this module trivially honors the shared DRY_RUN flag
# (core/utils.sh) by construction — it never calls a destructive command
# in the first place, so there is nothing to gate.

PRIVACY_SCAN_DIRS=(
    "$HOME/Library/LaunchAgents"
    "/Library/LaunchAgents"
    "/Library/LaunchDaemons"
)

# Returns the matching plist paths (one per line) for a case-insensitive
# substring across all scan dirs. Empty output = no match anywhere.
privacy_find_launch_items() {

    local pattern="$1"
    local dir

    for dir in "${PRIVACY_SCAN_DIRS[@]}"; do
        [[ -d "$dir" ]] || continue
        find "$dir" -maxdepth 1 -iname "*${pattern}*" 2>/dev/null
    done
}

# =========================
# Per-vendor detection
# =========================

detect_google_keystone() {

    local matches
    matches="$(privacy_find_launch_items "keystone")"

    if [[ -z "$matches" ]]; then
        for dir in "/Library/Google/GoogleSoftwareUpdate" "$HOME/Library/Google/GoogleSoftwareUpdate"; do
            [[ -d "$dir" ]] && matches+="$dir"$'\n'
        done
    fi

    printf "%s" "$matches"
}

detect_microsoft_office_telemetry() {
    privacy_find_launch_items "com.microsoft"
}

detect_adobe_telemetry() {
    privacy_find_launch_items "adobe"
}

detect_zoom_analytics() {
    privacy_find_launch_items "zoom"
}

# =========================
# Reporting (detection only — no action)
# =========================

privacy_report() {

    local label="$1" matches="$2"
    local item

    printf "%s: " "$label"

    if [[ -n "$matches" ]]; then
        echo "Detected"
        while IFS= read -r item; do
            [[ -z "$item" ]] && continue
            printf "   • %s\n" "$(basename "$item")"
        done <<< "$matches"
    else
        echo "Not Detected"
    fi

    echo ""
}

run_privacy_inventory() {

    print_section "🔍 Inventario de privacidad (solo detección)"
    info "ℹ️ Esta revisión es de solo lectura: no se modifica ni desactiva nada"
    echo ""

    privacy_report "Google Keystone" "$(detect_google_keystone)"
    privacy_report "Microsoft Office (actualización/telemetría)" "$(detect_microsoft_office_telemetry)"
    privacy_report "Adobe (telemetría/crash reporting)" "$(detect_adobe_telemetry)"
    privacy_report "Zoom (analítica)" "$(detect_zoom_analytics)"
}

# =========================
# Standalone execution support (outside jb / maintenance.sh)
# =========================
# Not yet wired into core/maintenance.sh's main flow — see
# AGENTS.md §5 for the documented future extension point. Runnable
# directly today for manual review: `bash core/maintenance/privacy.sh`.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    source "$BASE_DIR/core/utils.sh"
    source "$BASE_DIR/core/bootstrap/ui.sh"
    init_session
    set_ui_context "Privacy"
    run_privacy_inventory
fi
