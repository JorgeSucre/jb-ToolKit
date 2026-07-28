# ADR-0003: State Management

## Context

The Architecture Freeze request names "State" as a candidate future Platform
service, alongside Metrics, Logging, Report, Events, and Config. Before that
name gets used for anything, it's worth being explicit about what state
management already exists in this project, because there are two of them
now, and they should stay two — not get prematurely merged into one
"generic State service" that neither consumer actually needs.

## Problem

Without this ADR, a future contributor could reasonably read "State" in
[ADR-0001](0001-platform-philosophy.md)'s candidate list and assume it means
generalizing `logs/state.env`, or worse, assume Storage's volume-resident
`.jbtoolkit/state.env` is a prototype of that generalization and start
threading toolkit-wide state through a volume that may not even be plugged
in. Neither is true, and the difference is load-bearing, not stylistic.

## Decision

Keep two separate, narrowly-scoped state mechanisms, and don't build a third
"generic State service" to unify them:

1. **`logs/state.env`** — cross-**module** state, scoped to one toolkit
   installation on one Mac. Read/write via `core/utils.sh`'s `state_value` /
   `write_state_values`. This is how Diagnostics hands a baseline score to
   Maintenance, how Deployment tells Report what happened, and now how
   Storage records `LAST_STORAGE_MIGRATION` and friends. It answers "what did
   *this toolkit installation* last do."

2. **`<volume>/.jbtoolkit/state.env`** — cross-**session**, cross-**machine**
   state, scoped to one physical piece of removable media. Deliberately
   separate from #1 because it needs to travel with the volume, not the
   toolkit installation — the same drive might be adopted on one Mac and
   reused on another six months later, and its `MIGRATION_COUNT` /
   `LAST_MIGRATION_AT` need to mean "this drive's history," not "what the
   Mac currently running the toolkit remembers."

Both are already generalized at the *parser* level — `core/utils.sh`'s
`read_kv_value FILE KEY` / `write_kv_values FILE "K=V"…` back both
`state_value`/`write_state_values` (hardcoded to `$STATE_FILE`) and Storage's
`volume_metadata_value`/`touch_volume_usage` (hardcoded to a volume's
`.jbtoolkit/*.env`). That's the correct level of consolidation: one
flat-KV-file implementation, two independent files it operates on. Merging
the files themselves — routing volume state through the toolkit's local
`state.env`, or vice versa — would break the exact separation of scope that
makes each one correct for its consumer.

## Alternatives considered

- **A generic `core/platform/state/` service now**, with `logs/state.env`
  and volume state as two "backends." Rejected: there is no second
  *behavioral* consumer today, only two data files that happen to share a
  file format — the actual bar from [ADR-0001](0001-platform-philosophy.md)
  ("two or more consumers, consolidating makes it smaller") isn't met, and
  building an abstraction layer over two already-simple three-line functions
  would be strictly more code for zero behavioral gain.
- **Route Storage's volume state through `logs/state.env`** (e.g.,
  `STORAGE_VOLUME_<uuid>_MIGRATION_COUNT=…`). Rejected: it would make volume
  history depend on which Mac last ran the toolkit, defeating the entire
  reason volume-resident state exists (see [ADR-0002](0002-storage-platform.md)).

## Consequences

- "State" stays an unimplemented, unscheduled candidate on the Platform
  roadmap. If it's ever built, it should solve a problem neither of the two
  existing mechanisms has — not become a forced merge of them.
- Contributors adding a new cross-module fact reach for `write_state_values`
  (local, toolkit-scoped); contributors adding a new fact about an adopted
  volume reach for the volume's own `state.env` via Storage's `api.sh`. The
  choice is which *scope* the fact belongs to, not a technical constraint.

## Future implications

A genuine future need for a generalized State service would look like a
**third** consumer with its own scope (neither "this toolkit installation"
nor "this removable volume") — for example, syncing state across multiple
Macs in a shop without physical media changing hands. Until that need is
real, this ADR's answer is: two mechanisms, both already about as small as
they can be, deliberately not merged.
