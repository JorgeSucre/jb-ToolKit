# JB Toolkit v2.2.2 — Release Notes

## Overview

JB Toolkit is a macOS maintenance, diagnostic, optimization, and deployment
suite built for repair technicians and IT consultants. It runs entirely as
native Bash — no compiled binary, no package manager for itself, no runtime
beyond what macOS already ships (`bash`, `awk`, `diskutil`, `defaults`, and
friends). A single launcher (`jb`) presents five modules: Bootstrap,
Diagnostics, Maintenance, Deployment, and Report.

v2.2.2 is the first release prepared as a **production-quality baseline**
rather than an evolving prototype. It closes out an architectural arc that
started with promoting Storage to a reusable Platform service and ends with
this release's own integration-hardening pass: every subsystem has been
verified against real conditions — a real external drive, the real entry
point's actual shell semantics, deliberately broken fixtures — not just
read and reasoned about.

## Release Goals

This release had one job: make the implementation match the architecture
that had already been decided, and make the repository *feel* finished.
Concretely:

- Prove no historical concept (Bundles, Profiles, the old two-level category
  menu) survived anywhere in the codebase — not assumed, searched for.
- Verify every integration point behaves the way its own documentation
  already claimed it did, and fix the gaps where it didn't.
- Root-cause real-world-reported issues (an undetected external drive, an
  oddly worded performance mode) rather than patch their symptoms.
- Bring documentation, version numbers, and the actual repository state into
  agreement, everywhere.

No new features were added in service of this release. Every change either
closes a gap between documentation and implementation, or fixes a defect
found while verifying that gap didn't exist.

## Major Architectural Milestones

| Milestone | What changed | Where |
|---|---|---|
| Platform layer established | Storage became the first tenant of a `core/platform/` layer other shared services can eventually join | [ADR-0001](docs/architecture/0001-platform-philosophy.md) |
| Storage as a Platform service | Generic scan→plan→preview→execute→verify→rollback→commit pipeline; Adopted Data Volumes; a public `storage::*` API | [ADR-0002](docs/architecture/0002-storage-platform.md), [Storage-Architecture.md](docs/Storage-Architecture.md) |
| Deployment flattened | `Profiles → Bundles → Applications` → `Catalog → Applications → Selected Applications → Installation Plan → Execution`; one selection model | [ADR-0006](docs/architecture/0006-deployment-flattening.md), [Deployment-Architecture.md](docs/Deployment-Architecture.md) |
| Catalog consistency | One application → one category (16 tags → 8); presets consolidated into one file | [ADR-0007](docs/architecture/0007-catalog-consistency.md), [Catalog-Format.md](docs/Catalog-Format.md) |
| Integration hardening | JB Picks folded into normal browsing; Storage/Performance/validation defects root-caused and fixed | [ADR-0008](docs/architecture/0008-integration-hardening.md) |

## Platform Overview

`core/platform/` holds shared services with their own public API, sourced
by whichever module needs them — today, only Storage. The pattern: a thin
`api.sh` facade (`storage::*` functions are the *only* surface anything
outside the directory should call), internal implementation files that stay
private, and a bar for adding a second tenant (a real second consumer,
proven small, or an equally explicit request) so the pattern doesn't become
a home for premature abstraction.

## Storage Overview

An external APFS volume becomes **managed storage** the first time JB
Toolkit initializes it — a `.jbtoolkit/` directory holding immutable
identity (`TOOLKIT_UUID`, disk/volume UUIDs, creation record) and mutable
usage history, plus a shared `JB Toolkit/` namespace folder migration
profiles write under. Every migration goes through the same pipeline
regardless of what's being moved (Home, Downloads today; more profiles are
pure data/scan-script additions, zero engine changes). Nothing is deleted
from a source until a checksum-verified copy exists **and** a second
explicit confirmation is given.

This release fixed volume **discovery**: writability is now a per-volume
status shown to the technician (with an actionable reason), not a silent
filter that could make a real, correctly-formatted external drive
indistinguishable from nothing being plugged in at all.

## Deployment Overview

One flow, one selection model: pick a Quick Preset (optional — just a
shortcut into a pre-filled selection, never a separate execution path),
review and freely edit the Application Catalog (grouped by category, one
application in exactly one place), confirm, install. Every application
installs independently — one failure never stops the rest — and the result
screen names every outcome: installed, already installed, manual step
required, incompatible, or failed with its reason. Nothing is ever silently
skipped.

## Catalog Overview

The catalog (`catalog/`) is the single source of truth for what's
installable: one directory per application (`app.conf`, flat `KEY=value`,
readable and editable with any text editor), one `[id]` section per preset
in a single `presets.conf`. No YAML, no JSON, no SQLite — every file stays
parseable by the same lightweight `awk` pattern the rest of the toolkit's
state persistence already uses. A nine-rule validator (V1–V9) rejects an
inconsistent catalog loudly, by file and rule number, rather than silently
tolerating it.

## Maintenance Improvements

Aggressive performance optimization's relationship to Light is now stated
explicitly wherever the technician sees it, instead of presenting as two
independent, back-to-back operations. This was always intentional code
reuse (Aggressive genuinely calls Light internally to avoid duplicating
`defaults write` calls); the fix is entirely about what the technician sees
matching what the code does.

## Validation Improvements

- New rule **V9**: duplicate keys within one catalog file or preset section
  are now rejected instead of silently discarding everything but the first
  match.
- Malformed preset section headers are now validated instead of being
  invisible to every listing, including the validator's own success message.
- Internal catalog accessors (`_flag_line`/`_preset_flag_line`) were
  hardened to the same "tolerant, exit 0" contract every other accessor in
  the file follows.

## Important Design Decisions

- **YAML/JSON were considered and rejected for `presets.conf`.** The
  project's standing rule — no YAML, no JSON, no SQLite, ever — was upheld
  even when consolidating eight files into one; the `[id]`-section format
  chosen stays inside the existing awk-parseable convention instead of
  introducing a second parsing paradigm or a new dependency.
- **JB Picks is catalog data, not a feature.** `JB_PICK=true` is a per-
  application curation flag. It is now surfaced inline wherever the
  technician is already looking (the Application Catalog, the plan's
  explain view) instead of behind a dedicated screen that implied a
  different — and, in practice, dead-end — path through the tool.
- **Writability is a status, not a gate.** Consistent with how an
  incompatible application is shown with its reason rather than silently
  omitted, an external volume that can't be written to is now shown with
  its reason rather than silently absent from the list.

## Known Limitations

- `catalog/vendors/` is reserved, unimplemented space for future
  per-organization preset compositions. Deliberately deferred: the shape
  such a feature would take is structurally close to the removed Bundle
  concept, and it should not be designed casually.
- No pruning policy exists yet for Storage's on-volume plan/transaction
  history. Not a problem at realistic usage volumes today.
- Three presets (`business`, `education`, `office`) currently resolve to
  identical application lists — a content decision left open for whoever
  owns the catalog's curation, surfaced by the Catalog Doctor rather than
  silently hidden.

## Future Direction

No architecture work is planned for the immediate next version — this
release exists specifically to let the current architecture sit
unmodified through real-world use. Future changes should be driven by
concrete, demonstrated needs (a second Platform service tenant, a real
cross-preset reuse case, actual catalog scale pressure), not speculative
extension of what's here today. See [Future-Roadmap.md](docs/Future-Roadmap.md)
for the standing list of known, deliberately deferred items.
