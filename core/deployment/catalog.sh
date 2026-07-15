#!/bin/bash

# =========================
# Deployment catalog loader
# =========================
# Implements the data contracts in docs/Catalog-Format.md.
# On any disagreement, the contract document wins and this file is the bug.
#
# Accessors are tolerant (missing file/key → empty output, exit 0) so callers
# under `set -e` stay safe; existence is checked explicitly via *_exists.
# Validation is strict: validate_catalog reports every violation by rule
# number and file, and returns non-zero if the catalog is unusable.

CATALOG_DIR="${JB_CATALOG_DIR:-$BASE_DIR/catalog}"

CATALOG_ERRORS=0

# =========================
# Paths and existence
# =========================

app_conf_path() { printf "%s\n" "$CATALOG_DIR/applications/$1/app.conf"; }
bundle_path()   { printf "%s\n" "$CATALOG_DIR/bundles/$1.bundle"; }
profile_path()  { printf "%s\n" "$CATALOG_DIR/profiles/$1.profile"; }

app_exists()     { [[ -f "$CATALOG_DIR/applications/$1/app.conf" ]]; }
bundle_exists()  { [[ -f "$CATALOG_DIR/bundles/$1.bundle" ]]; }
profile_exists() { [[ -f "$CATALOG_DIR/profiles/$1.profile" ]]; }

# =========================
# Field access
# =========================

# catalog_field FILE KEY — first '=' splits; missing file/key → empty, exit 0
catalog_field() {
    local file="$1" key="$2"

    [[ -f "$file" ]] || return 0

    awk -F= -v key="$key" \
        '$1 == key {print substr($0, length(key) + 2); exit}' \
        "$file"
}

app_field()     { catalog_field "$(app_conf_path "$1")" "$2"; }
profile_field() { catalog_field "$(profile_path "$1")" "$2"; }

# =========================
# Listing
# =========================

list_applications() {
    local dir

    for dir in "$CATALOG_DIR/applications"/*/; do
        [[ -f "${dir}app.conf" ]] || continue
        basename "$dir"
    done
}

list_bundles() {
    local file

    for file in "$CATALOG_DIR/bundles"/*.bundle; do
        [[ -f "$file" ]] || continue
        basename "$file" .bundle
    done
}

list_profiles() {
    local file

    for file in "$CATALOG_DIR/profiles"/*.profile; do
        [[ -f "$file" ]] || continue
        basename "$file" .profile
    done
}

# =========================
# Bundle access
# =========================

# First comment line is the display name (contract V10)
bundle_display_name() {
    local file
    file="$(bundle_path "$1")"

    [[ -f "$file" ]] || return 0

    sed -n '1s/^# *//p' "$file"
}

# Application IDs, one per line, comments and blanks stripped
bundle_apps() {
    local file
    file="$(bundle_path "$1")"

    [[ -f "$file" ]] || return 0

    grep -Ev '^#|^[[:space:]]*$' "$file" || true
}

# =========================
# Profile access
# =========================

# Bundle IDs referenced by a profile, one per line, order preserved
profile_bundles() {
    local bundles
    bundles="$(profile_field "$1" BUNDLES)"

    [[ -n "$bundles" ]] || return 0

    tr ' ' '\n' <<< "$bundles" | sed '/^$/d'
}

# =========================
# Hierarchy queries (menu-generation contract, docs/Catalog-Format.md)
# =========================

_profile_order() {
    local order
    order="$(profile_field "$1" ORDER)"
    [[ "$order" =~ ^[0-9]+$ ]] || order=50
    printf "%03d\n" "$order"
}

# Distinct CATEGORY values ordered by the minimum ORDER among their profiles
list_categories() {
    local id

    for id in $(list_profiles); do
        printf "%s|%s\n" "$(_profile_order "$id")" "$(profile_field "$id" CATEGORY)"
    done | sort -t'|' -k1,1n -k2,2 | awk -F'|' '!seen[$2]++ {print $2}'
}

# Profile IDs within a category, ordered by ORDER (ties alphabetical)
profiles_in_category() {
    local category="$1" id

    for id in $(list_profiles); do
        [[ "$(profile_field "$id" CATEGORY)" == "$category" ]] || continue
        printf "%s|%s\n" "$(_profile_order "$id")" "$id"
    done | sort -t'|' -k1,1n -k2,2 | cut -d'|' -f2
}

# Collapse rule: prints the profile ID when the category resolves directly
# (exactly one profile, no SUBCATEGORY); prints nothing otherwise
category_direct_profile() {
    local ids count

    ids="$(profiles_in_category "$1")"
    count=$(printf "%s\n" "$ids" | sed '/^$/d' | wc -l | tr -d ' ')

    [[ "$count" -eq 1 ]] || return 0
    [[ -z "$(profile_field "$ids" SUBCATEGORY)" ]] || return 0

    printf "%s\n" "$ids"
}

# Application IDs marked JB_PICK=true
list_jb_picks() {
    local id

    for id in $(list_applications); do
        [[ "$(app_field "$id" JB_PICK)" == "true" ]] && printf "%s\n" "$id"
    done

    return 0
}

# Application IDs whose HW_RECOMMEND matches this machine.
# apps_recommended_for_hardware FAMILY HAS_EXTERNAL_DISPLAY(0|1)
# A tag matches when it equals FAMILY, or when it is "external_display"
# and an external display is present.
apps_recommended_for_hardware() {
    local family="$1" has_external="${2:-0}"
    local id tags tag

    for id in $(list_applications); do
        tags="$(app_field "$id" HW_RECOMMEND)"
        [[ -z "$tags" ]] && continue

        for tag in $tags; do
            if [[ "$tag" == "$family" ]] \
                || [[ "$tag" == "external_display" && "$has_external" -eq 1 ]]; then
                printf "%s\n" "$id"
                break
            fi
        done
    done

    return 0
}

# =========================
# Validation (rules V1–V10, docs/Catalog-Format.md)
# =========================

catalog_error() {
    CATALOG_ERRORS=$((CATALOG_ERRORS + 1))
    error_msg "❌ $1"
}

_valid_id() {
    [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]]
}

# _flag_line FILE KEY — prints the raw value iff the key line is present
# (distinguishes "absent" from "present with wrong value" for V4/V6)
_flag_line() {
    local line
    line="$(grep -m1 "^$2=" "$1" || true)"
    [[ -n "$line" ]] && printf "%s\n" "${line#"$2"=}"
}

validate_application() {
    local id="$1"
    local conf ref="applications/$id/app.conf"
    local field method value arch tag
    conf="$(app_conf_path "$id")"

    _valid_id "$id" \
        || catalog_error "V1: $ref — ID de directorio inválido (kebab-case requerido)"

    [[ "$(app_field "$id" ID)" == "$id" ]] \
        || catalog_error "V1: $ref — el campo ID no coincide con el directorio"

    for field in NAME DESCRIPTION; do
        [[ -n "$(app_field "$id" "$field")" ]] \
            || catalog_error "V2: $ref — falta el campo requerido $field"
    done

    method="$(app_field "$id" INSTALL_METHOD)"
    case "$method" in
        brew|cask|mas)
            [[ -n "$(app_field "$id" PACKAGE)" ]] \
                || catalog_error "V3: $ref — INSTALL_METHOD=$method requiere PACKAGE"
            ;;
        pkg|dmg|manual)
            [[ -n "$(app_field "$id" DOWNLOAD_URL)" ]] \
                || catalog_error "V3: $ref — INSTALL_METHOD=$method requiere DOWNLOAD_URL"
            ;;
        "")
            catalog_error "V3: $ref — falta INSTALL_METHOD (brew|cask|mas|pkg|dmg|manual)"
            ;;
        *)
            catalog_error "V3: $ref — INSTALL_METHOD desconocido: '$method'"
            ;;
    esac

    # Legacy keys from the v2.0.0 contract — silent no-ops if left behind
    for field in BREW CASK; do
        [[ -n "$(_flag_line "$conf" "$field")" ]] \
            && catalog_error "V3: $ref — la clave $field ya no existe; usa INSTALL_METHOD y PACKAGE"
    done

    for field in JB_PICK RECOMMENDED; do
        value="$(_flag_line "$conf" "$field")"
        if [[ -n "$value" && "$value" != "true" ]]; then
            catalog_error "V4: $ref — $field debe ser 'true' o estar ausente"
        fi
    done

    if [[ "$(app_field "$id" JB_PICK)" == "true" ]]; then
        [[ -n "$(app_field "$id" JB_PICK_NOTE)" ]] \
            || catalog_error "V5: $ref — JB_PICK=true requiere JB_PICK_NOTE (una recomendación sin justificación es inválida)"
    fi

    for arch in $(app_field "$id" ARCHS); do
        case "$arch" in
            arm64|x86_64) ;;
            *) catalog_error "V6: $ref — arquitectura desconocida en ARCHS: '$arch'" ;;
        esac
    done

    value="$(_flag_line "$conf" MIN_MACOS)"
    if [[ -n "$value" && ! "$value" =~ ^[0-9]+$ ]]; then
        catalog_error "V6: $ref — MIN_MACOS debe ser un entero"
    fi

    for tag in $(app_field "$id" HW_RECOMMEND); do
        case "$tag" in
            macbook_air|macbook_pro|mac_mini|mac_studio|imac|external_display) ;;
            *) catalog_error "V6: $ref — familia desconocida en HW_RECOMMEND: '$tag'" ;;
        esac
    done
}

validate_bundle() {
    local id="$1"
    local file ref="bundles/$id.bundle"
    local app seen=""
    file="$(bundle_path "$id")"

    _valid_id "$id" \
        || catalog_error "V1: $ref — ID de bundle inválido (kebab-case requerido)"

    head -1 "$file" | grep -q '^# .' \
        || catalog_error "V10: $ref — la primera línea debe ser el nombre visible ('# Nombre')"

    while IFS= read -r app; do
        [[ -z "$app" ]] && continue

        app_exists "$app" \
            || catalog_error "V7: $ref — referencia una aplicación inexistente: '$app'"

        if grep -qx "$app" <<< "$seen"; then
            catalog_error "V8: $ref — aplicación duplicada dentro del bundle: '$app'"
        fi
        seen+="$app"$'\n'

    done < <(bundle_apps "$id")
}

validate_profile() {
    local id="$1"
    local file ref="profiles/$id.profile"
    local field value bundle
    file="$(profile_path "$id")"

    _valid_id "$id" \
        || catalog_error "V1: $ref — ID de perfil inválido (kebab-case requerido)"

    for field in NAME DESCRIPTION CATEGORY BUNDLES; do
        [[ -n "$(profile_field "$id" "$field")" ]] \
            || catalog_error "V2: $ref — falta el campo requerido $field"
    done

    value="$(_flag_line "$file" ORDER)"
    if [[ -n "$value" && ! "$value" =~ ^[0-9]+$ ]]; then
        catalog_error "V6: $ref — ORDER debe ser un entero"
    fi

    while IFS= read -r bundle; do
        [[ -z "$bundle" ]] && continue
        bundle_exists "$bundle" \
            || catalog_error "V9: $ref — referencia un bundle inexistente: '$bundle'"
    done < <(profile_bundles "$id")
}

# V8 (global): a package identifier may exist in exactly one app.conf
# (per method — the brew, cask, and mas namespaces are independent)
validate_package_uniqueness() {
    local id dup pkg

    while IFS= read -r dup; do
        [[ -z "$dup" ]] && continue
        catalog_error "V8: el paquete '$dup' está definido en más de una aplicación"
    done < <(
        for id in $(list_applications); do
            pkg="$(app_field "$id" PACKAGE)"
            [[ -n "$pkg" ]] && printf "%s:%s\n" "$(app_field "$id" INSTALL_METHOD)" "$pkg"
        done | sort | uniq -d
    )
}

validate_catalog() {
    local id app_count=0 bundle_count=0 profile_count=0

    CATALOG_ERRORS=0

    print_section "🧪 Validación del catálogo"

    if [[ ! -d "$CATALOG_DIR" ]]; then
        catalog_error "No existe el directorio del catálogo: $CATALOG_DIR"
        return 1
    fi

    for id in $(list_applications); do
        validate_application "$id"
        app_count=$((app_count + 1))
    done

    for id in $(list_bundles); do
        validate_bundle "$id"
        bundle_count=$((bundle_count + 1))
    done

    for id in $(list_profiles); do
        validate_profile "$id"
        profile_count=$((profile_count + 1))
    done

    validate_package_uniqueness

    echo ""

    if [[ "$CATALOG_ERRORS" -gt 0 ]]; then
        error_msg "❌ Catálogo inválido: $CATALOG_ERRORS errores"
        return 1
    fi

    success "✔ Catálogo válido: $app_count aplicaciones, $bundle_count bundles, $profile_count perfiles"
}
