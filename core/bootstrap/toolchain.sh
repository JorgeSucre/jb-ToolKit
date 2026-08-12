#!/bin/bash

# =========================
# macOS toolchain compatibility
# =========================
# Resolves which macOS/Xcode/CLT/Homebrew situation this machine is in
# before Bootstrap touches Homebrew, using core/bootstrap/toolchain-matrix.conf
# as the single source of truth — no per-version if/elif ladder here or in
# bootstrap.sh. Adding a new macOS release means adding a row to that file,
# never editing this one.
#
# Pure decision logic (resolve_toolchain_section, resolve_toolchain_strategy,
# _version_ge, _is_full_xcode_path, validate_capability) takes its inputs as
# arguments and makes no system calls, so it's directly testable with literal
# strings — see toolchain_test.sh. Detection (macos_full_version,
# detect_xcode_clt) is the thin, untestable-without-a-real-Mac layer that
# feeds it.

TOOLCHAIN_MATRIX_FILE="${JB_TOOLCHAIN_MATRIX:-$BASE_DIR/core/bootstrap/toolchain-matrix.conf}"

# =========================
# Matrix parsing — same awk-based [section]/KEY=value reader as
# catalog.sh's _preset_block/preset_field (docs/Catalog-Format.md); no new
# dependency, no YAML/JSON.
# =========================

_toolchain_block() {
    local section="$1"

    [[ -f "$TOOLCHAIN_MATRIX_FILE" ]] || return 0

    awk -v section="[$section]" '
        $0 == section { found=1; next }
        /^\[/ { found=0 }
        found { print }
    ' "$TOOLCHAIN_MATRIX_FILE"
}

toolchain_field() {
    local section="$1" key="$2"

    _toolchain_block "$section" | awk -F= -v key="$key" \
        '$1 == key {print substr($0, length(key) + 2); exit}'
}

_toolchain_sections() {
    [[ -f "$TOOLCHAIN_MATRIX_FILE" ]] || return 0
    grep -oE '^\[[^]]+\]' "$TOOLCHAIN_MATRIX_FILE" | tr -d '[]'
}

# =========================
# Version comparison — dotted-numeric, Bash 3.2 safe (no associative
# arrays, no ${var,,}). Missing components compare as 0.
# =========================

# _version_ge V1 V2 — true iff V1 >= V2
_version_ge() {
    local v1="$1" v2="$2"
    local -a a1 a2
    local i max n1 n2

    IFS='.' read -r -a a1 <<< "$v1"
    IFS='.' read -r -a a2 <<< "$v2"

    max="${#a1[@]}"
    [[ "${#a2[@]}" -gt "$max" ]] && max="${#a2[@]}"

    for ((i = 0; i < max; i++)); do
        n1="${a1[i]:-0}"
        n2="${a2[i]:-0}"
        [[ "$n1" =~ ^[0-9]+$ ]] || n1=0
        [[ "$n2" =~ ^[0-9]+$ ]] || n2=0

        (( 10#$n1 > 10#$n2 )) && return 0
        (( 10#$n1 < 10#$n2 )) && return 1
    done

    return 0
}

# =========================
# Patch-band lookup — pure function, no system calls. FULL is the complete
# detected macOS version ("14.6"), MAJOR is its leading integer ("14"),
# both passed in rather than read from a global so this is directly
# testable with literal strings.
# =========================

# resolve_toolchain_section FULL MAJOR — prints the matrix section name
# that applies (a real "[floor]" row, DEFAULT_NEWER, or DEFAULT_OLDER), or
# the synthetic marker BELOW_FLOOR when MAJOR has rows in the matrix but
# every one of their PATCH_FLOOR values is above FULL.
resolve_toolchain_section() {
    local full="$1" major="$2"
    local section family floor
    local best="" best_floor="" family_has_rows=0
    local lowest_family="" highest_family=""

    for section in $(_toolchain_sections); do
        [[ "$section" == DEFAULT_* ]] && continue

        family="$(toolchain_field "$section" FAMILY)"
        [[ -n "$family" ]] || continue

        if [[ -z "$lowest_family" ]] || (( family < lowest_family )); then
            lowest_family="$family"
        fi
        if [[ -z "$highest_family" ]] || (( family > highest_family )); then
            highest_family="$family"
        fi

        [[ "$family" == "$major" ]] || continue
        family_has_rows=1

        floor="$(toolchain_field "$section" PATCH_FLOOR)"
        [[ -n "$floor" ]] || continue

        if _version_ge "$full" "$floor"; then
            if [[ -z "$best_floor" ]] || _version_ge "$floor" "$best_floor"; then
                best="$section"
                best_floor="$floor"
            fi
        fi
    done

    if [[ -n "$best" ]]; then
        printf "%s\n" "$best"
        return 0
    fi

    if (( family_has_rows )); then
        printf "BELOW_FLOOR\n"
        return 0
    fi

    if [[ -n "$highest_family" ]] && (( major > highest_family )); then
        printf "DEFAULT_NEWER\n"
    elif [[ -n "$lowest_family" ]] && (( major < lowest_family )); then
        printf "DEFAULT_OLDER\n"
    else
        # A numeric gap inside the matrix's own known range with no exact
        # family match — not reachable with the shipped matrix (12/13/14
        # are consecutive), but fail open rather than fail closed if a
        # future edit ever creates one.
        printf "DEFAULT_NEWER\n"
    fi
}

# resolve_toolchain_strategy FULL MAJOR — prints the effective
# TOOLKIT_STRATEGY for the row resolve_toolchain_section returns.
# BELOW_FLOOR (not a real matrix row) always resolves to "stop" directly,
# per the design's lookup-behavior step 5. Pure convenience wrapper for
# callers (e.g. the test suite) that only need the strategy string —
# prepare_toolchain below calls resolve_toolchain_section directly instead,
# since it also needs the matched row itself, and a global set from inside
# a function invoked via "$(...)" would never survive the command
# substitution's subshell back to the caller.
resolve_toolchain_strategy() {
    local full="$1" major="$2" row

    row="$(resolve_toolchain_section "$full" "$major")"

    if [[ "$row" == "BELOW_FLOOR" ]]; then
        printf "stop\n"
        return 0
    fi

    toolchain_field "$row" TOOLKIT_STRATEGY
}

# =========================
# Capability profiles — what the bootstrap actually needs, expressed as a
# named, behaviorally-validated profile rather than a version number. Adding
# full_xcode_required later is one more case branch here, not a bootstrap
# redesign; no current row uses it and none should be added speculatively.
# =========================

_capability_profile_commands() {
    case "$1" in
        standard_clt) printf "clang\ngit\n" ;;
    esac
}

# validate_capability COMMANDS — COMMANDS is one command name per line.
# Each must both exist AND run "<cmd> --version" successfully; command
# existence alone is not treated as sufficient. Pure function over its
# argument — safe to call with synthetic command names in tests.
validate_capability() {
    local commands="$1" cmd

    while IFS= read -r cmd; do
        [[ -z "$cmd" ]] && continue
        command -v "$cmd" >/dev/null 2>&1 || return 1
        "$cmd" --version >/dev/null 2>&1 || return 1
    done <<< "$commands"

    return 0
}

# validate_capability_profile PROFILE — the real entry point the bootstrap
# flow uses. An unrecognized profile fails closed rather than silently
# passing.
validate_capability_profile() {
    local profile="$1" commands

    commands="$(_capability_profile_commands "$profile")"
    [[ -n "$commands" ]] || return 1

    validate_capability "$commands"
}

# =========================
# Detection — the thin layer that calls real system commands. Everything
# above this point is pure and takes its inputs as arguments; everything
# below populates globals from the live machine.
# =========================

# macos_full_version — full dotted productVersion ("14.6"). Pairs with
# selection.sh's existing macos_major_version() (the leading-integer form
# already used for catalog MIN_MACOS compatibility) rather than duplicating
# a second macOS-version detector.
macos_full_version() {
    sw_vers -productVersion 2>/dev/null
}

# _is_full_xcode_path PATH — true iff PATH (an xcode-select -p result)
# points inside Xcode.app rather than the standalone CLT directory. Split
# out from detect_xcode_clt so the classification itself is testable with
# literal strings, with no xcode-select call involved.
_is_full_xcode_path() {
    [[ "$1" == *"/Xcode.app/"* ]]
}

TOOLCHAIN_XCODE_PATH=""
TOOLCHAIN_HAS_FULL_XCODE=0
TOOLCHAIN_XCODE_VERSION=""
TOOLCHAIN_CLT_VERSION=""

# detect_xcode_clt — populates the TOOLCHAIN_* globals above from the real
# machine. xcode-select -p alone only proves *something* is installed, not
# that it's the right version, so this also reads the CLT package's own
# version metadata (pkgutil), and xcodebuild -version when full Xcode is
# the active developer directory.
detect_xcode_clt() {
    TOOLCHAIN_XCODE_PATH=""
    TOOLCHAIN_HAS_FULL_XCODE=0
    TOOLCHAIN_XCODE_VERSION=""
    TOOLCHAIN_CLT_VERSION=""

    TOOLCHAIN_XCODE_PATH="$(xcode-select -p 2>/dev/null || true)"

    if _is_full_xcode_path "$TOOLCHAIN_XCODE_PATH"; then
        TOOLCHAIN_HAS_FULL_XCODE=1
        TOOLCHAIN_XCODE_VERSION="$(xcodebuild -version 2>/dev/null | awk 'NR==1{print $2}')"
    fi

    TOOLCHAIN_CLT_VERSION="$(pkgutil --pkg-info=com.apple.pkg.CLTools_Executables 2>/dev/null \
        | awk -F': ' '/^version:/{print $2}')"
}

# =========================
# Install/repair orchestration — steps 1-11 of the approved design.
# =========================

# install_clt — unconditional CLT install/poll. Relocated as-is from
# bootstrap.sh (behavior unchanged); prepare_toolchain below decides
# whether/when to call it and never trusts its exit code as proof of
# success on its own — the capability re-check after it runs is what does.
install_clt() {

    if xcode-select -p &>/dev/null; then
        log "✔ CLT ya instaladas"
        return 0
    fi

    log "📦 Intentando instalar CLT..."
    xcode-select --install 2>/dev/null || true

    for i in {1..60}; do

        if xcode-select -p &>/dev/null; then
            log "✔ CLT instaladas correctamente"
            return 0
        fi

        sleep 5
    done

    log "❌ CLT no se instalaron automáticamente"
    return 1
}

TOOLCHAIN_STRATEGY=""
TOOLCHAIN_ROW=""

# prepare_toolchain — resolves the compatibility matrix against this
# machine and ensures the required capability profile is satisfied before
# Bootstrap continues to Homebrew. Returns 0 to continue, 1 when the
# machine must stop for manual intervention or the toolchain still isn't
# usable after an install attempt. Never continues silently past
# TOOLKIT_STRATEGY=stop, and never treats an install command's exit code
# alone as proof the toolchain is now usable.
prepare_toolchain() {
    local full major profile arch_constraint
    local apple_min apple_max detected_label detected_kind

    full="$(macos_full_version)"
    major="$(macos_major_version)"

    TOOLCHAIN_ROW="$(resolve_toolchain_section "$full" "$major")"

    if [[ "$TOOLCHAIN_ROW" == "BELOW_FLOOR" ]]; then
        TOOLCHAIN_STRATEGY="stop"
    else
        TOOLCHAIN_STRATEGY="$(toolchain_field "$TOOLCHAIN_ROW" TOOLKIT_STRATEGY)"
    fi

    print_section "🧰 Toolchain de desarrollo"
    printf "macOS detectado: %s (familia %s)\n" "${full:-desconocido}" "${major:-desconocido}"

    case "$TOOLCHAIN_STRATEGY" in
        stop)
            error_msg "❌ Esta versión de macOS no cumple el mínimo soportado por JB Toolkit"
            info "ℹ️ Actualiza macOS a una versión soportada e inténtalo de nuevo"
            return 1
            ;;
        proceed_with_warning)
            warn "⚠️ Esta versión de macOS está fuera del nivel de soporte preferido de Homebrew, pero debería funcionar"
            ;;
        proceed_with_caution)
            warn "⚠️ Versión de macOS no reconocida por la matriz de compatibilidad; se continuará con verificación en vivo"
            ;;
        proceed)
            :
            ;;
        *)
            warn "⚠️ Estrategia de compatibilidad desconocida (\"$TOOLCHAIN_STRATEGY\"); continuando con precaución"
            TOOLCHAIN_STRATEGY="proceed_with_caution"
            ;;
    esac

    arch_constraint="$(toolchain_field "$TOOLCHAIN_ROW" ARCH_CONSTRAINT)"
    case "$arch_constraint" in
        apple_silicon_only)
            if (( ! IS_APPLE_SILICON )); then
                error_msg "❌ Esta versión de macOS/Xcode requiere Apple Silicon"
                return 1
            fi
            ;;
        intel_only)
            if (( IS_APPLE_SILICON )); then
                error_msg "❌ Esta versión de macOS/Xcode requiere un Mac con procesador Intel"
                return 1
            fi
            ;;
    esac

    profile="$(toolchain_field "$TOOLCHAIN_ROW" CAPABILITY_PROFILE)"
    [[ -n "$profile" ]] || profile="standard_clt"

    detect_xcode_clt

    # Advisory only, against whichever version is actually installed — full
    # Xcode's own version if present, otherwise the CLT package's version
    # (CLT builds are labeled with their paired Xcode version number, so
    # the same APPLE_XCODE_MIN/MAX range applies to either). Never gates
    # pass/fail on its own — that's validate_capability_profile's job.
    if (( TOOLCHAIN_HAS_FULL_XCODE )) && [[ -n "$TOOLCHAIN_XCODE_VERSION" ]]; then
        detected_label="$TOOLCHAIN_XCODE_VERSION"
        detected_kind="Xcode"
    else
        detected_label="$TOOLCHAIN_CLT_VERSION"
        detected_kind="Command Line Tools"
    fi

    if [[ -n "$detected_label" ]]; then
        apple_min="$(toolchain_field "$TOOLCHAIN_ROW" APPLE_XCODE_MIN)"
        apple_max="$(toolchain_field "$TOOLCHAIN_ROW" APPLE_XCODE_MAX)"

        if [[ -n "$apple_min" ]] && ! _version_ge "$detected_label" "$apple_min"; then
            warn "⚠️ $detected_kind $detected_label instalado es más antiguo que lo documentado por Apple para esta versión de macOS ($apple_min+)"
        elif [[ -n "$apple_max" ]] && ! _version_ge "$apple_max" "$detected_label"; then
            warn "⚠️ $detected_kind $detected_label instalado es más nuevo que lo documentado por Apple para esta versión de macOS (máx. $apple_max)"
        fi
    fi

    if validate_capability_profile "$profile"; then
        log "✔ Toolchain ya cumple el perfil requerido ($profile)"
        return 0
    fi

    log "📦 Toolchain incompleto; instalando Command Line Tools..."
    install_clt || true

    detect_xcode_clt

    if ! validate_capability_profile "$profile"; then
        error_msg "❌ El toolchain sigue sin cumplir el perfil requerido ($profile) tras la instalación"
        return 1
    fi

    log "✔ Toolchain verificado tras la instalación"
    return 0
}
