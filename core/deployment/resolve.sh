#!/bin/bash

# =========================
# Deployment resolution
# =========================
# Profile → bundles → application IDs → compatibility-filtered install set.
# Resolution semantics per docs/Catalog-Format.md: bundles in BUNDLES order,
# applications in bundle line order, first occurrence wins on duplicates.
# Every filtered application is recorded with its reason — silent skips are
# a contract violation.

RESOLVED_APPS=""      # compatible app IDs, one per line
RESOLVED_SKIPPED=""   # "id|reason" per line

# =========================
# Profile expansion
# =========================

# Ordered, deduplicated application IDs for a profile (no filtering)
resolve_profile_apps() {
    local profile="$1"
    local bundle app list=""

    while IFS= read -r bundle; do
        [[ -z "$bundle" ]] && continue

        while IFS= read -r app; do
            [[ -z "$app" ]] && continue

            if ! grep -qx "$app" <<< "$list"; then
                list+="$app"$'\n'
            fi

        done < <(bundle_apps "$bundle")

    done < <(profile_bundles "$profile")

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

# Populates RESOLVED_APPS and RESOLVED_SKIPPED for a profile
resolve_install_set() {
    local profile="$1"
    local app reason

    RESOLVED_APPS=""
    RESOLVED_SKIPPED=""

    while IFS= read -r app; do
        [[ -z "$app" ]] && continue

        if reason="$(app_incompatibility_reason "$app")"; then
            RESOLVED_APPS+="$app"$'\n'
        else
            RESOLVED_SKIPPED+="$app|$reason"$'\n'
        fi

    done < <(resolve_profile_apps "$profile")
}
