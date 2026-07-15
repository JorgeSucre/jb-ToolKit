# Future Roadmap

This document separates what **exists today** from what is **planned**, and records
known inconsistencies for future consideration. Planned items are goals, not
designs — no implementation details are prescribed here.

## Implemented today (v2.0.1)

- Interactive launcher with five modules: Bootstrap, Diagnostics, Maintenance, Deployment, Report
- Workstation deployment: catalog-driven profiles/bundles with the generic
  `INSTALL_METHOD` model (brew/cask automated; mas/pkg/dmg/manual as first-class
  manual steps), interactive bundle review (install all / customize per app /
  skip), read-only pre-flight validation, per-application resilient installation
  with verified outcomes, Deployment Planner with plan export, JB Picks browser,
  Catalog Doctor, Installation Transaction records with per-category named
  outcomes and failure reasons
- Bootstrap as an onboarding wizard over the Deployment library: base tools (CLT,
  Homebrew, verified fastfetch), pending-update offer, hardware detection, one
  catalog-generated question, then the shared planner and installer
- Homebrew lifecycle: install, validate, index refresh, session-level query
  caching with post-mutation invalidation
- Hardware-based package recommendations by machine family, encoded as catalog
  data (`HW_RECOMMEND`)
- Health score (CPU / RAM / disk) with baseline tracking across runs
- Preview-confirm cleanup with **confirmed** (re-counted) deletion accounting
- Storage analysis: large files, cloud-sync detection, LaunchAgents listing
- App risk scoring (architecture, size, staleness) with user-driven Trash moves
- Performance profiles: light, aggressive (superset of light), restore-defaults
- Session logging with full command/output/exit capture; artifact retention
- System snapshot inventory per session
- Terminal executive report and client-facing PDF (reportlab)
- Independent release-readiness audit completed; blocking findings fixed

## Planned (not implemented — do not document as existing)

| Goal | Intent | Status |
|---|---|---|
| **Deployment history** | Browse past Installation Transactions | Records exist (`logs/deployment_txn_*.env`); `history.sh` browser pending |
| **Automated `mas`/`pkg`/`dmg` installs** | Extend the engine beyond brew/cask | Catalog and plan already carry the method; only the execution branch in `install.sh` is missing |
| **Vendor presets** | Per-organization compositions of profiles | Reserved space only (`catalog/vendors/`) — not designed yet |
| **Plugin-like architecture** | Third-party/module extension points without touching core | Idea only |
| **Cross-platform readiness** | Isolate macOS-specific calls so future non-macOS targets are feasible | Idea only |
| **Improved reporting** | Richer PDF, historical trends, comparison between visits | Idea only |

Architectural note for implementers: the installation engine is the per-application
pattern in `core/deployment/install.sh` (`retry 3 5 run_cmd --visible brew install
[--cask]` + post-run verification) — Deployment resolves data and orchestrates;
nothing else in the toolkit installs software. New installation methods extend the
engine's `method` branch, never bypass it.

## Potential Future Improvements

Known inconsistencies, documented per policy **without changing the design**. None
are release blockers; several were consciously accepted.

1. **`ui.sh` location.** The UI layer for all modules lives under `core/bootstrap/`.
   A future move to `core/ui.sh` would match its actual role; deferred because the
   churn touches every module for zero behavior change.
2. **Banner version string.** ~~`print_banner` hardcodes the version~~ Resolved in
   v2.0.1: the banner renders `$JB_VERSION`; a version bump touches only utils.sh.
3. **Strict-mode inconsistency.** `bootstrap.sh` and `report.sh` use
   `set -Eeuo pipefail`; `maintenance.sh` omits `-e` (a failing cleanup step must not
   abort the run — arguably intentional); `diagnostics.sh` omits `-u`. Worth unifying
   deliberately, with the differences documented where they are intentional.
4. **`STATE_FILE` defined in three places.** utils.sh exports it; `bootstrap.sh` and
   `maintenance/state.sh` re-assign the identical value. Harmless today; a drift risk
   if `logs/` ever moves.
5. **Aggressive-profile tweaks on modern macOS.** The Siri `defaults` keys and the
   System Events login-item removal are legacy APIs: on macOS 13+ they execute
   successfully but affect nothing (audit findings F-05/F-06). The code still serves
   older systems; the summary lines could be conditioned on macOS version so the
   claims stay strictly truthful everywhere.
6. **Trash "elementos" counting.** The Trash counter counts top-level entries
   (including directories) while the size estimate counts files only (F-09).
   Cosmetic; the wording "elementos" was chosen to be accurate.
7. **Accepted duplications.** The RAM calculation (score vs report) and per-module
   architecture checks are deliberate — consolidation was evaluated and rejected
   because it added more code than it removed. Documented in
   [Design-Principles.md](Design-Principles.md); revisit only if a third consumer
   appears.
8. **README module-execution guidance.** The README instructs users to always start
   via `./jb`, while every module also supports standalone execution with a fallback
   session (`init_session` guard). Both are true; the README could acknowledge the
   standalone path as a developer/debugging affordance.
