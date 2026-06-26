#!/usr/bin/env bats
#
# Covers calculate_health_score() in core/utils.sh. The second test is a
# direct regression test for a real, previously-shipped bug: calling this
# function via "$(...)" runs it in a subshell, which discards the
# SYS_RAM_PCT/SYS_DISK_PCT/SYS_HEALTH_SCORE side-effect caches and
# silently persisted zeros into state.env (see core/diagnostics.sh's
# comment on the fix, and AGENTS.md §2's note on this bug class).

load 'helpers/load'

setup() {
    load_utils
}

@test "calculate_health_score prints a score between 0 and 100" {
    run calculate_health_score
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+$ ]]
    [ "$output" -ge 0 ]
    [ "$output" -le 100 ]
}

@test "calling calculate_health_score directly (no subshell) populates the cache globals" {
    # Regression test: must be called as "calculate_health_score >/dev/null",
    # never "X=\$(calculate_health_score)", or these globals never update.
    SYS_RAM_PCT=""
    SYS_DISK_PCT=""
    SYS_HEALTH_SCORE=""

    calculate_health_score >/dev/null

    [[ "$SYS_HEALTH_SCORE" =~ ^[0-9]+$ ]]
    [[ "$SYS_RAM_PCT" =~ ^[0-9]+$ ]]
    [[ "$SYS_DISK_PCT" =~ ^[0-9]+$ ]]
}

@test "calculate_health_score called via \$(...) loses its cache globals (documents the footgun)" {
    SYS_RAM_PCT="untouched"

    # shellcheck disable=SC2034
    local score
    score="$(calculate_health_score)"

    # The subshell never had a chance to update the caller's SYS_RAM_PCT —
    # this is exactly why core/diagnostics.sh calls the function directly
    # instead of through command substitution.
    [ "$SYS_RAM_PCT" = "untouched" ]
}
