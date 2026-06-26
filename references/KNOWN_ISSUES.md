# JB Toolkit — Engineering Backlog, Architecture Review & Roadmap

This is the permanent engineering backlog for JB Toolkit. It is **not** a bug
tracker for user-reported incidents — it is where technical debt,
architectural follow-ups, UX gaps, and future product direction live so they
don't get lost between sessions.

This file contains **future work only**. For what has actually shipped, see
[`CHANGELOG.md`](../CHANGELOG.md) at the repo root — once an item here ships,
it moves there and is removed from this document, not duplicated in both.

Every item below was verified against the current code before being listed
or kept — nothing here is speculative, and nothing is kept just because a
previous pass listed it. This revision re-audited the prior version of this
document: two fully-resolved items were removed outright (see "Changes from
the previous revision" below), several priorities were re-sequenced, and a
significant number of new items were added after walking the actual code,
not just brainstorming.

Format per backlog item: **Title**, Category, Current behavior, Suggested
improvement, Difficulty, Priority, Risk, Notes.

## Changes from the previous revision

- **Removed** — `JB_VERSION` default mismatch (was "A1"): fixed and
  verified end-to-end in the previous session. No longer backlog material.
- **Removed** — Aggressive-profile log/profile note (was "M1"): this was a
  "watch for regressions" note about an already-fixed bug, not an open
  issue. The regression risk is now covered by the existing code comment in
  `apply_aggressive_optimization()` itself — that's the right place for it,
  not a backlog entry that will sit here stale forever.
- **Re-sequenced** — several items moved between version buckets after
  reconsidering effort vs. value for a field technician (details inline,
  search "Reprioritized").
- **Added** — thirteen new items surfaced by walking the actual
  Bootstrap/Diagnostics/Maintenance/Report/PDF/Privacy code against the
  practical needs of a technician working on a client's Mac (see each
  module section).
- **Removed (this revision)** — six items shipped in the v1.1 round and
  moved to `CHANGELOG.md`: Dry Run mode (`M6`), FileVault detection
  (`D2`), Privacy Inventory wired into Diagnostics/Report/PDF (`M2`),
  Executive Recommendations (`R3`), internet speed validation (`D4`), and
  Support Bundle generation. `M7` and `A6` were narrowed/updated rather
  than removed, since Dry Run and the new `tests/` suite only partially
  covered what those two items originally asked for.

---

## Bootstrap

### B1 — `INSTALLED_APPS_SESSION` can go stale on a failed Bootstrap run
- **Category:** Bug
- **Current behavior:** `core/bootstrap.sh` only writes
  `INSTALLED_APPS_SESSION` near the end of the script. Several earlier
  `exit 1` paths exist (no internet, Homebrew install/validation failure,
  `select_brewfile` failure, `brew bundle` failure). If Bootstrap fails on
  any of those paths, `state.env` keeps whatever `INSTALLED_APPS_SESSION`
  a *previous, successful* run left behind — a later Report would show
  "Software instalado durante esta sesión" for a session that actually
  installed nothing.
- **Suggested improvement:** Write `INSTALLED_APPS_SESSION=` (empty) once,
  early, before any failure-prone step; let the existing end-of-script
  write overwrite it with the real value on success.
- **Difficulty:** Easy · **Priority:** Low · **Risk:** Low
- **Notes:** Narrow edge case, cheap fix, directly contradicts AGENTS.md
  §4's documented guarantee.

### B2 — Homebrew migration framework is designed but not built
- **Category:** Architecture
- **Current behavior:** `core/bootstrap/MIGRATION_FRAMEWORK.md` documents
  a detect → confirm → backup → migrate flow for converting a
  manually-installed app to Homebrew-managed. Nothing implements it yet.
- **Suggested improvement:** Implement per the documented design.
- **Difficulty:** Hard · **Priority:** Medium · **Risk:** Medium
- **Notes: Reprioritized.** Previously slotted into v1.1 alongside much
  cheaper items. On reflection this is the riskiest item in that bucket —
  it touches a user's existing, working install on a client's machine, and
  "Hard" difficulty for a feature a technician will use occasionally is a
  worse trade than several "Easy" wins that get used every visit. Moved
  later in the v1.1 sequence (still v1.1, not pushed to v2.0 — it's a
  feature, not an architectural shift) so it lands after the toolkit has
  more field experience with the simpler new features first.

### B3 — Homebrew install/validation failures report generic messages
- **Category:** UX
- **Current behavior:** `install_brew()` in `core/bootstrap/brew.sh` prints
  fixed messages (`"⚠️ Homebrew no pudo instalarse correctamente"`) without
  surfacing the actual `curl` exit code or the installer's own stderr.
- **Suggested improvement:** Capture and show/log the specific failure
  reason (network timeout vs. permissions vs. corrupt download vs.
  Homebrew's own error).
- **Difficulty:** Medium · **Priority:** Medium · **Risk:** Low
- **Notes:** A technician hits this in the field with no second machine to
  debug from — high practical value for the effort.

### B4 — No Rosetta installation prompt (NEW)
- **Category:** Enhancement
- **Current behavior:** `detect_rosetta()` already exists and is already
  surfaced in `print_hardware_summary()` ("Rosetta: Instalada" / "No
  detectada") — detection and display are done. What's missing: if an
  Apple Silicon Mac doesn't have Rosetta and the user is about to install
  an Intel-only optional app (or one is already detected by
  `maintenance/apps.sh`'s Intel-only scoring), Bootstrap never offers to
  run `softwareupdate --install-rosetta --agree-to-license`.
- **Suggested improvement:** When `IS_APPLE_SILICON` and
  `! ROSETTA_INSTALLED`, offer a one-line confirm-then-install prompt
  during Bootstrap, mirroring the existing "ask, then act" pattern used
  for optional packages.
- **Difficulty:** Easy · **Priority:** Medium · **Risk:** Low
- **Notes:** Detection already exists — this is purely the missing action
  step, not a new subsystem.

### B5 — No `brew doctor` integration (NEW)
- **Category:** Enhancement
- **Current behavior:** `brew doctor` is never invoked anywhere in the
  codebase. Homebrew health (broken symlinks, permission issues, stale
  taps) is invisible to the toolkit even though it directly affects
  whether `brew bundle` will succeed.
- **Suggested improvement:** Run `brew doctor` after `validate_brew()`
  (read-only, just surface the output) — don't act on it automatically,
  just show it so a technician sees Homebrew-level problems before they
  manifest as a confusing `brew bundle` failure later in the same run.
- **Difficulty:** Easy · **Priority:** Medium · **Risk:** Low
- **Notes:** Directly related to B3 — better error reporting and `brew
  doctor` output are complementary, not redundant.

---

## Diagnostics

### D1 — Diagnostics resets `SCORE_BEFORE` to match `SCORE_AFTER`
- **Category:** Architecture
- **Current behavior:** `core/diagnostics.sh` writes both `SCORE_BEFORE`
  and `SCORE_AFTER` to the same just-computed value on every run.
  `maintenance/state.sh` also owns these same two keys. If Diagnostics runs
  *after* Maintenance and *before* Report, Report's "Score anterior vs
  Score actual" always shows "Sin cambios," even if a real improvement
  happened earlier the same day.
- **Suggested improvement — two tiers:**
  1. **Cheap, v1.0.1-safe:** Document the behavior explicitly in
     AGENTS.md §3 (already done as part of this revision — see the
     ownership table) and adjust Report's wording so "Sin cambios" isn't
     shown when the *reason* is "Diagnostics just reset the baseline" vs.
     "nothing actually changed." A one-line wording guard, not a key
     rename.
  2. **Real fix, v1.1:** Give Diagnostics its own key (e.g.
     `LAST_DIAGNOSTIC_SCORE`) instead of writing `SCORE_BEFORE`/
     `SCORE_AFTER` at all.
- **Difficulty:** Medium (tier 2) · **Priority:** Medium · **Risk:** Medium
  (tier 2 touches Report's score-diff display and the PDF status banner)
- **Notes: Reprioritized.** Split into a cheap mitigation (v1.0.1) and the
  real architectural fix (v1.1) instead of treating it as one Medium-risk
  v1.1 item — the wording fix alone removes most of the practical
  confusion at near-zero risk.

### D3 — Spotlight status lives in Maintenance, not Diagnostics (NEW)
- **Category:** Architecture
- **Current behavior:** `mdutil -s /` is checked in `core/maintenance.sh`
  (prints "✔ Spotlight operativo" before cleanup runs) — not in
  Diagnostics, which is the module that owns "what is the current system
  state." This also matters now for a reason it didn't before: M3 below
  (app-activity detection) silently falls back to bundle mtime whenever
  Spotlight indexing is off, and there is currently no user-facing signal
  anywhere explaining *why* that fallback might be happening.
- **Suggested improvement:** Move the Spotlight status check into
  Diagnostics' system-state section (where `RAM_USED_PCT`/`DISK_USED_PCT`
  already live); have Maintenance read it from `state.env` if it still
  needs it for cleanup context, rather than recomputing it.
- **Difficulty:** Easy · **Priority:** Low · **Risk:** Low
- **Notes:** Small architecture correction, not a new feature — and it
  closes the loop on M3's existing "fallback visibility" gap for free.

### D5 — No duplicate application detection (NEW)
- **Category:** Enhancement
- **Current behavior:** `maintenance/apps.sh` scores apps by size/age/
  Intel-only status, but never checks for the same app installed twice
  (e.g., "Microsoft Word" and "Microsoft Word 2019" both present, or a
  leftover `.app` copy in `~/Downloads` next to the real one in
  `/Applications`). This is a common real-world disk-space and confusion
  source on client Macs.
- **Suggested improvement:** Compare `CFBundleIdentifier` (via
  `mdls -name kMDItemCFBundleIdentifier`, the same metadata family already
  used for activity detection) across all scanned `.app` bundles; flag
  matches at different paths.
- **Difficulty:** Medium · **Priority:** Medium · **Risk:** Low (detection
  only — fits the existing "stage candidates, never auto-uninstall"
  pattern in `apps.sh`)

### D6 — No Apple Intelligence compatibility check (NEW)
- **Category:** Enhancement
- **Current behavior:** Not implemented. Would require checking macOS
  version, Apple Silicon, and a RAM threshold.
- **Suggested improvement:** Add as a Diagnostics info line once the exact
  current eligibility criteria are confirmed at implementation time (Apple
  has changed these before — don't hardcode assumed thresholds without
  verifying against current documentation when this is actually built).
- **Difficulty:** Easy · **Priority:** Low · **Risk:** Low
- **Notes:** Flagging the verification caveat explicitly so whoever
  implements this doesn't ship a stale threshold.

### D7 — No orphaned LaunchAgent detection (NEW)
- **Category:** Enhancement
- **Current behavior:** `maintenance/storage.sh`'s `scan_launch_agents()`
  lists every LaunchAgent filename — it doesn't check whether the
  LaunchAgent's owning app still exists. This requires actually parsing
  plist contents (`Program`/`ProgramArguments`), which the codebase
  currently and deliberately avoids everywhere (filename-only matching, by
  design — see `privacy.sh`'s own header comment on this exact point).
- **Suggested improvement:** Use `plutil -convert json -o -` (built into
  macOS, no new dependency) to read just the `Program`/`ProgramArguments`
  key, check if that path exists, flag if not. Still strictly read-only.
- **Difficulty:** Medium · **Priority:** Low · **Risk:** Low
- **Notes:** This is a genuine step up in parsing complexity from the
  rest of the codebase's filename-only convention — implement carefully
  and don't let plist-parsing creep into other modules that don't need it.

---

## Maintenance

### M3 — `kMDItemLastUsedDate` detection depends on Spotlight indexing
- **Category:** Documentation
- **Current behavior:** Correct, intended fallback behavior, just not
  visible to the user. See **D3** above — moving Spotlight status into
  Diagnostics largely resolves the visibility gap without touching
  `apps.sh` at all.
- **Difficulty:** Easy · **Priority:** Low · **Risk:** Low

### M7 — Aggressive profile's login-item removal doesn't check presence first
- **Category:** Bug-adjacent / UX
- **Current behavior:** **Partially addressed by Dry Run mode (v1.1
  shipped — see CHANGELOG.md).** Dry Run now shows the *candidate* list
  before acting ("Would: remover apps de inicio (Discord, Steam, Epic
  Games, Microsoft Teams, Spotify si presentes)"), but that's the same
  static, hardcoded list every time — it still doesn't check which of
  those apps are *actually* registered as login items on this particular
  Mac before showing/removing them.
- **Suggested improvement:** Query actual current login items
  (`osascript -e 'tell application "System Events" to get the name of
  every login item'`), intersect with the candidate list, and use that
  intersection both in the Dry Run preview and in the real removal. Zero
  risk change in outcome (AppleScript's `delete` is already a no-op if the
  named login item doesn't exist) — this is purely a precision fix to a
  preview/removal step that already exists.
- **Difficulty:** Medium · **Priority:** Medium · **Risk:** Low
- **Notes:** Narrower in scope now that Dry Run exists — this is no longer
  "build a preview," just "make the existing preview accurate."

### M8 — Cache classification is uniform, not differentiated (NEW)
- **Category:** Enhancement
- **Current behavior:** `cleanup.sh` treats all of `~/Library/Caches` the
  same way (age-gated, >7 days). It doesn't distinguish "cheap to rebuild"
  caches from expensive ones (e.g., Xcode `DerivedData`, which can take
  many minutes to regenerate) or show a top-N breakdown by app before
  deleting.
- **Suggested improvement:** Show a top-5-by-size breakdown before
  cleanup, and consider an explicit skip-list for known-expensive caches
  (opt-in deletion only) — but only if a real complaint surfaces; don't
  build this speculatively.
- **Difficulty:** Medium · **Priority:** Low · **Risk:** Low
- **Notes:** Conservative by design today; this is a refinement, not a
  fix to anything broken.

---

## Report

### R1 — Live RAM/Disk recalculation in `report.sh`'s console output
- **Category:** Architecture
- **Current behavior:** Self-documented `TODO(architecture)` comments
  already in `core/report.sh`. The console recalculates RAM/Disk live
  instead of consuming `state_value RAM_USED_PCT`/`DISK_USED_PCT`;
  `report_pdf.py` already does this correctly.
- **Suggested improvement:** Apply the same "prefer state.env when fresh,
  fall back to live query" guard `report_pdf.py` already implements.
- **Difficulty:** Medium · **Priority:** Low · **Risk:** Low
- **Notes: now explicitly scheduled** (previously listed but missing from
  every roadmap bucket — an oversight in the prior revision). Slotted into
  v1.1.

### R2 — `report.sh` duplicates a `fastfetch` existence check
- **Category:** Enhancement
- **Current behavior:** `report.sh` uses raw `command -v fastfetch` instead
  of the shared `command_exists` helper `diagnostics.sh` already uses.
- **Difficulty:** Easy · **Priority:** Low · **Risk:** Low

### R4 — No maintenance trend analysis (NEW)
- **Category:** Enhancement
- **Current behavior:** `maintenance_history.log` exists and is displayed
  as a flat last-5 list, but nothing synthesizes a trend from it (e.g.,
  "score has improved in 3 of the last 5 runs").
- **Suggested improvement:** A one-line trend summary computed from the
  same 5 entries already being read — still "read, don't recalculate,"
  since the raw scores are already in the file.
- **Difficulty:** Easy · **Priority:** Medium · **Risk:** Low

### R5 — No Technician Notes section (NEW)
- **Category:** Enhancement
- **Current behavior:** No mechanism for a technician to add a short
  free-text note (what was observed/done) that flows into the PDF.
- **Suggested improvement:** An optional prompt in `report.sh` before PDF
  generation; pass through via the same environment-variable bridge
  pattern already used for `JB_APP_INVENTORY`/`JB_INSTALLED_APPS_SESSION`.
- **Difficulty:** Easy · **Priority:** Medium · **Risk:** Low
- **Notes:** High practical value for JB Repair's actual client-facing
  workflow — a generic report reads as automated; a one-line technician
  note makes it feel like a real service record.

---

## PDF

### P1 — `reportlab` is installed with no version pin
- **Category:** Enhancement · **Difficulty:** Easy · **Priority:** Low ·
  **Risk:** Low
- **Current behavior / improvement:** unchanged from previous revision —
  pin a known-good `reportlab` version in `ensure_pdf_python()`.

### P2 — `.venv` creation failure gives no specific diagnostic
- **Category:** UX · **Difficulty:** Easy · **Priority:** Low ·
  **Risk:** Low
- Unchanged from previous revision.

### P3 — No score visualization, only colored text (NEW)
- **Category:** UX
- **Current behavior:** The health score is shown as large colored text
  (green/yellow/red), not a graphic. No gauge/donut chart.
- **Suggested improvement:** A simple gauge or bar using ReportLab's own
  drawing canvas (`reportlab.graphics.shapes`) — no new dependency needed,
  confirmed available in the existing `reportlab` install.
- **Difficulty:** Medium · **Priority:** Low · **Risk:** Low

### P4 — No branding: logo, typography, client info, QR code (NEW)
- **Category:** UX
- **Current behavior:** PDF uses ReportLab's default styles
  (`getSampleStyleSheet()`), no JB Repair logo, no client/machine
  information section, no QR code.
- **Suggested improvement, broken into independent pieces:**
  - **Logo:** conditional `Image` flowable if a logo file is present in
    the repo — Easy, Low risk.
  - **Typography:** custom `ParagraphStyle` palette matching JB Repair's
    brand — Easy, Low risk.
  - **Client information section:** name/machine identifier/date —
    requires new technician-entered input (or serial-number detection via
    `system_profiler SPHardwareDataType`, not currently collected
    anywhere) — Medium, Low risk.
  - **QR code linking to JB Repair:** confirmed `reportlab.graphics.
    barcode.qr` is already available in the existing `reportlab`
    dependency — **no new dependency required.** Easy, Low risk.
- **Difficulty:** Medium overall (Easy per sub-piece) · **Priority:**
  Medium · **Risk:** Low
- **Notes:** This is the PDF's single biggest opportunity to look like a
  real business document instead of a generic script output — high value
  for a client-facing artifact, and confirmed technically cheap.

---

## Documentation

### DOC1 — `.codex/skills/jb-toolkit/references/*.md` predate several shipped features
- **Category:** Documentation · **Difficulty:** Easy (pointer) / Medium
  (full refresh) · **Priority:** Low · **Risk:** Low
- Unchanged from previous revision — add a pointer to AGENTS.md as the
  canonical source, or do a full refresh. Does not touch `core/docs.sh` or
  `references/tools/*` (the actual Documentation module).

---

## Homebrew

*(B2/B3/B4/B5 above, filed under Bootstrap since that's where the
Homebrew install/validation code lives.)*

---

## Privacy

### PRIV1 — Detection is filename-pattern-based only
- **Category:** Architecture (documented limitation, not a defect)
- Unchanged from previous revision — add `defaults` domain checks and
  process-name checks as a second signal, still detection-only.
- **Difficulty:** Medium · **Priority:** Low · **Risk:** Low

### PRIV2 — No Apple-specific analytics/diagnostics detection (NEW)
- **Category:** Architecture / Future Feature
- **Current behavior:** `privacy.sh` deliberately excludes
  `/System/Library` and covers third-party vendors only (Google,
  Microsoft, Adobe, Zoom). Apple's own analytics/diagnostics sharing
  (the System Settings → Privacy & Security → Analytics toggle and
  related `DiagnosticMessagesHistory`/`SubmitDiagInfo`-style preferences)
  has no equivalent detection today.
- **Suggested improvement:** Detection only, exactly like the rest of
  `privacy.sh` — read the relevant preference domain(s) via `defaults
  read`, report Detected/Not Detected with the same honest, no-action
  posture. **Implementation note:** verify the exact current preference
  domain/key names at build time rather than assuming — Apple's internal
  naming for this has shifted across macOS versions, and `privacy.sh`'s
  own stated principle ("never assert more precision than the pattern
  match supports") applies here more than anywhere else, since this is
  preference-based, not filename-based.
- **Difficulty:** Medium · **Priority:** Medium · **Risk:** Low (detection
  only, no disabling — confirmed in scope per this task's instructions)
- **Notes:** This directly answers the "Apple analytics" detection target
  requested for this round of planning. Microsoft/Adobe/Google telemetry
  detection already exists (via LaunchAgent patterns) — this is the one
  vendor category with a genuine gap, because Apple's own services don't
  register user-visible LaunchAgents the way third-party updaters do.

---

## Architecture

### A2 — `SCORE_BEFORE`/`SCORE_AFTER` ownership overlap
- See **D1** above.

### A3 — Duplicated `human_size()` definition (NEW)
- **Category:** Bug-adjacent (latent, not currently causing wrong output)
- **Current behavior:** `human_size()` is defined identically in both
  `core/maintenance/apps.sh` and `core/maintenance/storage.sh`.
  `maintenance.sh` sources `apps.sh` before `storage.sh`, so `storage.sh`'s
  definition silently wins — `apps.sh`'s copy is currently dead code that
  happens to match. If the two definitions are ever edited independently
  and drift apart, whichever one "wins" by source order changes silently
  and disk-size displays could become inconsistent between the two
  modules with no warning.
- **Suggested improvement:** Move `human_size()` to `core/utils.sh` (it's
  a pure formatting helper, fits naturally alongside `format_ram`-style
  helpers already conceptually similar in `report_pdf.py`); have both
  `apps.sh` and `storage.sh` call the shared one.
- **Difficulty:** Easy · **Priority:** Medium · **Risk:** Low (mechanical
  consolidation, output format is byte-identical between the two current
  copies — verified by direct comparison)
- **Notes:** Found during this audit's architecture pass, not a
  previously-known item. Cheap, safe, worth doing in v1.0.1.

### A4 — Report reaches into Bootstrap's internals (NEW)
- **Category:** Architecture
- **Current behavior:** `core/report.sh` sources
  `core/bootstrap/hardware.sh` and `core/bootstrap/packages.sh` directly
  to reuse `compute_hardware_recommendations()` and the
  `OPTIONAL_PACKAGE_IDS`/`HARDWARE_RECOMMENDED_IDS`/`package_app_bundle_name()`
  catalog — explicitly to avoid duplicating detection logic, which is the
  right instinct. But the result is that Bootstrap's internal global
  arrays and functions are now a de facto cross-module API, without ever
  having been designed as one.
- **Suggested improvement:** Extract the package catalog + bundle-name
  table + hardware-recommendation engine into a neutral module (e.g.
  `core/catalog.sh`) that both `bootstrap/packages.sh` and `report.sh`
  depend on symmetrically, instead of Report depending on Bootstrap.
- **Difficulty:** Medium · **Priority:** Low (today) → **rises over time**
  · **Risk:** Medium (touches both Bootstrap's install flow and Report's
  inventory sections — needs careful regression testing of both, not a
  quick move)
- **Notes:** Not urgent — it works correctly today and the coupling is at
  least documented in code comments, not silent. Flagged now because it's
  exactly the kind of thing that's cheap to fix while there are two
  consumers and expensive once there's a third (see Product Vision /
  client-database direction below, which would likely want this same
  catalog data too).

### A5 — `core/bootstrap/packages.sh` has outgrown a single responsibility (NEW)
- **Category:** Architecture
- **Current behavior:** At 732 lines, this is the largest shell file in
  the project. It currently covers: Brewfile filtering, the optional-app
  catalog, the hardware-recommendation engine, the manual-install
  bundle-name table, external/outdated-package tracking, install
  verification, and app-inventory printing — at least six distinct
  responsibilities.
- **Suggested improvement:** Split along those natural seams (e.g.
  `catalog.sh`, `verification.sh`, `external_packages.sh`) before the file
  grows further. Cheap today; expensive once it doubles again.
- **Difficulty:** Medium · **Priority:** Low · **Risk:** Low (pure
  reorganization, no behavior change, if done carefully with `source`
  order preserved)
- **Notes:** Not an emergency. Listed so it's tracked *before* it becomes
  a 1,200-line file that nobody wants to touch.

### A6 — Test coverage foundation laid; package-catalog and `((var++))` regression tests still missing
- **Category:** Architecture
- **Current behavior:** **Partially addressed (v1.1 shipped).** A minimal
  `bats-core` suite now exists under `tests/`, runnable via `make test` or
  `./tests/run.sh` (`CLAUDE.md` and `references/HOMEBREW_TAP.md` updated
  accordingly). It covers `state_value`/`write_state_values`'s
  atomic-replace behavior, `detect_app_state()`'s output contract,
  `calculate_health_score()` — including a direct regression test for the
  subshell-cache bug — and the `JB_VERSION` single-source-of-truth rule.
  Still missing: a test that `OPTIONAL_PACKAGE_IDS`/`LABELS`/`CATEGORIES`
  in `core/bootstrap/packages.sh` stay index-aligned, and a direct
  regression test for the `((var++))`-under-`errexit` footgun class
  itself (distinct from the subshell bug already covered).
- **Suggested improvement:** Add `tests/packages.bats` (array-alignment
  check) and a small, deliberately-synthetic `((var++))`-under-`set -e`
  regression test (can run in an isolated subshell so it doesn't affect
  the rest of the suite if it ever fails for real).
- **Difficulty:** Easy · **Priority:** Medium · **Risk:** Low
- **Notes:** No CI wiring yet, by design (v1.1 was "start small"). Wiring
  `make test` into CI is natural follow-up once the suite has grown a bit
  more — tracked here rather than assumed.

---

## Future Features

Net-new capabilities not yet scheduled to a specific version below them in
priority terms, or whose scope is still being shaped by the Product Vision
discussion. See Roadmap for what's actually committed to a version.

- **Time Machine verification** — read-only check of last successful
  backup time/destination health.
- **SMART history** — track `smartmontools` results over time, reusing the
  `maintenance_history.log`-style flat-file pattern for a new domain.
- **OneDrive / Office diagnostics** — read-only sync-status and
  licensing-state checks.
- **Backup reminder before aggressive maintenance** — non-blocking
  reminder in the aggressive-profile confirmation flow.
- **Historical Health Score charts** — needs a charting-capable PDF
  pipeline and likely a richer history format; v2.0-scale.

---

# Product Vision

JB Toolkit today is a single-technician, single-machine, file-based CLI
tool, run from a git checkout. That's the right shape for what it is now.
The question for this section is which of the "real product" directions
actually fit a small, in-person Mac repair business — and which would be
solving a problem JB Repair doesn't have.

## Recommended near-term (fits naturally, low risk)

- **Homebrew Tap.** `brew tap jbrepair/jb-toolkit && brew install
  jb-toolkit` is the idiomatic distribution method for exactly this kind
  of tool, and it fits the project's existing deep Homebrew-centric design
  philosophy better than a custom installer would. Recommended as the
  primary distribution mechanism going forward. **Readiness audit done —
  see `references/HOMEBREW_TAP.md`.** Five concrete prerequisites were
  found (symlink path resolution, a missing non-interactive `--version`
  flag, moving `logs/`/`state.env`/`.venv` to a per-user writable
  directory, version-bump process discipline, and `fastfetch` becoming a
  formula dependency) — none implemented yet, all scoped in that document.
- **Signed installer/package** — secondary to the Tap, useful for a
  technician's first-ever setup on a brand-new machine before Homebrew
  itself is even installed. Worth having, not worth building first.
- **Automatic updates — scoped narrowly.** Should apply only to the
  technician's own working copy of the toolkit, never silently to
  anything on a client's Mac mid-session. A simple "new version available"
  check (comparing against the Tap/repo) is enough; auto-applying updates
  to a tool that's mid-way through diagnosing someone else's computer is
  the wrong default.
- ~~Support bundle generation.~~ **Shipped (v1.1) — see CHANGELOG.md.**

## Worth pursuing, but as v2.0-scale architecture (start small)

- **Client database / multi-machine inventory.** Genuine long-term value
  for a repair business — "we've serviced this Mac three times this year,
  here's the trend" is a real differentiator. But start with a local,
  per-technician flat-file or SQLite registry keyed by Mac serial number,
  **not** a hosted multi-tenant service. A hosted service changes JB
  Repair's business into also operating a SaaS product, with real data
  -handling obligations for client diagnostic data — that's a business
  decision, not just an engineering one, and shouldn't be backed into via
  incremental feature requests.

## Recommended against, or conditional only

- **Remote Support mode — not recommended as a from-scratch build.**
  The Brewfile already includes RustDesk, a mature, audited, open-source
  remote-desktop tool, specifically in the Repair/Diagnostics category.
  Building competing remote-access infrastructure inside JB Toolkit would
  mean taking on real security and maintenance burden to duplicate
  something already solved and already in the toolchain. If the actual
  need is "let me triage a Mac I can't physically touch," the right
  answer is tighter integration with the existing RustDesk install (e.g.,
  a one-click way to generate a RustDesk session ID alongside a support
  bundle) — not a parallel remote-control feature.
- **Plugin architecture — not justified yet.** A plugin system implies a
  stable, versioned extension API for contributors outside the core team.
  JB Toolkit is currently a single-business internal tool with no outside
  contributors. Building this now would be designing for a hypothetical
  audience that doesn't exist — exactly what this project's own coding
  philosophy (CLAUDE.md) already warns against. Revisit only if JB
  Toolkit's audience genuinely expands beyond JB Repair itself (e.g.,
  other shops adopting it) — that would be a business-model change worth
  re-evaluating the technical decision against, not a technical decision
  made in isolation.

---

# Architecture Review — supporting the next several years

(Summary — see individual items A3–A6 above for specifics.)

- **Duplicated logic:** one confirmed case today (`human_size()`, A3).
  Small, cheap, worth fixing now rather than letting it drift.
- **Hidden/cross-module coupling:** Report depending on Bootstrap's
  internal catalog arrays (A4) — functional today, but the kind of
  shortcut that gets expensive with a third consumer. The Product
  Vision's client-database direction would likely want this same catalog
  data, which makes extracting it sooner rather than later more valuable,
  not less.
- **Modules outgrowing a single responsibility:** `bootstrap/packages.sh`
  at 732 lines covers at least six distinct concerns (A5). Not urgent, but
  the cheapest time to split a file is before it doubles again.
- **State management scaling:** the `state.env` + per-feature flat-history-file
  pattern (established by `maintenance_history.log`) works and should be
  the template for SMART history, network-diagnostics trends, etc. — but
  formalize it as a tiny shared helper in `utils.sh` now, rather than
  letting every new feature reinvent `mkdir -p && printf >> file`
  independently.
- **Bash as the implementation ceiling:** the toolkit is well-organized
  Bash for what it does today, but the Product Vision's client-database /
  multi-machine / charting directions are exactly the kind of work Bash is
  a poor fit for (no real data structures, awkward JSON, no SQL). When
  that work starts, the natural move is a small, deliberately-scoped
  Python component for just the data-management layer — Python is already
  a dependency via `report_pdf.py`'s `.venv` — while keeping all direct
  macOS system interaction in Bash, where it's genuinely well-suited. Not
  "rewrite the toolkit," a clean boundary at the right seam.
- **Test coverage (A6, repeated here because it matters most):** zero
  automated tests today, and this project's own history shows that exact
  gap has already caused multiple real, silent regressions. This is the
  one recommendation in this entire document that should be treated as
  more urgent than it might look on a difficulty/priority grid — it's
  infrastructure that makes every other recommendation here safer to
  implement.

---

# Roadmap

## v1.0.1 — Polish & Bug Fixes

Goal: tighten what already shipped. Cheap, safe, immediately useful to a
technician in the field. No architecture changes.

| Item | Source |
|---|---|
| Fix `INSTALLED_APPS_SESSION` staleness on failed Bootstrap runs | B1 |
| Better Homebrew install/validation error reporting | B3 |
| `brew doctor` integration after Homebrew validation | B5 |
| Rosetta installation prompt (detection already exists) | B4 |
| Move Spotlight status check into Diagnostics | D3 |
| Wording fix for the `SCORE_BEFORE`/`SCORE_AFTER` "Sin cambios" confusion | D1 (tier 1) |
| Pin `reportlab` version | P1 |
| Surface specific `.venv` creation failure reason | P2 |
| `report.sh`: reuse `command_exists` for fastfetch | R2 |
| Consolidate duplicated `human_size()` into `utils.sh` | A3 |
| Add a pointer from stale `.codex/skills/jb-toolkit/references/*.md` to AGENTS.md | DOC1 |

*(`D2` FileVault, `M2` privacy entry point, `D4` internet speed, `R3`
Executive Recommendations, `M6` Dry Run, and Support Bundle generation
were originally slotted here/in v1.1 but shipped ahead of schedule in
this v1.1 round — see `CHANGELOG.md`. `R4` maintenance trend analysis was
attempted but descoped to a future pass; still listed under Report above.)*

## v1.1 — Medium Improvements

Goal: round out diagnostics/maintenance/report with genuinely new
capability. Still no fundamental architecture change.

- Make the aggressive profile's login-item preview check actual presence,
  not just show the static candidate list (M7 — narrowed; Dry Run preview
  already shipped)
- Technician Notes section in Report/PDF (R5)
- PDF branding: logo, typography, client info section, QR code (P4)
- Duplicate application detection (D5)
- Apple Intelligence compatibility check (D6)
- Orphaned LaunchAgent detection (D7)
- Live RAM/Disk recalculation fix in `report.sh` console output (R1)
- `SCORE_BEFORE`/`SCORE_AFTER` real fix — dedicated Diagnostics key (D1 tier 2)
- Expand `privacy.sh`: Apple analytics/diagnostics detection (PRIV2)
- Expand `privacy.sh`: `defaults`-domain/process-name signals (PRIV1)
- Maintenance trend analysis — synthesize a trend sentence from the
  history already shown (R4)
- Continue expanding test coverage: package-catalog array-alignment test,
  `((var++))`-under-`errexit` regression test (A6)
- Homebrew Tap implementation, following the readiness audit in
  `references/HOMEBREW_TAP.md` (Product Vision) — the audit is done, the
  five prerequisites it lists are not
- Homebrew migration assistant (B2) — sequenced **last** in this release;
  see B2's note on why it's deprioritized relative to the rest of this list

*(Shipped ahead of schedule this round, no longer listed above — see
`CHANGELOG.md`: Dry Run mode (M6), Executive Recommendations (R3),
Privacy Inventory wired into Diagnostics/Report/PDF (M2 + PRIV — Google/
Microsoft/Adobe/Zoom only, PRIV2's Apple-specific detection is still
open), FileVault detection (D2), internet speed validation (D4), and
Support Bundle generation.)*

## v2.0 — Major Architectural Changes

Goal: capabilities that change what kind of tool JB Toolkit *is* — and the
architecture cleanup that should happen alongside them, not after.

- Extract the shared package/hardware catalog out of Bootstrap (A4) —
  do this *as part of* building client-database support, since that
  feature will want the same catalog data Report already borrows
- Split `bootstrap/packages.sh` along its natural seams (A5)
- Client database / local multi-machine inventory (Product Vision —
  start small: local file/SQLite, not a hosted service)
- Historical Health Score charts (needs the richer history format this
  implies)
- Scoped automatic-update mechanism for the technician's own install
  (Product Vision — never auto-applies to a client Mac)
- Signed installer/package as a secondary distribution path

## v3.0 — Only If Justified

Not committed. Listed only because the task asked whether anything
belongs here, and being honest about that means saying "not yet" for most
of it.

- **Remote diagnostics / remote support infrastructure** — only if JB
  Repair's business genuinely grows multi-technician/multi-location *and*
  there's a demonstrated gap that integrating with the already-installed
  RustDesk (see Product Vision) doesn't cover. Not a default next step.
- **Plugin architecture** — only if JB Toolkit's user base expands beyond
  JB Repair itself. Until then, this would be designing for an audience
  that doesn't exist.
- **Hosted/multi-tenant client database** — only as a deliberate evolution
  of the local-file v2.0 version above, once there's real multi-technician
  or multi-location demand, and only with an explicit decision about the
  data-handling/liability questions that come with hosting client
  diagnostic data for other businesses.
