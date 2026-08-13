# Future Roadmap

This document separates what **exists today** from what is **planned**, and records
known inconsistencies for future consideration. Planned items are goals, not
designs — no implementation details are prescribed here.

## Implemented today (v2.5.0)

- Interactive launcher with five modules: Bootstrap, Diagnostics, Maintenance, Deployment, Report
- Workstation deployment: a flat `Catalog → Applications → Selected
  Applications → Installation Plan → Execution` model (no bundle/profile
  grouping layer — see [architecture/0006-deployment-flattening.md](architecture/0006-deployment-flattening.md)).
  Presets are predefined selections, one `[id]` section per preset in a
  single `catalog/presets.conf` (just an app-ID list — see
  [architecture/0007-catalog-consistency.md](architecture/0007-catalog-consistency.md));
  the generic `INSTALL_METHOD` model (brew/cask automated; mas/pkg/dmg/manual
  as first-class manual steps); one Application Catalog screen (grouped by
  each application's single `CATEGORY`, so every app appears in exactly one
  section with one selection number; add/remove/toggle without leaving it,
  incompatible apps shown live instead of deferred); hardware
  recommendations folded into the same selection; read-only pre-flight
  validation; per-application resilient installation with verified outcomes;
  Installation Planner with plan export and a preset-vs-selection diff view
  (`--tree`); JB Picks annotated inline in the Application Catalog and plan
  explain view (not a separate screen — see
  [architecture/0008-integration-hardening.md](architecture/0008-integration-hardening.md));
  Catalog Doctor; Installation Transaction
  records with per-category named outcomes and failure reasons
- Bootstrap as an onboarding wizard over the Deployment library: base tools (CLT,
  Homebrew, verified fastfetch), pending-update offer, hardware detection, one
  flat preset question, then the exact same selection/planner/installer
  pipeline the Deployment module uses standalone
- Homebrew lifecycle: install, validate, index refresh, session-level query
  caching with post-mutation invalidation
- Hardware-based package recommendations by machine family, encoded as catalog
  data (`HW_RECOMMEND`)
- Health score (CPU / RAM / disk) with baseline tracking across runs
- Preview-confirm cleanup with **confirmed** (re-counted) deletion accounting
- Storage analysis: large files, cloud-sync detection, LaunchAgents listing
- Storage Platform service (`core/platform/storage/`), the first tenant of a
  `core/platform/` layer: Adopted Data Volumes (a `.jbtoolkit/` directory —
  `metadata.env` + `state.env` + `plans/` + `transactions/`, living on the
  volume itself so records travel with the drive — turn a generic external
  APFS disk into recognized managed storage, with transparent schema
  migration for volumes adopted by an earlier toolkit version), a generic
  scan → plan → preview → execute → verify → rollback → commit pipeline with
  UUID-identified transactions persisted incrementally at each real lifecycle
  transition (`planned → executing → committed/failed/cancelled`), a public
  `storage::*` API (`api.sh`) that is the only surface other modules should
  call, and two migration profiles built on it as plugin directories — Home
  (editable exclusion list) and Downloads (proof the engine generalizes
  without duplicating logic). Verifies each copy via checksum diff before
  ever offering to delete the source; a copy failure rolls back
  automatically, a verify failure does not. See
  [Storage-Architecture.md](Storage-Architecture.md) and
  [architecture/](architecture/) for the ADRs.
- App risk scoring (architecture, size, staleness) with user-driven Trash moves
- Performance profiles: light, aggressive (superset of light), restore-defaults
- Session logging with full command/output/exit capture; artifact retention
- System snapshot inventory per session
- Terminal executive report and client-facing PDF (reportlab)
- Independent release-readiness audit completed; blocking findings fixed
- Catalog quality metadata (v2.3.0): every application also carries
  `HOMEPAGE`, `LICENSE`, `PACKAGE_TYPE`, and `ARCHITECTURE`; the Catalog
  Doctor gained corresponding advisories. See
  [CATALOG_STANDARD.md](CATALOG_STANDARD.md) and
  [architecture/0009-catalog-evolution.md](architecture/0009-catalog-evolution.md)
- Catalog search, filters, and cross-references (v2.3.1–v2.3.2): the
  Application Catalog supports text search and JB-Pick/hardware-
  recommendation filters in place, plus an optional `RELATED` field
  pointing at companion applications. See
  [architecture/0010-catalog-discoverability.md](architecture/0010-catalog-discoverability.md)
- Deployment workflow simplification (v2.4.0): catalog-first entry, no
  mandatory preset-picker screen, hardware recommendations advisory-only
  (never auto-selecting). See
  [architecture/0011-deployment-workflow-simplification.md](architecture/0011-deployment-workflow-simplification.md)
- Responsive terminal catalog grid (v2.4.1; width-detection corrected in
  v2.5.0): the Application Catalog renders as a 1–3 column grid sized from
  the real terminal width; presets are no longer loadable from inside the
  interactive catalog screen (still real everywhere else — `presets.conf`,
  the CLI, Bootstrap's onboarding wizard). See
  [architecture/0012-terminal-ui-refinement.md](architecture/0012-terminal-ui-refinement.md)
- Engineering Governance Layer and the Module Contract model (v2.5.0):
  architecture described as atomic, independently verifiable claims rather
  than prose alone; adopted for `Deployment.Menu` (ADR-0013) and, after
  completing the same Boundary Verification sequence, for five more
  Deployment-layer modules (`Deployment.Selection`, `Deployment.Planner`,
  `Deployment.Confirm`, `Deployment.Renderer`, `Deployment.Installer`). See
  [architecture/0013-module-contracts.md](architecture/0013-module-contracts.md),
  [engineering/](engineering/), and
  [engineering/MODULE_CONTRACT_MIGRATION_LESSONS.md](engineering/MODULE_CONTRACT_MIGRATION_LESSONS.md)
- Environment-aware Bootstrap (v2.5.0): a data-driven macOS/Xcode/Command
  Line Tools/Homebrew compatibility matrix
  (`core/bootstrap/toolchain-matrix.conf`) resolved before Homebrew is ever
  touched, with behaviorally-validated capability checking and mandatory
  live Homebrew validation

## Planned (not implemented — do not document as existing)

| Goal | Intent | Status |
|---|---|---|
| **Deployment history** | Browse past Installation Transactions | Records exist (`logs/deployment_txn_*.env`); `history.sh` browser pending |
| **Storage history browsing** | Browse past Storage Migration Transactions | `storage::transactions` already returns the data ([Storage-Architecture.md](Storage-Architecture.md)); only a browser UI is missing |
| **Fine-grained migration resume** | Detect and continue an interrupted migration | `STORAGE_TXN_STATE` checkpoints already make "was this interrupted" answerable; the two-pass `storage_execute` needed for real `copied`/`verified` checkpoints is deferred (see [architecture/0004-transactions.md](architecture/0004-transactions.md)) — today, resuming means safely re-running `storage::run_profile` against the same plan, since rsync is idempotent |
| **Photos Library / Steam Library / Docker / VMs / Cloud Sync / Backups / Media Libraries profiles** | New migration profiles on the Storage Platform pipeline | Architecture and contract exist ([Storage-Architecture.md](Storage-Architecture.md)); each is a new `core/platform/storage/profiles/<id>/` directory (`profile.env` + `scan.sh`) — no engine changes needed |
| **Additional Platform services** | State, Metrics, Logging, Report, Events, Config under `core/platform/` | Named and reasoned about in [architecture/0001-platform-philosophy.md](architecture/0001-platform-philosophy.md); none designed or implemented — the bar is a demonstrated second consumer or an equally explicit request, same as Storage's own origin |
| **Automated `mas`/`pkg`/`dmg` installs** | Extend the engine beyond brew/cask | Catalog and plan already carry the method; only the execution branch in `install.sh` is missing |
| **Vendor presets** | Per-organization compositions of presets | Reserved space only (`catalog/vendors/`) — not designed yet. Known tension: this is structurally the "bundle" concept removed in v2.2; design against that deliberately, see ADR-0006 |
| **Plugin-like architecture** | Third-party/module extension points without touching core | Implemented for one subsystem (Storage's migration profiles); not generalized toolkit-wide |
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
4. **~~`STATE_FILE` defined in three places~~ Resolved.** `core/utils.sh` is now the
   sole owner; the redundant re-assignments in `bootstrap.sh` and
   `maintenance/state.sh` are deleted. Related: every entry point's `BASE_DIR`
   computation is now guarded (`${BASE_DIR:-...}`) to prefer an inherited value
   over recomputing — this doesn't fix a live bug (every real invocation path
   already converged on the same value), it's idiom alignment with
   `init_session`'s existing fallback pattern, done as part of the Storage
   Platform work's "no module calculates its root independently" requirement.
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
