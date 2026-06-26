#!/usr/bin/env bats
#
# Covers the JB_VERSION single source of truth (AGENTS.md §3): every
# consumer must read $JB_VERSION; nothing may hardcode a literal version
# string. This is a direct regression test for a real, previously-shipped
# bug where core/utils.sh's default lagged the actual v1.0.0 release tag.

load 'helpers/load'

@test "JB_VERSION is exported and non-empty after sourcing utils.sh" {
    load_utils
    [ -n "$JB_VERSION" ]
}

@test "no file under core/ hardcodes a literal JB_VERSION=<digit> write" {
    # The only legitimate forms are "JB_VERSION=\$JB_VERSION" (state writes)
    # and the "\${JB_VERSION:-default}" fallback in utils.sh/ui.sh — never
    # a bare literal like "JB_VERSION=0.9" being assigned/written elsewhere.
    run grep -rn '"JB_VERSION=[0-9]' "$JB_TEST_ROOT/core" --include="*.sh"
    [ "$status" -ne 0 ]
}

@test "the banner does not hardcode a literal version string" {
    # print_banner must print %s + $JB_VERSION, never a baked-in "vX.Y" —
    # any line that looks like a version string must also reference
    # JB_VERSION on the same line.
    run grep -nE 'JB Toolkit.*v[0-9]+\.[0-9]' "$JB_TEST_ROOT/core/bootstrap/ui.sh"
    [ "$status" -ne 0 ] || [[ "$output" == *'JB_VERSION'* ]]
}
