# Future Roadmap

This document separates what **exists today** from what is **planned**, and records
known inconsistencies for future consideration. Planned items are goals, not
designs — no implementation details are prescribed here.

## Implemented today (v0.9)

- Interactive launcher with four modules: Bootstrap, Diagnostics, Maintenance, Report
- Homebrew lifecycle: install, validate, index refresh, Brewfile sync with
  architecture variants, session-level query caching with post-mutation invalidation
- Optional-package catalog with interactive multi-select and range syntax (`1,3-5`)
- Hardware-based package recommendations by machine family
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

| Goal | Intent |
|---|---|
| **Deployment system** | Push complete configurations to a prepared Mac in one operation |
| **Reusable Bundles** | Named package/config groups that can be applied as units |
| **Workstation Profiles** | Role-based machine definitions (e.g., office, creative, dev) composed of bundles |
| **JB Picks** | Curated recommended-apps catalog maintained by JB Repair |
| **Application Catalog** | Structured metadata for installable apps beyond the flat Brewfile |
| **Plugin-like architecture** | Third-party/module extension points without touching core |
| **Cross-platform readiness** | Isolate macOS-specific calls so future non-macOS targets are feasible |
| **Improved reporting** | Richer PDF, historical trends, comparison between visits |

Architectural note for implementers: the existing seams for this work are the
Brewfile-variant selection (`select_brewfile`), the optional-package catalog arrays
(`OPTIONAL_PACKAGE_IDS`/`LABELS`), and the machine-family recommendation matrix.
Bundles/profiles should generalize these, not bypass them.

## Potential Future Improvements

Known inconsistencies, documented per policy **without changing the design**. None
are release blockers; several were consciously accepted.

1. **`ui.sh` location.** The UI layer for all modules lives under `core/bootstrap/`.
   A future move to `core/ui.sh` would match its actual role; deferred because the
   churn touches every module for zero behavior change.
2. **Banner version string.** `print_banner` hardcodes `v0.9` in the format string
   while `JB_VERSION` exists in utils.sh. A version bump currently requires touching
   both.
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
