# Design Principles

These principles are **inferred from the implementation**, not aspirational. Each one
is backed by code that actually enforces it. When contributing, treat violations of
these principles as design regressions.

## 1. Never report estimated values when real measurements are available

The toolkit's central promise is that its output is truthful. This was the subject of
a dedicated release-readiness audit.

- `cleanup_homebrew()` measures cache size **before and after** `brew cleanup` and
  reports the difference — never the preview estimate.
- `cleanup_caches()` / `cleanup_logs()` / `cleanup_trash()` re-run their `find` after
  deletion and report `initial − remaining` as the confirmed removal count. Files that
  could not be deleted (sandbox, SIP) are automatically excluded from the totals.
- `move_apps_to_trash()` increments `FILES_REMOVED` only inside the `if mv …; then`
  success branch.
- Preview figures are explicitly labeled as estimates: `"Espacio potencial a
  recuperar: ~XMB"` (note the `~`).

**Rule:** a `success "✔ …"` message must be backed by a verified operation — an exit
code, a re-count, or a before/after measurement.

## 2. Modules are independent processes; state crosses through one file

The four modules never call each other. Anything that must outlive a module run is
written to `logs/state.env` via `write_state_values` and read via `state_value`.
Missing keys read as `"N/A"`, and every consumer handles that value explicitly.

**Rule:** do not add cross-module function calls or shared in-memory state. Add a
state key instead, and handle `N/A`.

## 3. Shared logic belongs in `core/utils.sh`

Duplicated helpers have been deliberately consolidated there: `dir_size_mb`,
`human_size`, `parse_selection`, the Homebrew query cache, hardware primitives. When
the same logic appears in a second module, it moves to `utils.sh` — but only when the
consolidation makes the code **smaller** (see principle 7).

## 4. Hardware capabilities determine behavior

Behavior branches on detected hardware, not on user configuration:

- Brewfile variant selection by architecture (`Brewfile.apple` / `Brewfile.intel`).
- Package recommendations by machine family (`offer_hardware_recommendations`:
  AlDente for MacBooks, Macs Fan Control for desktops, BetterDisplay when an external
  display is present).
- App risk scoring weights Intel-only binaries only on Apple Silicon.
- Rosetta detection runs only on Apple Silicon; Siri tweaks only on Intel.
- `get_device_profile` normalizes: laptops always report a battery.

## 5. Fail gracefully; abort only when continuing is meaningless

Two failure tiers, consistently applied:

- **Absorbed:** cosmetic or best-effort operations use `2>/dev/null || true` or
  `|| warn`. A failed `killall Dock` or an unreadable directory never stops a run.
- **Fatal:** missing internet, missing Homebrew after install attempts, or a corrupted
  temp Brewfile abort with `print_completion "false"` and non-zero exit, because every
  later step depends on them.

Network operations retry with backoff (`retry 3 5 …` for `brew bundle`, a 3-attempt
loop for the Homebrew installer, `curl --retry 3`).

## 6. Expensive queries run once per process

- Homebrew list/outdated queries are cached in module-level variables with lazy-load
  flags (`brew_list_formula` et al.) and **invalidated after mutations** via
  `brew_cache_reset()`.
- `build_app_metadata_cache` and `build_large_files_cache` compute once and memoize.
- `load_hardware_info` caches `system_profiler` output for the process lifetime.
- Single-purpose subprocess consolidation: one `df -H /` call feeds four fields.

**Rule:** if you add a mutation to Homebrew state, call `brew_cache_reset()` after it.

## 7. Prefer deleting code over adding code

The project explicitly values simplicity, readability, and low cognitive load over
abstraction, extensibility, and future-proofing. Accepted consequences visible in the
code:

- The RAM calculation exists twice (`calculate_health_score` and `report.sh`) because
  the two consumers need different outputs and a shared helper would be **larger**
  than the duplication. This was evaluated and rejected deliberately.
- Architecture detection variables exist per-module (`APPLE_SILICON`,
  `IS_APPLE_SILICON`) because the modules run in separate processes and consolidation
  would add coupling without removing lines.

**Rule:** consolidate only when the result is smaller, more readable, and introduces
no new abstraction. A three-line fix beats a thirty-line framework.

## 8. Destructive actions are user-driven and scoped to user space

- Nothing under `/System`, `/Library` (system domain), or other users' homes is ever
  written. Cleanup targets are `~/Library/Caches`, `~/Library/Logs`, `~/.Trash`, and
  the Homebrew cache.
- App removal is selection-driven (`move_apps_to_trash`) and moves to Trash — it never
  `rm -rf`s an application.
- Cloud-synced paths are excluded from large-file candidates (`is_excluded_path`:
  CloudStorage, iCloud Drive, Dropbox, OneDrive, Google Drive, plus VM images under
  Parallels/Docker).
- Maintenance asks for confirmation (`ask_yes_no`) before touching anything, and a
  "no" exits cleanly with `MAINTENANCE_SKIPPED`.

## 9. Every action is auditable

Every `success`/`warn`/`info`/`error_msg` call writes to the session log. Every
command executed through `run_cmd` records the exact quoted command line, its full
output (indented), and its exit code. See [Logging.md](Logging.md).

**Rule:** run state-changing shell commands through `run_cmd`, not bare.

## 10. UI is consistent and bilingual by convention

- **User-facing text is Spanish; code, comments, and logs are English.**
- Sections open with `print_section "emoji Title"`; modules end with
  `print_completion "true|false"`.
- Status prefixes are uniform: `✔` success, `⚠️` warning, `ℹ️` info, `❌` error.
- Yes/no prompts accept `y/Y/s/S` (English and Spanish affirmatives).
- Numeric selection prompts share one parser (`parse_selection`) supporting
  `1,3-5,7` with per-token validation warnings.

## Coding conventions (observed)

| Convention | Example |
|---|---|
| Functions: `lower_snake_case` | `build_outdated_package_list` |
| Module-level globals: `UPPER_SNAKE_CASE` | `TOOLKIT_OUTDATED`, `APP_COUNT` |
| Private/cache globals: leading underscore | `_BREW_LIST_FORMULA_LOADED` |
| Locals declared with `local`, arrays with `local -a` | `parse_selection` |
| Section banners in every file | `# ===== … =====` comment blocks |
| Guard-clause early returns | `[[ -z "$APP_CANDIDATES" ]] && return 0` |
| Heredoc-free short osascript / awk inline | one-purpose one-liner style |
| No `eval` on user input; regex-validated selections | `^[0-9]+$` checks before arithmetic |
