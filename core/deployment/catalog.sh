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
#
# Two layers only — applications and presets. See
# docs/architecture/0006-deployment-flattening.md for why there is no
# intermediate bundle/profile grouping, and
# docs/architecture/0007-catalog-consistency.md for why applications own
# exactly one category and presets live in a single file.

CATALOG_DIR="${JB_CATALOG_DIR:-$BASE_DIR/catalog}"
PRESETS_FILE="$CATALOG_DIR/presets.conf"

# The only values CATEGORY may take. Adding one is a deliberate taxonomy
# decision (see the ADR) — not something a new app.conf should introduce on
# its own, which is why the validator (V6) rejects anything outside this set.
CATALOG_CATEGORIES="browsers communication creative development hardware networking productivity utilities"

CATALOG_ERRORS=0

# =========================
# Paths and existence
# =========================

app_conf_path()  { printf "%s\n" "$CATALOG_DIR/applications/$1/app.conf"; }
app_exists()     { [[ -f "$CATALOG_DIR/applications/$1/app.conf" ]]; }

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

app_field()    { catalog_field "$(app_conf_path "$1")" "$2"; }

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

# =========================
# Preset access — catalog/presets.conf, one file, one [id] section per
# preset. Sections stay flat KEY=value, same awk-parseable convention as
# every other catalog file — no YAML/JSON parser, no new dependency. See
# docs/architecture/0007-catalog-consistency.md.
# =========================

# Lines belonging to preset ID's [id] section, in file order
_preset_block() {
    local id="$1"

    [[ -f "$PRESETS_FILE" ]] || return 0

    awk -v section="[$id]" '
        $0 == section { found=1; next }
        /^\[/ { found=0 }
        found { print }
    ' "$PRESETS_FILE"
}

preset_exists() {
    [[ -f "$PRESETS_FILE" ]] && grep -qx "\[$1\]" "$PRESETS_FILE"
}

preset_field() {
    local id="$1" key="$2"

    _preset_block "$id" | awk -F= -v key="$key" \
        '$1 == key {print substr($0, length(key) + 2); exit}'
}

# _preset_flag_line ID KEY — raw value iff KEY's line is present within ID's
# own section. Scoped to the block (not the whole file) so it can never pick
# up a same-named key from a different preset lower in presets.conf. Always
# exits 0 — an absent key is a normal outcome for this accessor, not a
# failure, same tolerant contract as catalog_field/preset_field.
_preset_flag_line() {
    local id="$1" key="$2" line
    line="$(_preset_block "$id" | grep -m1 "^$key=" || true)"
    [[ -n "$line" ]] && printf "%s\n" "${line#"$key"=}"
    return 0
}

# Preset IDs, one per line, in file order. Only well-formed (kebab-case)
# section headers — a malformed one (typo, stray capital, a space) must
# still be caught by the validator, not silently absent from every listing
# as if it never existed. validate_catalog iterates
# _preset_section_headers_raw() instead, specifically to catch that case.
list_presets() {
    [[ -f "$PRESETS_FILE" ]] || return 0
    grep -o '^\[[a-z0-9][a-z0-9-]*\]$' "$PRESETS_FILE" | sed 's/^\[//; s/\]$//'
}

# Every [section] header exactly as written, malformed ones included —
# validation-only. Functional code (menus, doctor) must keep using
# list_presets(); this exists so an invalid header is reported (V1) instead
# of just never appearing anywhere.
_preset_section_headers_raw() {
    [[ -f "$PRESETS_FILE" ]] || return 0
    grep -o '^\[[^]]*\]$' "$PRESETS_FILE" | sed 's/^\[//; s/\]$//'
}

_preset_order() {
    local order
    order="$(preset_field "$1" ORDER)"
    [[ "$order" =~ ^[0-9]+$ ]] || order=50
    printf "%03d\n" "$order"
}

# Application IDs a preset predefines, one per line, order preserved.
# This is the ENTIRE preset — no nested references, no groups.
preset_apps() {
    local apps
    apps="$(preset_field "$1" APPS)"

    [[ -n "$apps" ]] || return 0

    tr ' ' '\n' <<< "$apps" | sed '/^$/d'
}

# Preset IDs ordered by ORDER (ties alphabetical) — the flat Quick Presets list
list_presets_ordered() {
    local id

    for id in $(list_presets); do
        printf "%s|%s\n" "$(_preset_order "$id")" "$id"
    done | sort -t'|' -k1,1n -k2,2 | cut -d'|' -f2
}

# =========================
# Application category queries (Application Catalog browser)
# =========================
# CATEGORY is presentational only and single-valued: every application
# belongs to exactly one category, so it appears in exactly one section with
# exactly one selection number — never duplicated, never split across
# sections. See docs/architecture/0007-catalog-consistency.md.

# Distinct CATEGORY values across all applications, alphabetical
list_app_categories() {
    local id

    for id in $(list_applications); do
        app_field "$id" CATEGORY
    done | sort -u
}

# Application IDs whose CATEGORY is CATEGORY, ordered by NAME
apps_in_category() {
    local category="$1" id name

    for id in $(list_applications); do
        [[ "$(app_field "$id" CATEGORY)" == "$category" ]] || continue
        name="$(app_field "$id" NAME)"
        printf "%s|%s\n" "$name" "$id"
    done | sort -t'|' -k1,1 | cut -d'|' -f2
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
# Validation (rules V1–V9, docs/Catalog-Format.md)
# =========================

catalog_error() {
    CATALOG_ERRORS=$((CATALOG_ERRORS + 1))
    error_msg "❌ $1"
}

# _duplicate_keys BLOCK_TEXT — KEY names appearing on more than one line.
# catalog_field/preset_field take the FIRST match and never mention the
# rest, so a duplicate key is otherwise a silent, invisible inconsistency —
# the second value is just discarded with no error and no trace (V9).
_duplicate_keys() {
    awk -F= '/^[A-Za-z_][A-Za-z0-9_]*=/ {print $1}' <<< "$1" | sort | uniq -d
}

_valid_id() {
    [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]]
}

# _flag_line FILE KEY — prints the raw value iff the key line is present
# (distinguishes "absent" from "present with wrong value" for V4/V6). Always
# exits 0 — an absent key is a normal outcome for this accessor, not a
# failure, same tolerant contract as catalog_field/preset_field. Every real
# validate_catalog call site wraps it in `if`, which already shields errexit
# from an inner command substitution's exit code — but the accessor should
# not rely on that at every call site to stay set -e-safe.
_flag_line() {
    local line
    line="$(grep -m1 "^$2=" "$1" || true)"
    [[ -n "$line" ]] && printf "%s\n" "${line#"$2"=}"
    return 0
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

    value="$(_flag_line "$conf" JB_PICK)"
    if [[ -n "$value" && "$value" != "true" ]]; then
        catalog_error "V4: $ref — JB_PICK debe ser 'true' o estar ausente"
    fi

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

    value="$(app_field "$id" CATEGORY)"
    if [[ -z "$value" ]]; then
        catalog_error "V2: $ref — falta el campo requerido CATEGORY"
    elif ! grep -qw "$value" <<< "$CATALOG_CATEGORIES"; then
        catalog_error "V6: $ref — categoría desconocida en CATEGORY: '$value'"
    fi

    while IFS= read -r field; do
        [[ -z "$field" ]] && continue
        catalog_error "V9: $ref — clave duplicada: '$field' (solo se usa la primera aparición, el resto se descarta en silencio)"
    done < <(_duplicate_keys "$(cat "$conf" 2>/dev/null)")
}

validate_preset() {
    local id="$1"
    local ref="presets.conf#[$id]"
    local field value app seen=""

    _valid_id "$id" \
        || catalog_error "V1: $ref — ID de preset inválido (kebab-case requerido)"

    for field in NAME DESCRIPTION APPS; do
        [[ -n "$(preset_field "$id" "$field")" ]] \
            || catalog_error "V2: $ref — falta el campo requerido $field"
    done

    value="$(_preset_flag_line "$id" ORDER)"
    if [[ -n "$value" && ! "$value" =~ ^[0-9]+$ ]]; then
        catalog_error "V6: $ref — ORDER debe ser un entero"
    fi

    while IFS= read -r app; do
        [[ -z "$app" ]] && continue

        app_exists "$app" \
            || catalog_error "V7: $ref — referencia una aplicación inexistente: '$app'"

        if grep -qx "$app" <<< "$seen"; then
            catalog_error "V8: $ref — aplicación duplicada dentro del preset: '$app'"
        fi
        seen+="$app"$'\n'

    done < <(preset_apps "$id")

    while IFS= read -r field; do
        [[ -z "$field" ]] && continue
        catalog_error "V9: $ref — clave duplicada: '$field' (solo se usa la primera aparición, el resto se descarta en silencio)"
    done < <(_duplicate_keys "$(_preset_block "$id")")
}

# V8 (global): no duplicate [id] section within presets.conf. One file, one
# grep-able source of truth per preset id — the filesystem no longer
# enforces this by construction the way one-file-per-preset did.
validate_preset_uniqueness() {
    local dup

    [[ -f "$PRESETS_FILE" ]] || return 0

    while IFS= read -r dup; do
        [[ -z "$dup" ]] && continue
        catalog_error "V8: presets.conf — sección de preset duplicada: '[$dup]'"
    done < <(_preset_section_headers_raw | sort | uniq -d)
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
    local id app_count=0 preset_count=0

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

    # Every raw [section] header, not list_presets() — a malformed header
    # (invalid kebab-case, possibly containing spaces) must be validated and
    # reported (V1), not silently excluded from the count as if it didn't
    # exist. while-read, not for-in: a malformed header can contain spaces,
    # which word-splitting would fracture into several fake IDs.
    while IFS= read -r id; do
        [[ -z "$id" ]] && continue
        validate_preset "$id"
        preset_count=$((preset_count + 1))
    done < <(_preset_section_headers_raw)

    validate_preset_uniqueness
    validate_package_uniqueness

    echo ""

    if [[ "$CATALOG_ERRORS" -gt 0 ]]; then
        error_msg "❌ Catálogo inválido: $CATALOG_ERRORS errores"
        return 1
    fi

    success "✔ Catálogo válido: $app_count aplicaciones, $preset_count presets"
}
