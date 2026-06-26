# Changelog

All notable changes to JB Toolkit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The project follows [Semantic Versioning](https://semver.org/) (SemVer).

## [Unreleased]

### Added

### Changed

### Fixed

### Removed

### Security

---

## [1.1.0] - 2026-06-26

Second stable release focused on robustness, diagnostics, reporting, and technician workflow.

### Added

- Dry Run mode for Bootstrap and Maintenance: a confirmation prompt lets a
  technician preview every action ("Would remove: ...", "Would disable:
  ...", "Would install: ...") with nothing actually modified, fixed,
  installed, or deleted. Backed by one shared mechanism (`core/utils.sh`)
  so every module — current and future — honors the same flag.
- FileVault status detection (Enabled/Disabled/Unknown) in Diagnostics,
  shown in the console report and the PDF. Detection only — never enables
  or disables FileVault.
- Privacy Inventory wired into Diagnostics, Report, and the PDF: the
  existing detection-only `privacy.sh` module (Google Keystone, Microsoft
  Office, Adobe, Zoom) is now computed once per Diagnostics run and
  displayed everywhere downstream, instead of sitting unreachable from
  normal use.
- Executive Recommendations ("Overall Recommendation") in the console
  report and PDF: up to 5 prioritized, plain-language action items with a
  priority rating, synthesized entirely from data already collected by
  Diagnostics/Maintenance — no new system queries.
- Support Bundle generation in Report: bundles the current session log,
  `state.env`, system snapshot, and the latest PDF (if available) into a
  single zip for sharing with a colleague or support ticket.
- Optional internet speed test in Diagnostics (download/upload/latency via
  `networkQuality`, built into macOS) — always opt-in, never automatic,
  and not re-run if a result is already available without asking first.
- A minimal automated test suite (`bats-core`) under `tests/`, runnable
  via `make test` or `./tests/run.sh`, covering state persistence,
  application-state detection, health-score calculation, and the
  `JB_VERSION` single-source-of-truth rule.
- `references/HOMEBREW_TAP.md`: a readiness audit for distributing JB
  Toolkit via a Homebrew Tap — no functional changes, audit only.

### Changed

### Fixed

### Removed

### Security

---

## [1.0.0] - 2026-06-23

First stable release.

### Added

- Executive PDF report covering health score, hardware summary, and
  maintenance results, rendered through a dedicated, automatically-managed
  Python virtual environment so it no longer depends on (and can't be
  blocked by) the system's or Homebrew's Python installation.
- Maintenance history: every completed Maintenance run is recorded
  (timestamp, profile, score) and the last 5 runs are shown in both the
  console report and the PDF.
- Session installation tracking: Bootstrap records which applications were
  actually installed during a session (never already-installed or failed
  ones) and Report shows them in a dedicated section.
- Bootstrap now verifies each selected package's installation individually
  after `brew bundle` runs, instead of trusting a single overall
  success/failure result.
- Homebrew vs. manual application detection: reports now distinguish
  between apps installed via Homebrew, installed manually, or available
  through the App Store, instead of assuming Homebrew is the only source.
- Real application-usage detection: stale-application warnings now prefer
  actual last-opened information (via Spotlight metadata) over file
  modification time, and only fall back to modification time when usage
  data isn't available.
- Privacy inventory module (detection only): a read-only check for known
  background update/telemetry services from Google, Microsoft, Adobe, and
  Zoom. Reports Detected/Not Detected with the exact item found — it never
  disables or removes anything.
- WhatsApp and Telegram added to the optional application catalog, the
  Bootstrap selection menu, and the Technical Reference Library.
- Technical Reference Library: an offline, per-tool documentation browser
  with categories, search, and hardware-based recommendations, reachable
  from the main menu and from Bootstrap before installing an app.
- Hardware-aware recommendations: Bootstrap suggests tools (AlDente, Macs
  Fan Control, BetterDisplay, etc.) based on the detected Mac model,
  architecture, and whether an external display is connected.
- Rosetta detection during Bootstrap, shown in the hardware summary on
  Apple Silicon Macs.
- Session logging and system snapshots: every run produces one session log
  and one system snapshot, which Report reuses instead of re-querying the
  system.

### Changed

- Bootstrap split into focused modules (UI, Homebrew, hardware detection,
  package handling, stage/progress display) instead of one large script.
- Optional application selection consolidated into a single numbered
  multi-select menu, replacing multiple per-category prompts.
- Report's executive summary reworked for clarity: humanized RAM/disk
  figures, a formulas/casks breakdown for Homebrew, and removal of
  debug/timestamp noise from the output.
- PDF generation consolidated into a single prompt owned by Report.
- Application risk/staleness wording made more honest: results now say
  "no recent activity" or "no recent changes" depending on what was
  actually measured, instead of asserting an app was forgotten when only
  file-modification time was available.

### Fixed

- Fixed Maintenance silently reporting success after an internal failure,
  caused by a shared command-output helper leaving strict error-checking
  permanently enabled for the rest of the run.
- Fixed the Aggressive performance profile being recorded as "Light" in
  reports — it reuses the Light profile's setup step internally but wasn't
  restoring its own profile name afterward.
- Fixed RAM and disk usage percentages being persisted as `0` after
  running Diagnostics, caused by a health-score calculation losing its
  cached values inside a subshell.
- Fixed PDF generation failing on systems where Homebrew's or the
  system's Python refuses package installs ("externally-managed
  environment"); PDF dependencies now install into a private,
  toolkit-owned virtual environment instead.
- Fixed a duplicate PDF-generation prompt appearing in some flows.
- Fixed CPU brand detection on Apple Silicon (M1/M2).
- Fixed the health score shown in the console and in the PDF report being
  out of sync with each other.

---

## Versioning Policy

JB Toolkit follows [Semantic Versioning](https://semver.org/)
(`MAJOR.MINOR.PATCH`). Use the kind of change to decide which part to bump —
not how large the diff looks.

- **Patch** (e.g. `1.0.1`) — safe to install without re-reading anything.
  - Bug fixes
  - Wording improvements (console, report, or PDF text)
  - Documentation updates
  - Diagnostics corrections (a check that was wrong, not a new check)
- **Minor** (e.g. `1.1.0`) — new capability, nothing existing breaks.
  - New maintenance modules
  - New documentation/reference entries
  - Additional diagnostics (a genuinely new check)
  - New supported applications (Bootstrap catalog, Brewfile)
- **Major** (e.g. `2.0.0`) — a technician's existing habits/scripts around
  the toolkit may need to change.
  - Architecture redesigns (module boundaries, state format)
  - Incompatible CLI changes (flags, prompts, menu structure)
  - A new plugin system
  - Breaking workflow changes

Planned and proposed future work lives in
[`references/KNOWN_ISSUES.md`](references/KNOWN_ISSUES.md), not in this
file. This file only records what has actually shipped.

---

## Changelog Maintenance Guidelines

Every commit merged into `main` should update the `[Unreleased]` section
above — not just the commit that eventually cuts a release. Treat it the
same way you'd treat updating a test: part of the change, not a follow-up.

Pick the heading by what changed, not by how the commit is titled:

| Change                                            | Heading        |
| ------------------------------------------------- | -------------- |
| New feature                                       | `### Added`    |
| Behavior change to something that already existed | `### Changed`  |
| Bug fix                                           | `### Fixed`    |
| Removed functionality                             | `### Removed`  |
| Security improvement                              | `### Security` |

A few concrete examples, scoped to this project: a new diagnostics check is
`Added`; correcting a check that was already there is `Fixed`; reworking
wording or reordering a flow is `Changed`; dropping a deprecated menu option
is `Removed`; tightening a permission or hardening a dependency is
`Security`. Only add a `### Security` heading to an entry when there's a
real item for it — see Objective 1's note below; don't add it as boilerplate.

If a change doesn't affect anyone using the toolkit (internal refactor, test
infrastructure, CI), it's fine to skip the changelog — this file documents
user-visible history, not every commit.

---

## Release Workflow

This is the official process for cutting a JB Toolkit release:

1. Develop on `main`, updating `[Unreleased]` as changes land (see
   Changelog Maintenance Guidelines above).
2. Before release, review `[Unreleased]` for accuracy — every line should
   describe something a technician would actually notice, written the way
   it appears elsewhere in this file.
3. Decide the version number using the Versioning Policy above.
4. Move everything under `[Unreleased]` into a new
   `## [x.y.z] - YYYY-MM-DD` section (copy the structure from
   "Future Release Template" below), dropping any empty headings.
5. Create the git tag (`vX.Y.Z`) on the commit that includes the updated
   changelog.
6. Push the tag.
7. Publish the GitHub Release using that version's changelog section as
   the release notes — **this file is the source for GitHub Release
   notes**, not a separate write-up.
8. Recreate an empty `[Unreleased]` section (all five headings, no
   content) at the top, ready for the next round of changes.

---

## Future Release Template

Copy this block when cutting a new release (step 4 of the Release Workflow
above). It's an HTML comment so it never renders — delete unused headings
once the real entries are filled in.

<!--
## [1.x.x] - YYYY-MM-DD
### Added
### Changed
### Fixed
### Removed
### Security
-->
