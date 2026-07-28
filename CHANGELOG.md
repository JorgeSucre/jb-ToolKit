# Changelog

All notable changes to JB Toolkit are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versioning follows
[Semantic Versioning](https://semver.org/) as adapted for this project in
[docs/release-policy.md](docs/release-policy.md).

This file focuses on user-visible and architectural changes, not
implementation detail — see `docs/architecture/*.md` for the reasoning
behind each decision, and `docs/*.md` for how the system works today.

## [2.2.2] — 2026-07-28 — First production-quality release

This release closes the architectural arc that began with the Storage
Platform work: Platform, Storage, Deployment, the Catalog, the one selection
model, and Transactions are now all considered **stable** — not just
implemented, but verified against real hardware and real execution
conditions, and declared frozen for this release.

### Architecture

- **Deployment flattened** from `Profiles → Bundles → Applications` to a
  single flow: `Catalog → Applications → Selected Applications → Installation
  Plan → Execution`. Bundles and Profiles are gone entirely — not renamed,
  not kept as an internal composition primitive. See
  [ADR-0006](docs/architecture/0006-deployment-flattening.md).
- **One selection model.** Whether an application enters the selection via a
  preset, a hardware recommendation, or a manual toggle, it is the exact same
  kind of member of `SELECTED_APPS` by the time the Application Catalog or
  the plan sees it. There is exactly one code path from selection to plan.
- **Storage promoted to a Platform service** (`core/platform/storage/`): a
  generic scan → plan → preview → execute → verify → rollback → commit
  pipeline, an Adopted Data Volume concept that persists identity on the
  external volume itself (not the toolkit's local logs), and a public
  `storage::*` API. See
  [ADR-0001](docs/architecture/0001-platform-philosophy.md) and
  [ADR-0002](docs/architecture/0002-storage-platform.md).
- **One application, one category.** The catalog's `CATEGORIES` field
  (multi-valued, 16 overlapping tags) became `CATEGORY` (exactly one value,
  validated against an 8-value enum). An application can no longer appear
  twice in the Application Catalog browser under two different selection
  numbers. See [ADR-0007](docs/architecture/0007-catalog-consistency.md).
- **Presets consolidated** from one file per preset
  (`catalog/presets/<id>.preset`, 8 files) into a single
  `catalog/presets.conf` (one `[id]` section per preset). Considered and
  rejected YAML/JSON in favor of staying inside the project's existing
  awk-parseable, dependency-free file convention. See ADR-0007.
- **JB Picks is no longer a separate screen.** A `JB_PICK=true` application
  is annotated inline (⭐) wherever it appears in the Application Catalog,
  instead of living behind a dead-end read-only menu branch that implied a
  different execution path where none existed. See
  [ADR-0008](docs/architecture/0008-integration-hardening.md).

### Added

- New catalog validation rule **V9**: no duplicate `KEY=` line within one
  `app.conf` or one preset's `[id]` section — previously a silently
  discarded, invisible inconsistency.
- Malformed preset section headers (a typo, a stray capital, a space in
  `[id]`) are now caught by the validator instead of being silently invisible
  to every listing.
- Storage volume discovery now reports **why** an external volume can't be
  used instead of silently omitting it: an unwritable volume is listed with
  an actionable status ("⛔ Sin permisos de escritura") and a fix suggestion,
  rather than looking identical to no disk being attached at all.

### Changed

- Application Catalog browsing groups by each application's single
  `CATEGORY` instead of a multi-valued tag set — 16 overlapping categories
  consolidated to 8 clear ones (browsers, communication, creative,
  development, hardware, networking, productivity, utilities).
- Aggressive performance optimization now states explicitly, in its own
  messaging, that it includes everything Light applies plus additional
  changes — instead of two independent-looking "Applying..." announcements
  with nothing connecting them.
- Hardware-recommended applications now pass through the same
  compatibility filter (`ARCHS`/`MIN_MACOS`) preset loading already used,
  closing a structural gap where a hardware recommendation could
  theoretically bypass compatibility checking that every other selection
  path enforces.

### Fixed

- **Storage Management failed to detect a real, correctly-attached external
  drive.** Root cause: the writability probe wrote to the volume's bare
  root, which fails for a non-root user on any drive with ownership
  enforcement on (root:wheel, a common and unremarkable state for a
  previously-used or freshly-formatted external disk) — and the volume was
  then silently dropped from the list rather than reported. Verified fixed
  against a real attached drive.
- `diagnostics.sh` was writing the **literal string** `"JB_VERSION=0.9"` into
  `state.env` on every Diagnostics run, silently overwriting the real
  installed version. Now writes the actual `$JB_VERSION`.
- Four core files (`ui.sh`, `hardware.sh`, `brew.sh`, `storage.sh`) had two
  stray blank lines before their shebang line.
- Removed dead code with zero call sites and no documented future use:
  `list_jb_picks()`, `render_jb_pick()`, `_count_lines()`,
  `brew_prefix_safe()`, `print_cancelled()`.
- `_flag_line`/`_preset_flag_line` (catalog validator internals) now always
  return 0, matching the "tolerant, exit 0" contract every other catalog
  accessor in the file already follows — closes a latent `set -e` hazard
  that, while confirmed not reachable through any real call site today,
  should not have depended on every future caller remembering to guard
  against it.
- Top-level `README.md` described the removed Profiles→Bundles workflow and
  the pre-consolidation category groupings as current; rewritten to match
  the shipped architecture.

### Known Limitations

- `catalog/vendors/` remains reserved and unimplemented — a future
  "vendor composing presets" concept is structurally close to the removed
  Bundle concept and must be designed against that tension deliberately, not
  silently reintroduced.
- No retention/pruning policy exists yet for `.jbtoolkit/plans/` and
  `.jbtoolkit/transactions/` on external volumes — not a real problem at
  current usage scale, revisit if it becomes one.
- `business`/`education`/`office` presets currently resolve to identical
  application lists — a curation decision, not a defect, left for whoever
  owns that call (the Catalog Doctor's D2 advisory keeps this visible).

## [2.0.1] — Single version source and manual outcomes in Report

Last previously tagged release. `BREW=`/`CASK=` catalog fields generalized
into the `INSTALL_METHOD`/`PACKAGE`/`DOWNLOAD_URL` model (with a manual track
for applications Homebrew can't provide); `JB_VERSION` became the single
source read by every consumer (banner, snapshot, state); Report gained
verified manual-outcome reporting.

## Earlier history

JB Toolkit began as a single-purpose maintenance script and grew into a
modular launcher (Bootstrap, Diagnostics, Maintenance, Deployment, Report)
before formal versioning and this changelog existed. See `git log` for the
complete commit history predating v2.0.1.
