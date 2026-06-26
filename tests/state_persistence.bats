#!/usr/bin/env bats
#
# Covers state_value() and write_state_values() in core/utils.sh — the
# single source of truth for logs/state.env (AGENTS.md §3). Every test
# runs against an isolated STATE_FILE under $BATS_TEST_TMPDIR, never the
# real logs/state.env.

load 'helpers/load'

setup() {
    load_utils
    export STATE_FILE="$BATS_TEST_TMPDIR/state.env"
}

@test "state_value returns N/A when the state file does not exist yet" {
    run state_value ANY_KEY
    [ "$status" -eq 0 ]
    [ "$output" = "N/A" ]
}

@test "write_state_values creates the file and the key becomes readable" {
    write_state_values "FOO=1"
    [ -f "$STATE_FILE" ]

    run state_value FOO
    [ "$output" = "1" ]
}

@test "state_value returns N/A for a key that was never written" {
    write_state_values "FOO=1"

    run state_value DOES_NOT_EXIST
    [ "$output" = "N/A" ]
}

@test "write_state_values updates a key atomically instead of appending a duplicate line" {
    write_state_values "FOO=1"
    write_state_values "FOO=2"

    local count
    count=$(grep -c "^FOO=" "$STATE_FILE")
    [ "$count" -eq 1 ]

    run state_value FOO
    [ "$output" = "2" ]
}

@test "write_state_values preserves unrelated keys when updating one key" {
    write_state_values "FOO=1" "BAR=hello"
    write_state_values "FOO=2"

    run state_value BAR
    [ "$output" = "hello" ]
    run state_value FOO
    [ "$output" = "2" ]
}

@test "write_state_values accepts multiple key/value pairs in one call" {
    write_state_values "A=1" "B=2" "C=3"

    run state_value A
    [ "$output" = "1" ]
    run state_value B
    [ "$output" = "2" ]
    run state_value C
    [ "$output" = "3" ]
}

@test "write_state_values handles a value containing an equals sign" {
    write_state_values "SOME_KEY=a=b=c"

    run state_value SOME_KEY
    [ "$output" = "a=b=c" ]
}
