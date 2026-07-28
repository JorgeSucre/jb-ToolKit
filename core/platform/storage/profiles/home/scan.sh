#!/bin/bash

# =========================
# Storage profile: Home del usuario
# =========================
# Mirrors the console user's Home folders one level deep. Library,
# Applications, Developer, Public, OneDrive, Dropbox, and iCloud Drive are
# never migrated by default; hidden entries (.ssh, .gitconfig, .cache, ...)
# are filtered out at the `find` level and never even reach the candidate
# list, so there is no toggle that can turn them on.

_storage_home_excluded() {

    local name="$1"

    case "$name" in
        Library|Applications|Developer|Public|OneDrive|Dropbox) return 0 ;;
        "iCloud Drive") return 0 ;;
    esac

    return 1
}

storage_profile_home_source_root() {
    resolve_user_home "$(detect_console_user)"
}

storage_profile_home_scan() {

    local root="$1"
    local entry name size_mb excluded

    STORAGE_SCAN_CACHE=""

    while IFS= read -r entry; do

        [[ -z "$entry" ]] && continue

        name="$(basename "$entry")"

        if _storage_home_excluded "$name"; then
            excluded=1
        else
            excluded=0
        fi

        size_mb="$(dir_size_mb "$entry")"
        size_mb="${size_mb:-0}"

        STORAGE_SCAN_CACHE+="$name|$size_mb|$excluded"$'\n'

    done < <(find "$root" -mindepth 1 -maxdepth 1 -type d ! -name ".*" 2>/dev/null | sort)
}
