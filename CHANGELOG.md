# Changelog

All notable changes to JB Toolkit are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versioning follows
[Semantic Versioning](https://semver.org/) as adapted for this project in
[docs/release-policy.md](docs/release-policy.md).

This file focuses on user-visible and architectural changes, not
implementation detail — see `docs/architecture/*.md` for the reasoning
behind each decision, and `docs/*.md` for how the system works today.

## [2.4.1] — 2026-08-05 — Terminal UI & Deployment UX Refinement

Real-world use of v2.4.0 on actual Macs showed the remaining friction was
presentational, not architectural. This release reverses one v2.4.0
decision (interactive preset loading) based on that feedback and adds a
real terminal-width-aware multi-column catalog layout — previously rejected
on alignment-risk grounds, now shipped with a concrete, bounded mitigation.
See `docs/architecture/0012-terminal-ui-refinement.md` for full reasoning,
including rejected proposals.

### Changed

- The Application Catalog's `l` command (load a preset, added in v2.4.0) is
  removed. The standalone Deployment module's interactive UI has no way to
  load a preset anymore — every workflow ends with hand-picking from the
  catalog regardless, so the loader was one more concept without enough
  payoff. Presets remain fully real everywhere else: `catalog/presets.conf`,
  `catalog.sh`'s accessors, the CLI (`--resolve`/`--explain`/`--tree`/
  `--plan`), `render_plan_tree`, and Bootstrap's onboarding wizard (its own
  "how will this Mac be used?" question) are all unchanged.
- The Application Catalog now renders as a responsive 1–3 column grid,
  chosen from real terminal width (`tput cols`, re-read on every screen
  redraw) — `<100` columns wide stays single-column, `100–149` becomes two
  columns, `150+` becomes three. Numbering runs left-to-right so typed
  ranges (`3-5`) stay visually adjacent. Category headers now show an
  inline app count.
- The application detail view drops the `ARCHITECTURE` line (purely
  descriptive, never gates anything, "universal" for nearly every app) and
  collapses category/license/install-method into one compact line.
- The pre-install confirmation screen is now glyph-led (✔ installed, ⭐
  picks, ★ recommended-skipped, ✋ manual) instead of label-led — the same
  vocabulary the catalog grid and the result screen already use, so nothing
  new has to be learned to read it.

### Rejected (see ADR-0012 for full reasoning)

- Truncating long application names to guarantee perfect column alignment
  — rejected; the rare long name (1 of 181 today) overflows its own row by
  a few characters instead, a bounded, self-contained cosmetic exception
  rather than hidden information.
- Column-major ("down then across") numbering, matching `ls -C` — rejected
  in favor of row-major, which keeps typed ranges visually adjacent.
- Removing `confirm.sh`'s `[G]` diff-view option as a consequence of
  removing interactive preset loading — rejected; it's a real no-op for the
  standalone-Deployment case now, but still genuinely useful for the
  wizard's flow, which the brief explicitly preserves presets for.
- 4+ column layouts for ultra-wide terminals — rejected as scope beyond
  what real technician terminals need; capped at 3, easy to extend later.

## [2.4.0] — 2026-08-05 — Deployment Workflow Simplification

The catalog and its browsing experience were mature by v2.3.2; this release
targets the *workflow* around it — fewer forced screens/decisions, and
earlier visibility into machine state. The Plan/Transaction contract,
Storage, Validation, and the Catalog's own data shape are untouched. See
`docs/architecture/0011-deployment-workflow-simplification.md` for full
reasoning, including rejected proposals.

### Changed

- The standalone Deployment module's entry point is now the Application
  Catalog itself — the preset-picker screen ("what kind of Mac are we
  preparing?") is no longer a mandatory first step. Presets are now loaded
  via a new `l` command *from inside* the catalog (confirmed only when
  replacing a non-empty selection); `catalog/presets.conf`, the CLI preset
  flags (`--resolve`/`--explain`/`--tree`/`--plan`), and Bootstrap's own
  onboarding wizard (which still asks its own "how will this Mac be used?"
  question first) are unchanged.
- Hardware recommendations (`HW_RECOMMEND`) are advisory-only: a ★ badge on
  matching apps in the Application Catalog, shown regardless of selection
  state. They no longer silently pre-select applications into the plan.
- The Application Catalog shows a ✔ badge (green) on already-installed
  applications, checked live via the existing Homebrew query cache /
  `/Applications` bundle check — no new subprocess per app.
- Within each category, applications are sorted JB Picks first, then
  hardware-recommended, then alphabetically — the highest-relevance apps
  surface without scrolling. Selection state is deliberately not a sort
  key, so the list never reorders under a technician mid-selection.
- The application detail view (`d<n>`) leads with an install/recommendation
  status line.
- The pre-install confirmation screen and the explain view now show
  will-install / already-installed / recommended-but-skipped counts
  alongside the existing manual/pick/incompatible counts, computed fresh at
  render time (no change to the Plan contract itself).

### Rejected (see ADR-0011 for full reasoning)

- Deleting presets entirely — still wired into the plan's identity
  (`--tree`'s diff view) and four CLI flags; only the *mandatory screen*
  was removed, not the concept.
- A 2/3-column grid catalog layout — `printf` column-padding in Bash 3.2
  isn't reliably terminal-width-accurate for emoji/symbol badges, risking
  visibly misaligned output across terminals; a priority sort achieves the
  same "less scrolling" goal without that risk.
- Sorting by "already installed" or by current selection state — both
  would reorder the list while a technician is actively browsing/
  selecting, which is worse than the scrolling being solved for.
- A "□ Available" badge on every non-installed application — badging the
  ~150-of-181 default case is noise, not information.
- A broader color palette (per-category color, dimmed rows) — one reused
  color (green, matching its existing "success" meaning) for one concept.
- Refactoring `install.sh` to reuse the new catalog-driven
  `app_already_installed` helper — `install.sh` is documented to never
  read the catalog and execute plan records verbatim
  (`Deployment-Architecture.md`); doing so would have introduced exactly
  the dependency that invariant exists to prevent.

## [2.3.2] — 2026-08-05 — Catalog Experience & Discoverability

The 181-application catalog is mature; this release makes it easier to
navigate instead of larger. Deployment, Presets, Storage, and Validation's
existing shape are untouched — everything here is additive rendering/query
logic over the existing two layers plus one new optional field. See
`docs/architecture/0010-catalog-discoverability.md` for the full decision
record, including features deliberately rejected.

### Added

- Search and filters inside the existing Application Catalog screen (no new
  screen): `/text` searches name/description (case-insensitive substring),
  `p` toggles a JB Picks-only filter, `h` toggles a recommended-for-this-Mac
  filter. Both narrow the same numbered toggle list technicians already use.
- Application detail view (`d<number>`): homepage, license, install method,
  architecture, requirements, notes, the JB Pick note, alternatives, and
  related applications for one app, without leaving the catalog screen.
- New optional field `RELATED` — space-separated application IDs for
  companion tools typically used alongside this one (e.g. Docker Desktop →
  Visual Studio Code, Git, Postman, Node.js; Ollama → AnythingLLM, LM
  Studio, GPT4All, ChatGPT). Validated against the catalog (new rule V12).
  Seeded on 10 applications in the development/AI clusters where the
  relationship is unambiguous — not populated exhaustively, same precedent
  as `ALTERNATIVES`/`NOTES` today.

### Rejected (see ADR-0010 for full reasoning)

- A per-application `RECOMMENDED_FOR`/persona field and a `USER_LEVEL`
  field — both would reintroduce audience-based classification
  `CATALOG_CONSTITUTION.md` §2 already ruled out for `CATEGORY`, and
  `USER_LEVEL` would require fabricating a skill-level judgment for 181
  applications with no operational basis for most of them.
- A second "JB Notes" field distinct from `JB_PICK_NOTE` — redundant with
  what `JB_PICK`+`JB_PICK_NOTE` already means; no new picks were fabricated
  to backfill it.
- A dedicated JB Picks browser screen — already built and deliberately
  removed in v2.2.2; the new `p` filter stays inside the one catalog screen.
- A License-based (open source/paid/freemium) filter and an install-method
  filter — evaluated, didn't clear the "clearly improves usability" bar.
- Real fuzzy (edit-distance) search — substring match already resolves
  partial names/typos for a ~180-item list without the extra code.

## [2.3.1] — 2026-08-05 — Catalog Expansion & Curation

The catalog grows from 121 to 181 applications and from 12 to 13
categories, purely through curated additions on top of the v2.3.0 schema.
Deployment, Presets, Platform, Storage, and Validation are untouched — this
release is catalog content only. Every application was individually
evaluated against the Catalog Constitution's "curated over exhaustive"
principle before being added; several well-known candidates were
deliberately rejected. See the engineering report delivered alongside this
release for the full research trail, rejections, and reasoning.

### Added

- 60 new applications, every one verified via `brew info` against the live
  Homebrew index before being catalogued (59 casks, 1 formula — Neovim).
  No entry was catalogued from memory alone; candidates that didn't
  resolve were either given a corrected token, replaced with a verified
  equivalent, or rejected outright (see Known Limitations).
- New `cloud` category (Dropbox, Google Drive, MEGAsync, Nextcloud, Resilio
  Sync, Syncthing) — six cloud-storage/sync clients, enough purpose-coherent
  volume to earn a dedicated home rather than being split across
  `productivity` and `system`.
- Notable additions by category: `ai` (GPT4All, Jan, AnythingLLM);
  `development` (GitHub Desktop, Zed, Sublime Text, the JetBrains Toolbox
  plus PyCharm CE and IntelliJ IDEA CE, Sourcetree, GitKraken, kitty,
  Neovim, and virtualization tools UTM/VirtualBox/Parallels Desktop);
  `security` (KeePassXC, Cryptomator, GPG Suite, Yubico Authenticator,
  BlockBlock, ClamXAV, and the VPN clients Cloudflare WARP and OpenVPN
  Connect); `creative` (Audacity, LosslessCut, Shotcut, Blender, Inkscape,
  Krita); `system` (BetterTouchTool, Raycast, Alfred, Dropzone, Loop,
  Maccy, Itsycal, Rocket, Scroll Reverser, GrandPerspective).
- Virtualization (UTM, VirtualBox, Parallels Desktop) evaluated for its own
  category and placed under `development` instead — three applications
  don't yet justify a fourteenth category; revisit if the count grows.

### Changed

- Category enum: 12 → 13 values (`cloud` added). `CATALOG_CATEGORIES` in
  `core/deployment/catalog.sh`, `docs/CATALOG_STANDARD.md`, and
  `docs/Catalog-Format.md` updated together, same as every prior category
  change.

### Known Limitations

- None of the 60 new applications were added to any preset — same
  deliberate scope boundary as v2.3.0. All 60 are fully reachable through
  the Application Catalog browser; the Catalog Doctor's A1 advisory
  reflects this honestly (60 new "not referenced by any preset"
  suggestions, all expected).
- No `JB_PICK` was added for any new application — adding an application to
  the catalog is not a field endorsement; see CATALOG_STANDARD.md.
- Several well-known candidates from the research list were evaluated and
  rejected rather than catalogued with guessed metadata: VMware Fusion (no
  Homebrew cask; post-acquisition distribution is account-gated), Bear and
  Samsung Smart Switch (no confidently verifiable package/homepage without
  risking a stale or fabricated URL), Winbox (only an unofficial
  third-party macOS wrapper exists, not MikroTik's own product), Xerox and
  Ricoh printer software (no single canonical consumer app comparable to
  Brother/Canon/Epson/HP's, only enterprise per-model driver bundles), and
  OnlyKey/AppCrypt (maintenance status and current official homepage could
  not be confidently verified). See the engineering report for the
  complete rejection list and reasoning.

## [2.3.0] — 2026-07-28 — Catalog Evolution & Quality Standard

The catalog grows from a 30-application, 8-category package list into a
121-application, 12-category, metadata-rich library — with a written
constitution and quality standard behind it. Deployment, Presets, and
Transactions are untouched: this is catalog work, not architecture work.
See [ADR-0009](docs/architecture/0009-catalog-evolution.md) for the
reasoning behind every non-obvious call.

### Added

- `docs/CATALOG_CONSTITUTION.md` — the catalog's ten long-term principles
  (one application/one category, curated over exhaustive, prefer Homebrew,
  official names only, metadata first, and more).
- `docs/CATALOG_STANDARD.md` — the normative metadata schema: 11 required
  fields per application, the 12-category enum, the license vocabulary, and
  four new optional fields (`ALTERNATIVES`, `NOTES`, `WEBSITE`,
  `REQUIREMENTS`).
- 91 new applications across the catalog's new categories — `ai` and
  `security` most notably (previously nonexistent categories), plus new
  entries in every prior category. Every entry carries `HOMEPAGE`,
  `LICENSE`, `PACKAGE_TYPE`, and `ARCHITECTURE`, verified against the real
  local Homebrew installation wherever a formula or cask exists.
- Catalog validation rules **V10** (`PACKAGE_TYPE` must agree with
  `INSTALL_METHOD`) and **V11** (no two applications may share a `NAME` or
  `HOMEPAGE` — duplicate-application detection).

### Changed

- `ID` → `APP_ID`, `PACKAGE` → `PACKAGE_NAME` across every `app.conf` — a
  pure rename (same data, same meaning), propagated to the small, fixed set
  of Deployment call sites that read them. The installer itself needed no
  change: it never rereads the catalog.
- Category taxonomy: `hardware` + `utilities` merged into `system`;
  `device-management`, `media`, `printers-scanners` added as genuinely new
  categories. `chatgpt`, `codex`, and `antigravity` recategorized from
  `productivity`/`development` into the new `ai` category — a deliberate
  correction now that a purpose-coherent home exists for them.
- All 30 pre-existing applications migrated to the full v2.3.0 schema with
  real, verified `HOMEPAGE`/`LICENSE` data — no metadata was invented for
  applications already in the catalog.

### Fixed

- `Swifty`, listed under Development in the source request, verified via
  its actual Homebrew cask to be a password manager — catalogued under
  `security` instead, with a note explaining the correction.

### Known Limitations

- A handful of applications with no Homebrew cask/formula (FileZilla,
  DaVinci Resolve, DeepSeek, NotebookLM, Authy, printer-vendor utilities,
  a few others) are catalogued as `manual` with homepage data from general
  knowledge rather than a verified package registry; lower-confidence
  entries (`leftovers` specifically) carry an explicit `NOTES` field saying
  so rather than presenting uniform confidence across all 121 entries.
- None of the 91 new applications were added to any preset — presets were
  explicitly out of scope for this release. Every new application remains
  fully reachable through the Application Catalog browser regardless of
  preset membership; the Catalog Doctor's D1 advisory reflects this
  honestly (91 "not referenced by any preset" suggestions, all expected).
- No `JB_PICK` was added for any new application — a pick is a specific
  claim of real field experience the catalog author doesn't yet have for
  newly-added software; see ADR-0009.

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
