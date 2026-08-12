#!/bin/bash

# =========================
# toolchain.sh self-check
# =========================
# No test framework, per docs/CONTRIBUTING.md's "Testing expectations" —
# plain assertions against the pure decision functions in toolchain.sh,
# run with literal/synthetic inputs so nothing here touches the real
# machine's actual macOS/Xcode/CLT installation. Run directly:
#   core/bootstrap/toolchain_test.sh

set -Eeuo pipefail

BASE_DIR="${BASE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$BASE_DIR/core/bootstrap/toolchain.sh"

PASS=0
FAIL=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        printf "FAIL: %s — expected %q, got %q\n" "$desc" "$expected" "$actual"
    fi
}

assert_ok() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        printf "FAIL: %s — expected success, command failed\n" "$desc"
    fi
}

assert_fail() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        FAIL=$((FAIL + 1))
        printf "FAIL: %s — expected failure, command succeeded\n" "$desc"
    else
        PASS=$((PASS + 1))
    fi
}

# =========================
# 1. Patch-band lookup — against the real, committed matrix file, exactly
#    the scenarios the design requires.
# =========================

assert_eq "Monterey 12.5 -> section" "12.5" "$(resolve_toolchain_section 12.5 12)"
assert_eq "Monterey 12.5 -> strategy" "proceed_with_warning" "$(resolve_toolchain_strategy 12.5 12)"

assert_eq "Monterey below 12.5 -> strategy" "stop" "$(resolve_toolchain_strategy 12.4 12)"

assert_eq "Ventura 13.5 -> section" "13.5" "$(resolve_toolchain_section 13.5 13)"
assert_eq "Ventura 13.5 -> strategy" "proceed_with_warning" "$(resolve_toolchain_strategy 13.5 13)"

assert_eq "Ventura below 13.5 -> strategy" "stop" "$(resolve_toolchain_strategy 13.4 13)"

assert_eq "Sonoma 14.0 -> section" "14.0" "$(resolve_toolchain_section 14.0 14)"
assert_eq "Sonoma 14.0 -> strategy" "proceed" "$(resolve_toolchain_strategy 14.0 14)"

assert_eq "Sonoma 14.4 -> section (still the 14.0 band)" "14.0" "$(resolve_toolchain_section 14.4 14)"

assert_eq "Sonoma 14.5 -> section" "14.5" "$(resolve_toolchain_section 14.5 14)"
assert_eq "Sonoma 14.5 -> strategy" "proceed" "$(resolve_toolchain_strategy 14.5 14)"

assert_eq "Sonoma newer than 14.5 -> section (14.5 band still applies)" "14.5" "$(resolve_toolchain_section 14.9 14)"

assert_eq "macOS major newer than matrix -> DEFAULT_NEWER" "DEFAULT_NEWER" "$(resolve_toolchain_section 15.0 15)"
assert_eq "macOS major newer than matrix -> strategy" "proceed_with_caution" "$(resolve_toolchain_strategy 15.0 15)"

assert_eq "macOS major older than matrix -> DEFAULT_OLDER" "DEFAULT_OLDER" "$(resolve_toolchain_section 11.7 11)"
assert_eq "macOS major older than matrix -> strategy" "stop" "$(resolve_toolchain_strategy 11.7 11)"

# =========================
# 2. Version comparison
# =========================

assert_ok "_version_ge equal" _version_ge "14.5" "14.5"
assert_ok "_version_ge greater" _version_ge "14.6" "14.5"
assert_fail "_version_ge less" _version_ge "14.4" "14.5"
assert_ok "_version_ge longer vs shorter" _version_ge "14.5.1" "14.5"
assert_ok "_version_ge major-only vs dotted" _version_ge "15" "14.9"

# =========================
# 3. Xcode vs. CLT path classification
# =========================

assert_ok "full Xcode path detected" _is_full_xcode_path "/Applications/Xcode.app/Contents/Developer"
assert_fail "CLT-only path not classified as full Xcode" _is_full_xcode_path "/Library/Developer/CommandLineTools"
assert_fail "empty path not classified as full Xcode" _is_full_xcode_path ""

# =========================
# 4. Capability validation — hermetic fixture commands, no dependency on
#    the real clang/git or their state on this machine.
# =========================

FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

cat > "$FIXTURE_DIR/good-tool" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$FIXTURE_DIR/good-tool"

cat > "$FIXTURE_DIR/bad-tool" <<'EOF'
#!/bin/bash
exit 1
EOF
chmod +x "$FIXTURE_DIR/bad-tool"

PATH="$FIXTURE_DIR:$PATH"

assert_ok "CLT present and valid" validate_capability "good-tool"
assert_fail "CLT missing entirely" validate_capability "nonexistent-tool-xyz"
assert_fail "toolchain present but --version fails (invalid/insufficient)" validate_capability "bad-tool"
assert_ok "capability profile: standard_clt satisfied" validate_capability "good-tool
good-tool"
assert_fail "capability profile: standard_clt with one missing command" validate_capability "good-tool
nonexistent-tool-xyz"
assert_fail "unknown capability profile fails closed" validate_capability_profile "no_such_profile"

echo ""
echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
