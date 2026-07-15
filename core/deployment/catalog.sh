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
    local field brew cask value arch
    conf="$(app_conf_path "$id")"

    _valid_id "$id" \
        || catalog_error "V1: $ref — ID de directorio inválido (kebab-case requerido)"

    [[ "$(app_field "$id" ID)" == "$id" ]] \
        || catalog_error "V1: $ref — el campo ID no coincide con el directorio"

    for field in NAME DESCRIPTION; do
        [[ -n "$(app_field "$id" "$field")" ]] \
            || catalog_error "V2: $ref — falta el campo requerido $field"
    done

    brew="$(app_field "$id" BREW)"
    cask="$(app_field "$id" CASK)"
    if [[ -n "$brew" && -n "$cask" ]]; then
        catalog_error "V3: $ref — BREW y CASK son mutuamente excluyentes"
    elif [[ -z "$brew" && -z "$cask" ]]; then
        catalog_error "V3: $ref — se requiere exactamente uno de BREW o CASK"
    fi

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

# V8 (global): a Homebrew package name may exist in exactly one app.conf
validate_package_uniqueness() {
    local dup

    while IFS= read -r dup; do
        [[ -z "$dup" ]] && continue
        catalog_error "V8: el paquete '$dup' está definido en más de una aplicación"
    done < <(
        grep -hE '^(BREW|CASK)=' "$CATALOG_DIR"/applications/*/app.conf 2>/dev/null \
            | sort | uniq -d
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
