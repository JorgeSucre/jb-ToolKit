#!/usr/bin/env bats
#
# Covers detect_app_state() in core/utils.sh — the single source of truth
# for "is this app installed" (Homebrew formula -> Homebrew cask -> manual
# .app bundle -> Mac App Store), reused by Bootstrap, Documentation, and
# Report (AGENTS.md §4). Read-only: these tests never install or remove
# anything, they only query state that already exists on the machine.

load 'helpers/load'

setup() {
    load_utils
}

@test "detect_app_state reports not_installed:none for a package that cannot exist" {
    run detect_app_state "definitely-not-a-real-package-xyz123" "DefinitelyNotARealApp.app" "0000000000"
    [ "$status" -eq 0 ]
    [ "$output" = "not_installed:none" ]
}

@test "detect_app_state output always matches the documented <state>:<method> contract" {
    run detect_app_state "definitely-not-a-real-package-xyz123"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^(installed|update|not_installed):(homebrew-formula|homebrew-cask|manual|app-store|none)$ ]]
}

@test "detect_app_bundle_installed returns failure for an empty app name" {
    run detect_app_bundle_installed ""
    [ "$status" -ne 0 ]
}

@test "detect_mas_app_installed returns failure for an empty mas id" {
    run detect_mas_app_installed ""
    [ "$status" -ne 0 ]
}
