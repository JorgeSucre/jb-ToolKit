# Module Overview

Per-file responsibilities and notable functions. Orchestrators own control flow;
sub-modules are function libraries sourced by their orchestrator.

## Entry point

### `jb` — Launcher
Owns the session (`init_session`, `install_session_traps`), presents the 5-option
menu, and executes each module as a child `bash` process via `run_script`, which logs
launch/exit and survives module failures. `chmod +x`es core scripts defensively.

## Foundation

### `core/utils.sh` — Shared foundation (sourced by everything)
| Area | Functions |
|---|---|
| Config | `BASE_DIR`, `STATE_FILE`, `JB_VERSION`, ANSI colors (TTY-gated) |
| Health score | `calculate_health_score` (+ `SYS_*` metric cache) — see [Health-Score.md](Health-Score.md) |
| State | `state_value`, `write_state_values` — see [State-System.md](State-System.md) |
| Session | `init_session`, `session_write`, `set_session_module`, `install_session_traps`, `finish_session_module`, `handle_unexpected_error`, `retain_recent_artifacts` |
| Command execution | `run_cmd [--visible]`, `shell_quote_command`, `retry N delay cmd…` (N total attempts) |
| Snapshot | `generate_system_snapshot` (hardware, disk, Homebrew, displays, network → text file) |
| Homebrew access | `brew_bin`, `ensure_brew_path`, `brew_available`, `brew_prefix_safe` |
| Homebrew query cache | `brew_list_formula`, `brew_list_cask`, `brew_outdated_formula`, `brew_outdated_cask`, `brew_formula_installed`, `brew_cask_installed`, `brew_upgrade_package`, `brew_cache_reset` |
| Selection parsing | `parse_selection input max` — expands `1,3-5,7` to one number per line, warns on invalid tokens |
| Size helpers | `dir_size_mb`, `human_size` |
| Hardware primitives | `load_hardware_info`, `get_arch`, `is_laptop`, `has_battery`, `has_fan`, `has_external_display`, `get_device_profile`, `get_cpu_brand_string` |
| Misc | `log`, `section` (fallback), `command_exists` |

### `core/bootstrap/ui.sh` — UI layer (used by ALL modules, not just bootstrap)
`print_section`, `print_banner`, `print_completion`, `print_cancelled`,
`success`/`warn`/`error_msg`/`error`/`info` (terminal + session log),
`set_ui_context`, `ask_yes_no` (accepts `YySs`), `print_elapsed_time`.

## Bootstrap subsystem

### `core/bootstrap.sh` — Orchestrator
Linear setup flow with 5 staged sections and hard abort points: base tools (CLT,
Homebrew), Homebrew configuration (indexes, verified fastfetch install, pending
updates), hardware detection, the onboarding wizard, and finalization. Sources the
**Deployment library** (`core/deployment/*`) so the wizard uses the same catalog,
planner, and installer as the Deployment module. Also defines `install_clt`
(Command Line Tools with 5-minute polling) and the admin-rights check.

### `core/bootstrap/stages.sh`
`print_stage` — `[n/TOTAL]` progress header with previous-stage elapsed time.

### `core/bootstrap/brew.sh`
`check_internet_connection`, `install_brew` (3 attempts, official installer,
`--visible`), `configure_brew` (resolve `BREW_BIN`, eval `shellenv`),
`validate_brew`, `update_brew_indexes` (skips when FETCH_HEAD < 24 h),
`ensure_base_tools` (fastfetch through the engine pattern, verified afterward),
`offer_package_updates` (preview → confirm → upgrade each → verify remaining
count with a fresh outdated query).

### `core/bootstrap/wizard.sh`
`run_onboarding_wizard` — Bootstrap's software step. Validates the catalog, asks
one question ("¿Cómo se usará este Mac?") generated from catalog categories, and
dispatches into the Deployment flows (`open_category`, `run_custom_flow`). Owns no
software selection logic; ends when a deployment executes or the technician skips.

### `core/bootstrap/hardware.sh`
`detect_rosetta` (filesystem check, `pkgutil` fallback; Apple Silicon only),
`load_hardware_profile` (parses `get_device_profile` output into `ARCH`/`TYPE`/
`BATTERY`/`FAN`), `detect_machine_family` (MacBook Air/Pro, mini, Studio, iMac),
`detect_model`, `build_hardware_labels` (Spanish display strings),
`print_hardware_summary`, `print_optimization_summary`.

## Diagnostics

### `core/diagnostics.sh` — Self-contained module
fastfetch summary (or manual fallback), top-5 process table, health-score bar,
state write, threshold-based executive summary, next-step recommendation.
Read-only toward the system.

## Maintenance subsystem

### `core/maintenance.sh` — Orchestrator
Spotlight/swap quick checks → cleanup (with skip path) → storage analysis → apps
cleanup → performance menu → post-score → state save → executive summary → safety
claims footer.

### `core/maintenance/cleanup.sh`
`scan_cleanup_targets` + `safe_old_files_size_mb` (preview estimates),
`preview_cleanup` (estimates labeled `~`), `has_homebrew_cleanup_candidates`,
`cleanup_homebrew` (before/after measured), `cleanup_caches` / `cleanup_logs` /
`cleanup_trash` (age-based `find -delete`, then re-count for confirmed totals),
`run_cleanup_tasks` (confirm-or-skip gate). Age policies: caches > 7 days,
logs > 14 days, Trash > 7 days.

### `core/maintenance/storage.sh`
`build_large_files_cache` (find by extension, > 1 GB, in user content dirs +
/Applications), `is_excluded_path` (cloud/VM exclusions), `scan_large_files`,
`print_cloud_storage_status`, `scan_launch_agents`, `run_storage_analysis`.
Entirely read-only — it reports, never deletes.

### `core/maintenance/apps.sh`
`is_intel_only_app` (PlistBuddy `CFBundleExecutable` → `file` arch check),
`app_age_days`, `build_app_metadata_cache` (score every ≥ 100 MB app),
`scan_large_apps` (sort by score, cap at `MAX_RESULTS`=12), `print_app_candidates`,
`move_apps_to_trash` (selection → `mv` to `~/.Trash`, counts successes only),
`run_apps_cleanup`. Risk model: Intel-only on AS +35, > 5 GB +25 / > 1 GB +10,
> 30 days +20; Crítico ≥ 70, Alto ≥ 40, Medio ≥ 25, below → not shown.

### `core/maintenance/performance.sh`
`apply_light_optimization` (reduce motion/transparency, faster Dock, window
animations off), `apply_aggressive_optimization` (includes light via nested call,
then ad personalization off, Siri tweaks on Intel, legacy login-item removal),
`restore_performance_defaults` (deletes every key the profiles write),
`run_performance_optimization` (menu with confirmation gate on aggressive).
All writes are user-domain `defaults`; `killall Dock` applies Dock changes.

### `core/maintenance/state.sh`
`initialize_state` (zero counters, promote previous score to baseline),
`calculate_post_maintenance_score` (fallback to baseline on failure),
`save_maintenance_state` (persist all keys), `print_maintenance_summary`
(tiered outcome message, freed space, items, profile, score delta).

## Deployment subsystem

See [Deployment-Architecture.md](Deployment-Architecture.md) for the pipeline and
layer contracts. The sub-module files are a **shared library**: sourced by
`deployment.sh` (launcher option 4) and by `bootstrap.sh` (the onboarding wizard).

### `core/deployment.sh` — Dispatcher (launcher menu option 4)
Small by design: sources the sub-modules and dispatches. Interactive entry
validates the catalog, then runs the menu loop. CLI commands — each a different
representation of the same Deployment Plan: `--validate`, `--doctor`,
`--resolve <perfil>` (summary), `--explain <perfil>` (provenance), `--tree
<perfil>`, `--plan <perfil>` (serialized export).

### `core/deployment/catalog.sh`
Read-only catalog access and the validator. Accessors are tolerant (missing
file/key → empty, exit 0 — safe under `set -e`); existence checks are explicit.
Field access (`catalog_field`/`app_field`/`profile_field`), listers, bundle and
profile readers, hierarchy queries for menu generation (`list_categories`,
`profiles_in_category`, `category_direct_profile` — the collapse rule,
`list_jb_picks`, `apps_recommended_for_hardware` — `HW_RECOMMEND` matching), and
`validate_catalog` implementing rules V1–V10 (including the `INSTALL_METHOD`
contract) with per-file, per-rule Spanish messages. `JB_CATALOG_DIR` overrides
the catalog root (testing).

### `core/deployment/resolve.sh`
`resolve_apps_for_bundles` (bundle order, line order, first-occurrence dedupe,
**provenance-carrying** `id|bundle` records), `app_incompatibility_reason`
(ARCHS vs `uname -m`, MIN_MACOS vs `sw_vers` major → Spanish reason),
`resolve_install_set_for_bundles` → `RESOLVED_APPS` (`id|bundle`) and
`RESOLVED_SKIPPED` (`id|bundle|reason`). Skips always recorded, never silent.

### `core/deployment/doctor.sh`
Catalog Doctor: advisory maintainability diagnostics on a valid catalog —
unreferenced applications, single-app bundles, apps in multiple bundles,
single-bundle profiles, single-profile categories. Suggestions only; never a
validation failure (hard rules stay in the validator).

### `core/deployment/planner.sh`
Builds the **Deployment Plan** — the official contract between every layer; the
only decision-making layer. `build_deployment_plan <profile> [excluded] [extras]
[bundles]` / `build_custom_plan <bundles> [excluded] [extras]` populate the
`PLAN_*` globals: plan identity (`PLAN_ID`), machine compatibility context,
bundles, the automatic track (`PLAN_APPS` — `id|name|source|method|package`; the
installer never reads the catalog), the manual track (`PLAN_MANUAL` —
`id|name|source|method|download-url`; mas/pkg/dmg/manual apps, never failures),
named skips (compatibility + technician deselections), JB Picks, counts.
`export_deployment_plan` serializes to `logs/deployment_plan_<id>.env`
(human-readable, retained ×20).

### `core/deployment/render.sh`
Pure presentation; renders catalog/plan/transaction data, never resolves or
mutates. Element renderers (`render_category`, `render_profile`, `render_bundle`,
`render_application`, `render_jb_pick`, `plan_source_label`,
`manual_step_label`) and view renderers: `render_plan_summary` (concise),
`render_plan` (explain: provenance + manual steps with URLs + skip reasons +
pick notes), `render_plan_tree` (developer tree with dedup/manual/skip
annotations), `render_confirmation` (pre-install summary: automatic vs manual
counts), `render_transaction` (verified result: every outcome named —
installed, already installed, manual, skipped, failed with reasons).

### `core/deployment/menu.sh`
Navigation generated entirely from catalog data — no hardcoded names.
`run_deployment_menu` (categories + Personalizado + JB Picks, ≤7 entries),
`open_category` (submenu or collapse), `run_bundle_review` (per-bundle gate:
install all / customize / skip; `_customize_bundle` is a per-app toggle loop),
`offer_hardware_extras` (catalog apps whose `HW_RECOMMEND` matches this machine
and aren't installed), `run_custom_flow` (bundle multi-select via
`parse_selection`, then the same review), `show_jb_picks` (read-only browser).
Screens collect decisions; the planner applies them.

### `core/deployment/confirm.sh`
`run_plan_confirmation`: the final review screen — `[E]` explain, `[G]` tree,
`[I]` install (runs the installer; a y/n gate inside is the last stop), `[0]`
back. Cancellation or a blocked install returns to the review; execution ends it.

### `core/deployment/transaction.sh`
The **Installation Transaction** — the execution record, separate from the plan.
`txn_begin` / `txn_finish` / `txn_export` capture session id, profile, plan id and
file, timing, attempted/installed/already/skipped/manual/failed counts, named
outcomes per category (failures carry their reason: `id|name|reason`),
cancellation, and the result (`success|partial|failed|cancelled` — manual steps
never degrade the result). Persisted to `logs/deployment_txn_<id>.env` (retained
×20) and pointed to from `state.env`. Future Reports, Support Bundles, and
History consume this record.

### `core/deployment/install.sh`
Executes an already-built plan; **makes no decisions** — no resolution, no
compatibility rules, no catalog reads. Partitions installed/pending from plan
records (Homebrew queries for the automatic track, `/Applications` existence for
the manual track), runs a **read-only pre-flight** that verifies every pending
package against Homebrew's index before anything is modified (unavailable
packages become named failures behind a continue/abort gate), then installs
**each application individually** through the engine pattern (`retry 3 5 run_cmd
--visible brew install [--cask]`), verifies each app against a fresh Homebrew
query (`brew_cache_reset`), records confirmed outcomes in the transaction and
`state.env`, and finally offers to open each manual app's download page.

## Reporting

### `core/report.sh` — Orchestrator
Terminal executive report + optional PDF trigger. Own RAM calculation (display
needs GB values). Double-run guard via `JB_REPORT_ALREADY_RUN`.

### `core/report_pdf.py` — PDF generator (Python 3 + reportlab)
Reads `state.env` (`get_state_value`) and the latest system snapshot
(`read_snapshot`), renders an executive PDF to `$JB_PDF_OUTPUT`. Pure consumer:
executes no system commands for data that Bash already measured.
