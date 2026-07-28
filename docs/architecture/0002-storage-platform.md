# ADR-0002: Storage as a Platform Service

## Context

Storage began as `core/maintenance/sync-data.sh`: a script that copied a
fixed set of folders to a hardcoded external drive path. It was rebuilt twice
in quick succession — first into a self-contained migration engine
(discover volumes, adopt one, mirror the Home folder, verify, offer
disposal), then, per this ADR, into infrastructure other migration profiles
build on rather than a single-purpose Home-migration feature. See
[ADR-0001](0001-platform-philosophy.md) for why that means living under
`core/platform/`.

The business context matters here: this is a repair shop's toolkit. The same
external drive plausibly migrates data for many different client Macs over
time — it isn't permanently attached to one machine the way `logs/` is.

## Problem

A migration engine hardcoded to "Home" cannot grow into "Photos Library,
Steam Library, Docker, VMs, Cloud Sync, Backups, Media Libraries" without
duplicating its scan/copy/verify/rollback logic once per kind of data — the
exact kind of duplication the project's own principles reject. Separately, a
volume that gets adopted once and then treated as "just an external disk"
every other session loses information a technician would want: is this drive
already ours, what's already on it, did the last migration to it finish
cleanly.

## Decision

Split Storage into two concerns:

1. **Adopted Data Volume** (`volume.sh`) — a `.jbtoolkit/` directory
   (`metadata.env`, `state.env`, `plans/`, `transactions/`) written onto the
   volume itself turns a generic external disk into recognized managed
   storage. Every run re-discovers volumes and reads this directory fresh;
   there is no separate toolkit-side registry to fall out of sync with
   what's actually plugged in. Plans and transactions are persisted **on the
   volume**, not the toolkit's internal `logs/` — a future "was this
   migration interrupted" check needs to find the record by re-plugging the
   drive, potentially into a different Mac, not by trusting whichever
   machine happened to run the operation.

2. **Generic pipeline + profile plugins** (`engine.sh` + `profiles/*/`) — the
   engine knows only abstract concepts (profile, plan, transaction, verify,
   commit, rollback); every domain-specific thing (what "Home" or "Photos
   Library" means, where it lives, how to enumerate it) is two files under
   `profiles/<id>/`. Verified by construction, not just by design: the
   Downloads profile is two files and ~40 lines total, and it inherited the
   full pipeline — adoption awareness, sizing, the toggle screen, plan
   export, verified copy, rollback on failure, gated deletion — with zero
   engine changes.

Everything outside `core/platform/storage/` talks to it through `api.sh`'s
`storage::*` functions only (`discover_volumes`, `list_volumes`,
`get_default_volume`, `is_managed`, `adopt_volume`, `forget_volume`,
`health`, `free_space`, `verify`, `rollback`, `transactions`, `run_profile`).
See [Storage-Architecture.md](../Storage-Architecture.md) for the full API
table and profile contract.

## Alternatives considered

- **Keep Storage a `core/maintenance/*` sub-module.** Rejected: sub-modules
  are function libraries owned by one orchestrator's workflow. Storage needs
  to be callable by any future orchestrator without that orchestrator
  becoming Maintenance's business — the Platform placement makes that
  explicit rather than incidental.
- **Profiles as single files with N callback functions** (the shape used
  before this iteration). Rejected in favor of `profile.env` + `scan.sh`
  directories: it matches the catalog's own proven convention (one directory
  per data unit, a flat `.env`/`.conf` for declarative fields), and it
  separates truly static data (`DEST_SUBDIR` never changes at runtime) from
  the one genuinely dynamic behavior (scan), rather than encoding a constant
  as a function that always returns it.
- **Per-profile `execute.sh`/`verify.sh` hooks** (part of the original
  request's sketch). Rejected: copying and verification have zero
  profile-specific variance today — 100% generic rsync/checksum — and the
  engine is required to stay domain-agnostic. Per-profile hooks would be
  ceremony with no current use, and worse, would let a future profile
  quietly weaken the uniform verify-before-offering-deletion guarantee every
  other profile relies on for safety.
- **Plans/transactions staying in the toolkit's internal `logs/`.**
  Rejected: it's the more familiar choice (matches Deployment's pattern
  exactly) but wrong for this specific subsystem — Storage is the only part
  of the toolkit whose subject matter is portable, removable media. Keeping
  records local to whichever Mac ran the operation would silently break the
  "find an interrupted migration by re-plugging the drive" property that
  portability is supposed to buy.

## Consequences

- Adding a profile is a two-file, zero-engine-change addition, provable
  today (Downloads) rather than a claim about the future.
- Volume identity, plans, and transactions survive being unplugged from one
  Mac and plugged into another; the toolkit's own `logs/` does not need to
  know a migration ever happened for that migration's record to still exist.
- A schema-1 volume (from before this iteration) is upgraded transparently
  on next use rather than silently misclassified as unmanaged — see
  [ADR-0004](0004-transactions.md) for why this mattered enough to implement
  rather than defer.
- The API surface is now the thing that has to stay stable, not the
  internals — `volume.sh`/`engine.sh` can be refactored freely as long as
  `api.sh`'s contract holds.

## Future implications

Photos Library, Steam Library, Docker, VMs, Cloud Sync, Backups, and Media
Libraries are each a new `profiles/<id>/` directory when actually needed —
not implemented now, per the "prepare the architecture, not the features"
instruction this iteration was scoped under. A Storage History browser
becomes a thin consumer of `storage::transactions`, which already returns
the data.
