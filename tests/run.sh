#!/bin/bash
# Lightweight test runner — wraps bats-core so `./tests/run.sh` and
# `make test` both work without anyone needing to remember the exact
# bats invocation. No CI wiring yet (v1.1 — "start small, no CI yet").

set -Eeuo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v bats >/dev/null 2>&1; then
    echo "❌ bats-core no está instalado."
    echo "   Instálalo con: brew install bats-core"
    exit 1
fi

exec bats "$BASE_DIR/tests"
