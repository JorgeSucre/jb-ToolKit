# Common setup for JB Toolkit bats tests.
#
# Tests source core/utils.sh directly and exercise its functions against
# an isolated, per-test STATE_FILE (under $BATS_TEST_TMPDIR) — they never
# touch the real logs/state.env. Anything that would be destructive on a
# real Mac (cleanup.sh, performance.sh, bootstrap.sh) is deliberately not
# tested here yet — see references/KNOWN_ISSUES.md for the test-coverage
# roadmap. This is a starting point, kept intentionally small per the
# v1.1 objective ("start small").

JB_TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

load_utils() {
    # shellcheck disable=SC1091
    source "$JB_TEST_ROOT/core/utils.sh"
}
