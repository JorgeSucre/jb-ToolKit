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
| State | `state_value`, `write_state_values`, generic `read_kv_value FILE KEY` / `write_kv_values FILE …` underneath both — also used by volume metadata (`.jbtoolkit`) — see [State-System.md](State-System.md) |
| Session | `init_session`, `session_write`, `set_session_module`, `install_session_traps`, `finish_session_module`, `handle_unexpected_error`, `retain_recent_artifacts` |
| Command execution | `run_cmd [--visible]`, `shell_quote_command`, `retry N delay cmd…` (N total attempts) |
| Snapshot | `generate_system_snapshot` (hardware, disk, Homebrew, displays, network → text file) |
| Homebrew access | `brew_bin`, `ensure_brew_path`, `brew_available` |
| Homebrew query cache | `brew_list_formula`, `brew_list_cask`, `brew_outdated_formula`, `brew_outdated_cask`, `brew_formula_installed`, `brew_cask_installed`, `brew_upgrade_package`, `brew_cache_reset` |
| Selection parsing | `parse_selection input max` — expands `1,3-5,7` to one number per line, warns on invalid tokens |
| Size helpers | `dir_size_mb`, `human_size` |
| Hardware primitives | `load_hardware_info`, `get_arch`, `is_laptop`, `has_battery`, `has_fan`, `has_external_display`, `get_device_profile`, `get_cpu_brand_string` |
| Misc | `log`, `section` (fallback), `command_exists` |

### `core/bootstrap/ui.sh` — UI layer (used by ALL modules, not just bootstrap)
`print_section`, `print_banner`, `print_completion`,
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
one question ("¿Cómo se usará este Mac?") as a flat list generated from
`list_presets_ordered` (no category nesting), and dispatches into
`start_deployment_flow` — the **same** function the Deployment menu's preset
picker calls. Owns no software selection logic; ends when a deployment
executes or the technician skips.

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
Spotlight/swap quick checks → cleanup (with skip path) → storage analysis →
Storage Management (opt-in — see below) → apps cleanup → performance menu →
post-score → state save → executive summary → safety claims footer.

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

## Storage Platform service

See [Storage-Architecture.md](Storage-Architecture.md) for the pipeline, the
Adopted Data Volume concept, and the profile contract, and
[architecture/0002-storage-platform.md](architecture/0002-storage-platform.md)
for why it's structured as a Platform service. `core/platform/storage/` is a
**shared library** — sourced today only by `maintenance.sh` (between storage
analysis and app cleanup), architecturally identical in shape to
`core/deployment/*`: any future orchestrator sources the same files and calls
`storage::run_profile`. Only `api.sh`'s `storage::*` functions are meant to be
called from outside this directory.

### `core/platform/storage/api.sh` — Public API
The only public surface. Thin wrappers over the internals below:
`storage::discover_volumes` / `list_volumes` / `get_default_volume`,
`storage::is_managed` / `adopt_volume` / `forget_volume`, `storage::health`
(composite read: managed/healthy/free_space/volume_uuid/pending_transactions/
last_transaction/last_verify — not wired into Diagnostics, ready for a future
integration), `storage::free_space`, `storage::verify` / `rollback` (rollback
is per-item, not whole-transaction), `storage::transactions` (lists
`.jbtoolkit/transactions/*.env` as data, not a browser), `storage::run_profile`
(the only one that changes anything).

### `core/platform/storage/volume.sh` — Adopted Data Volume
`detect_console_user` / `resolve_user_home` (console-session owner via
`stat -f%Su /dev/console`, not `$HOME` — shared by adoption and every profile),
`is_external_apfs_volume` / `is_writable_volume` / `is_time_machine_volume`
(`diskutil info` + a real write probe), `_diskutil_field` /
`storage_volume_free_space` (identity + free-space parsing), `is_adopted_volume`
(recognizes both the current directory-based `.jbtoolkit/` and a legacy
schema-1 flat file), `volume_metadata_value` / `volume_state_value` (read
`metadata.env`/`state.env` via `utils.sh`'s `read_kv_value`),
`initialize_managed_volume` (creates the `JB Toolkit/` namespace + `.jbtoolkit/`
structure: `metadata.env`, `state.env`, `plans/`, `transactions/` — schema
version, a JB-generated UUID, the disk's own UUIDs, owner, timestamp),
`_upgrade_legacy_volume_metadata` (transparently migrates a schema-1 volume,
preserving history), `touch_volume_usage` (increments `MIGRATION_COUNT` /
stamps `LAST_MIGRATION_AT`), `check_volume_schema_compat` (warns, never
blocks, on a newer schema), `forget_volume` (archives `.jbtoolkit`, never
deletes it), `discover_storage_volumes` / `select_storage_volume` (menu
marking each volume managed vs. generic; unmanaged offers adoption inline;
legacy triggers the upgrade transparently).

### `core/platform/storage/plan.sh` — Storage Migration Plan
`build_storage_plan` (freezes the toggled selection plus volume/profile context
into `STORAGE_PLAN_*`), `export_storage_plan` (serializes to
`<volume>/.jbtoolkit/plans/*.env` — on the volume, not the toolkit's own
`logs/`, so the record travels with the drive). Mirrors `deployment/planner.sh`'s
role.

### `core/platform/storage/transaction.sh` — Storage Migration Transaction
`txn_begin` (also assigns `STORAGE_TXN_UUID` and sets `STORAGE_TXN_STATE=planned`)
/ `txn_finish` / `txn_export` (idempotent, called at each real STATE
transition — `planned → executing → committed|failed|cancelled` — not just
once at the end, so an interrupted migration leaves a discoverable partial
record; deliberately does not attempt `copied`/`verified`/`rolled_back` as
top-level states since the engine can't produce them as distinct checkpoints
today, see [architecture/0004-transactions.md](architecture/0004-transactions.md)),
`txn_record_summary_in_state` (updates local `state.env`'s `LAST_STORAGE_*`
keys, called once after the true final export). Mirrors
`deployment/transaction.sh`'s role.

### `core/platform/storage/engine.sh` — Generic pipeline + profile registry
`register_storage_profile` / `storage_profile_label` / `storage_profile_dest_subdir`
/ `load_storage_profiles` (discovers `profiles/*/`, sources `profile.env` then
`scan.sh`, registers on the profile's behalf), `select_storage_profile`
(auto-collapses when exactly one profile is registered), `storage_scan`
(dispatches to the active profile's callbacks by computed function name — no
`eval`), `toggle_storage_selection` (per-item toggle pattern from
`deployment/menu.sh`, generic over whatever `STORAGE_SCAN_CACHE` contains),
`storage_preview` (pure presentation over the plan), `resolve_rsync_binary` /
`rsync_supports_flag` / `build_rsync_flags` (detects Homebrew rsync's `-A`/`-X`
support instead of assuming macOS's stock rsync), `storage_execute` (copy per
item) + `storage_verify_item` (`--checksum --dry-run -i`, zero lines =
identical — deliberately `-a -H` only, not the copy's fuller flags: on modern
macOS, `openrsync` reports a false checksum mismatch for byte-identical files
when `-E`/`-A`/`-X` are combined with `--checksum --dry-run`) +
`storage_rollback_item` (a copy failure removes the partial destination; a
verify failure does not — the copy exists, the cause is ambiguous, a human
should look), `storage_commit` / `confirm_and_delete_verified_sources` /
`remove_verified_source` (the only path that deletes source data, gated on a
`verified` outcome plus explicit confirmation, size re-measured immediately
before deletion and re-counted after rather than assumed), `run_storage_management`
(top-level orchestrator, writes STATE checkpoints at each transition; every
early exit — no eligible volume, declined, cancelled, nothing selected — is a
clean no-op).

### `core/platform/storage/profiles/<id>/` — Migration profiles
`profile.env` (`PROFILE_ID`, `PROFILE_LABEL`, `DEST_SUBDIR` — plain KEY=value,
quote any value with spaces since it's sourced as bash) + `scan.sh` (two
callbacks: `_source_root`, `_scan`) — see Storage-Architecture.md's profile
contract. `home/`: mirrors the console user's Home folders one level deep;
`_storage_home_excluded` permanently excludes Library, Applications,
Developer, Public, OneDrive, Dropbox, iCloud Drive, and (via `find`, before
the candidate list even exists) anything hidden. `downloads/`: a
single-folder profile with no exclusion list, kept deliberately minimal as
proof that the engine generalizes without duplicating logic.

## Deployment subsystem

See [Deployment-Architecture.md](Deployment-Architecture.md) for the pipeline and
layer contracts, and [architecture/0006-deployment-flattening.md](architecture/0006-deployment-flattening.md)
for why there is no bundle/profile grouping layer. The sub-module files are a
**shared library**: sourced by `deployment.sh` (launcher option 4) and by
`bootstrap.sh` (the onboarding wizard) — one catalog, one selection model, one
planner, one installer.

### `core/deployment.sh` — Dispatcher (launcher menu option 4)
Small by design: sources the sub-modules and dispatches. Interactive entry
validates the catalog, then runs the menu loop. CLI commands — each a different
representation of the same Installation Plan: `--validate`, `--doctor`,
`--resolve <preset>` (summary), `--explain <preset>` (provenance), `--tree
<preset>` (diff view), `--plan <preset>` (serialized export). `require_plan`
loads the named preset into a fresh selection with zero manual edits — the
CLI has no interactive concept.

### `core/deployment/catalog.sh`
Read-only catalog access and the validator. Accessors are tolerant (missing
file/key → empty, exit 0 — safe under `set -e`); existence checks are explicit.
Two layers only: applications and presets (the latter one file,
`catalog/presets.conf`, one `[id]` section each — see
[architecture/0007-catalog-consistency.md](architecture/0007-catalog-consistency.md)).
Field access (`catalog_field`/`app_field`/`preset_field`), listers
(`list_applications`, `list_presets`, `list_presets_ordered` — flat,
`ORDER`-then-alphabetical, no category nesting), `preset_apps` (a preset's
entire `APPS` list — no bundle expansion, there's nothing to expand), the
Application Catalog's browsing queries (`list_app_categories` /
`apps_in_category` — every application's single `CATEGORY` value, alphabetical,
one app per section by construction),
`apps_recommended_for_hardware` (`HW_RECOMMEND` matching), and
`validate_catalog` implementing rules V1–V9 (including the `INSTALL_METHOD`
contract) with per-file, per-rule Spanish messages. `JB_CATALOG_DIR` overrides
the catalog root (testing).

### `core/deployment/selection.sh`
**The one selection model.** `SELECTED_APPS` (`id|provenance`, provenance ∈
`preset:<id>` / `hardware` / `manual`, display-only — nothing downstream
branches on it): `selection_add` / `selection_remove` / `selection_toggle` /
`selection_contains` / `selection_provenance` / `selection_list` /
`selection_count`. `app_incompatibility_reason` (ARCHS vs `uname -m`,
MIN_MACOS vs `sw_vers` major → Spanish reason — moved here from the former
`resolve.sh`; this is exactly "can this app join the selection").
`load_preset_into_selection` (replaces the current selection with a preset's
`APPS`, recording incompatible entries in `SELECTION_LOAD_SKIPPED` — never
silent). `apply_hardware_recommendations` (folds `HW_RECOMMEND` matches not
already installed into the same selection, provenance `hardware` — no
separate offer screen).

### `core/deployment/doctor.sh`
Catalog Doctor: advisory maintainability diagnostics on a valid catalog — D1
(application referenced by no preset, `HW_RECOMMEND` apps exempt), D2
(applications referenced by 4+ presets, an informational curation aid for the
duplication flat presets accept — see the ADR). Suggestions only; never a
validation failure (hard rules stay in the validator).

### `core/deployment/planner.sh`
Builds the **Installation Plan** — the official contract between every layer;
the only decision-making layer past selection. `build_plan_from_selection
[preset_id]` classifies whatever is in `SELECTED_APPS` — it does not resolve
presets or know what a category is, that already happened in `selection.sh`.
Populates the `PLAN_*` globals: plan identity (`PLAN_ID`), machine
compatibility context, preset identity (`PLAN_PRESET_ID`/`PLAN_PRESET_NAME`,
`"custom"` if none), the automatic track (`PLAN_APPS` —
`id|name|provenance|method|package`; the installer never reads the catalog),
the manual track (`PLAN_MANUAL` — `id|name|provenance|method|download-url`;
mas/pkg/dmg/manual apps, never failures), named skips — **compatibility
exclusions only** (`id|name|reason`; a technician not selecting an app is not
a skip, it's simply absent from `SELECTED_APPS`), JB Picks, counts.
`export_deployment_plan` serializes to `logs/deployment_plan_<id>.env`
(human-readable, retained ×20).

### `core/deployment/render.sh`
Pure presentation; renders catalog/plan/transaction data, never resolves or
mutates. Element renderers (`render_category`, `render_preset`,
`render_application`, `plan_source_label` — switches on
provenance string, no more bundle lookups, `manual_step_label`) and view
renderers: `render_plan_summary` (concise), `render_plan` (explain: provenance
+ manual steps with URLs + compatibility-exclusion reasons + pick notes),
`render_plan_tree` (**preset-vs-final-selection diff** — kept/added/removed,
computed at render time from `PLAN_APPS`/`PLAN_MANUAL` against a fresh
`preset_apps()` lookup, no stored diff data; a no-op when `PLAN_PRESET_ID` is
`"custom"`), `render_confirmation` (pre-install summary: automatic vs manual
vs compatibility-excluded counts), `render_transaction` (verified result:
every outcome named — installed, already installed, manual, compatibility
excluded, failed with reasons).

### `core/deployment/menu.sh`
One workflow: Quick Presets → Application Catalog → confirmation (`confirm.sh`).
Navigation generated entirely from catalog data — no hardcoded names.
`run_deployment_menu` (flat list: every preset by `list_presets_ordered` +
Empezar vacío, no category nesting), `start_deployment_flow` (loads a
preset or resets to empty, folds hardware recommendations, runs the Application
Catalog, builds the plan, hands off to confirmation — the **same** function
`wizard.sh` calls), `run_application_catalog` (the one screen selection
happens in: a single continuous list grouped by `CATEGORY` with running
selection numbers so `parse_selection`'s `1,3-5` syntax works across category
boundaries; `JB_PICK=true` applications are marked `⭐` inline, regardless of
selection state; an incompatible app is shown with its reason instead of a
checkbox and is never assigned a number — add/remove/toggle without leaving
the screen, Enter to continue, `0` to cancel). There is no separate JB Picks
screen — see
[architecture/0008-integration-hardening.md](architecture/0008-integration-hardening.md).

### `core/deployment/confirm.sh`
`run_plan_confirmation`: the final review screen — `[E]` explain, `[G]`
preset-vs-selection diff, `[I]` install (runs the installer; a y/n gate inside
is the last stop), `[0]` back. Cancellation or a blocked install returns to
the review; execution ends it. Unchanged by the flattening — it was already
fully generic over whatever the planner built.

### `core/deployment/transaction.sh`
The **Installation Transaction** — the execution record, separate from the plan.
`txn_begin` / `txn_finish` / `txn_export` capture session id, preset
(`TXN_PRESET`), plan id and file, timing, attempted/installed/already/skipped/
manual/failed counts, named outcomes per category (failures carry their
reason: `id|name|reason`), cancellation, and the result
(`success|partial|failed|cancelled` — manual steps never degrade the result).
Persisted to `logs/deployment_txn_<id>.env` (retained ×20) and pointed to from
`state.env`. Future Reports, Support Bundles, and History consume this record.

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
