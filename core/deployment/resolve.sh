#!/bin/bash

# =========================
# Deployment resolution
# =========================
# Bundles → application IDs with provenance → compatibility-filtered set.
# Resolution semantics per docs/Catalog-Format.md: bundles in the given
# order, applications in bundle line order, first occurrence wins on
# duplicates. Every filtered application is recorded with its reason —
# silent skips are a contract violation.

RESOLVED_APPS=""      # "id|bundle" — compatible apps, install order
RESOLVED_SKIPPED=""   # "id|bundle|reason"

# =========================
# Bundle expansion
# =========================

# resolve_apps_for_bundles BUNDLES(newline-separated IDs)
# Emits "app|source-bundle" lines; first occurrence wins on duplicates.
resolve_apps_for_bundles() {
    local bundles="$1"
    local bundle app list=""

    while IFS= read -r bundle; do
        [[ -z "$bundle" ]] && continue

        while IFS= read -r app; do
            [[ -z "$app" ]] && continue

            if ! grep -q "^$app|" <<< "$list"; then
                list+="$app|$bundle"$'\n'
            fi

        done < <(bundle_apps "$bundle")

    done <<< "$bundles"

    printf "%s" "$list"
}

# =========================
# Compatibility filter
# =========================

macos_major_version() {
    sw_vers -productVersion 2>/dev/null | cut -d. -f1
}

# Prints the Spanish skip reason and returns 1 when incompatible;
# prints nothing and returns 0 when the app can be installed here.
app_incompatibility_reason() {
    local id="$1"
    local archs min arch major

    archs="$(app_field "$id" ARCHS)"
    if [[ -n "$archs" ]]; then
        arch="$(uname -m)"
        if [[ " $archs " != *" $arch "* ]]; then
            printf "no compatible con %s\n" "$arch"
            return 1
        fi
    fi

    min="$(app_field "$id" MIN_MACOS)"
    if [[ -n "$min" ]]; then
        major="$(macos_major_version)"
        if [[ -n "$major" && "$major" -lt "$min" ]]; then
            printf "requiere macOS %s+\n" "$min"
            return 1
        fi
    fi

    return 0
}

# =========================
# Install set
# =========================

# resolve_install_set_for_bundles BUNDLES(newline-separated IDs)
# Populates RESOLVED_APPS and RESOLVED_SKIPPED.
resolve_install_set_for_bundles() {
    local bundles="$1"
    local record app reason

    RESOLVED_APPS=""
    RESOLVED_SKIPPED=""

    while IFS= read -r record; do
        [[ -z "$record" ]] && continue

        app="${record%%|*}"

        if reason="$(app_incompatibility_reason "$app")"; then
            RESOLVED_APPS+="$record"$'\n'
        else
            RESOLVED_SKIPPED+="$record|$reason"$'\n'
        fi

    done < <(resolve_apps_for_bundles "$bundles")
}
