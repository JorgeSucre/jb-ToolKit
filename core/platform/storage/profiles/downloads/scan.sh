#!/bin/bash

# =========================
# Storage profile: Descargas
# =========================
# The simplest possible profile: one folder, no exclusion list. It exists
# mainly as evidence that the engine generalizes past Home without
# duplicating scan/plan/execute/verify/rollback/commit logic — adding this
# profile was two small files with zero engine changes.

storage_profile_downloads_source_root() {
    resolve_user_home "$(detect_console_user)"
}

storage_profile_downloads_scan() {

    local root="$1"
    local size_mb

    STORAGE_SCAN_CACHE=""

    [[ -d "$root/Downloads" ]] || return 0

    size_mb="$(dir_size_mb "$root/Downloads")"
    STORAGE_SCAN_CACHE="Downloads|${size_mb:-0}|0"$'\n'
}
