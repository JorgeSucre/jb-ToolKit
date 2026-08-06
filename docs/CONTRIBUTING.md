# Contributing to JB Toolkit

This is an engineering handbook, not a checklist. It explains how the project thinks,
so that your changes read like they were written by the same team that wrote the rest.

JB Toolkit went through multiple architecture passes and an independent
release-readiness audit before its structure was declared stable. The bar for changing
that structure is high; the bar for working well **within** it is what this document
teaches. Read [Design-Principles.md](Design-Principles.md) first — this handbook
applies those principles to day-to-day decisions.

---

## Project philosophy

1. **Keep the architecture modular.** Four (soon five) top-level modules run as
   independent child processes under the `jb` launcher. Each module is a complete,
   self-contained workflow.
2. **Never let module orchestrators depend on each other.** Bootstrap must not know
   Maintenance exists. No module runs, calls, or reads the internals of another
   module's orchestrator. If two modules need the same small logic, it belongs in
   the foundation layer (`core/utils.sh`). Two subsystems are **shared function
   libraries**, not module internals: `core/bootstrap/ui.sh` (the UI layer for all
   modules) and `core/deployment/*` (the Deployment library — catalog, planner,
   installer — sourced by both `deployment.sh` and `bootstrap.sh`, so software
   selection and installation exist exactly once).
3. **`state.env` is the only cross-module communication mechanism.** Data that must
   outlive a module run is written with `write_state_values` and read with
   `state_value`. There is no other channel — no shared temp files, no exported
   variables between modules (the session identity exported by the launcher is the
   sole exception).
4. **Prefer simplicity over unnecessary abstraction.** A three-line fix beats a
   thirty-line framework. Delete code when you can. Duplication is sometimes the
   correct choice (see below).
5. **Never report estimated values when verified measurements are available.** Every
   `success "✔ …"` message must be backed by an exit code, a re-count, or a
   before/after measurement. Preview figures are labeled with `~`. This is the
   toolkit's core promise and it has been audited; do not regress it.
6. **UI consistency is more important than adding features.** A feature that needs a
   new interaction pattern, a bigger menu, or a new message style is not ready. Fit
   the existing patterns or don't ship it.

---

## Where code belongs

### When code goes in `utils.sh`

Put a function in `core/utils.sh` when **all** of these hold:

- Two or more modules need it (not "might need it" — need it today).
- Consolidating makes the total code **smaller** than the duplication it removes.
- It introduces no new abstraction — it's a function, not a framework.

Current examples: `dir_size_mb`, `human_size`, `parse_selection`, the Homebrew query
cache, `run_cmd`, hardware primitives.

### When duplication is acceptable

Duplication is the better design when the copies serve different consumers with
different output shapes, or live in different processes where sharing would add
coupling without removing lines. Two standing examples, both evaluated and accepted:

- The RAM calculation exists in `calculate_health_score` (needs an integer percent)
  and in `report.sh` (needs GB strings for display). A shared helper would be larger
  than the duplication.
- Per-module architecture checks (`APPLE_SILICON` in apps.sh, `IS_APPLE_SILICON` in
  performance.sh). One `uname -m` per process is cheaper than cross-module coupling.

Do not "fix" these. If you find a **third** consumer of duplicated logic, that's the
signal to revisit consolidation.

### When a new top-level module is justified

Almost never. A new module means a new launcher menu entry, and menus stay small. A
new module is justified only when the work is a complete, independent workflow with
its own lifecycle (like Deployment) — not a feature of an existing workflow. New
maintenance capabilities are sub-modules under `core/maintenance/`; new setup
capabilities extend `core/bootstrap/`.

### When something belongs in `core/platform/<service>/`

Rarer still — see [architecture/0001-platform-philosophy.md](architecture/0001-platform-philosophy.md).
`core/platform/` is for genuinely reusable infrastructure with its own public
API, consumed by multiple modules over time (today: only Storage; State,
Metrics, Logging, Report, Events, and Config are named as future candidates,
**not implemented** — don't scaffold empty directories for them). The bar: a
demonstrated second consumer, or a request as explicit as the one that
created Storage. Most new capabilities are sub-modules of an existing module,
not a new Platform service.

---

## Shell scripting style

- Bash, macOS-compatible (the system bash is 3.2 — avoid associative arrays,
  `readarray`, `${var,,}` and other 4.x-only features).
- Guard clauses over nesting: `[[ -z "$X" ]] && return 0` at the top, not an
  `if` pyramid.
- Declare function variables `local` (arrays as `local -a`). Module-level state is
  fine as globals, named in `UPPER_SNAKE_CASE`.
- Quote every expansion. Prefer `[[ … ]]` over `[ … ]`, `$( … )` over backticks.
- Prefer native parameter expansion over subprocesses when clearly simpler:
  `${pkg%% *}` beats `awk '{print $1}'`. But readability wins over
  micro-optimization — don't golf.
- Validate numeric input with a regex (`^[0-9]+$`) before arithmetic. Never `eval`
  user input.
- Every file opens with the section-banner comment style used throughout
  (`# ===== … =====`).
- Entry points set strict modes (see the per-module differences documented in
  [Future-Roadmap.md](Future-Roadmap.md) before copying one).
- Every entry point computes `BASE_DIR` the same guarded way:
  `BASE_DIR="${BASE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"`
  — reuse an inherited value (running as a child of `jb`) before
  self-computing (standalone execution), mirroring `init_session`'s existing
  fallback idiom. `core/utils.sh` is the single owner of `STATE_FILE`; don't
  redefine it elsewhere.

## Naming conventions

| Thing | Convention | Example |
|---|---|---|
| Functions | `lower_snake_case`, verb-first | `build_outdated_package_list` |
| Module globals | `UPPER_SNAKE_CASE` | `TOOLKIT_OUTDATED`, `APP_COUNT` |
| Private/cache globals | leading underscore | `_BREW_LIST_FORMULA_LOADED` |
| State keys | `UPPER_SNAKE_CASE`, past-tense facts | `TOTAL_FREED_MB`, `LAST_MAINTENANCE` |
| Files | `lower-context.sh` under the owning subsystem | `maintenance/cleanup.sh` |

User-facing text is **Spanish**; code, comments, commit messages, and docs are
**English**.

## Error handling

Two tiers, applied consistently:

- **Absorbed** — cosmetic or best-effort operations: `2>/dev/null || true`, or
  `|| warn "⚠️ …"` when the user should know. A failed `killall Dock` never aborts
  a run.
- **Fatal** — the module's remaining work is meaningless without it (no internet, no
  Homebrew, base tools missing after install): print an `error_msg`,
  `print_completion "false"`, exit non-zero. One application failing to install is
  **not** fatal — deployments continue and record the failure with its reason.

Network operations retry (`retry 3 5 cmd…` — note: 3 **total** attempts). Decide the
tier deliberately; don't default everything to `|| true`.

## Logging and session logging

- Route state-changing commands through `run_cmd` (or `run_cmd --visible` when the
  user should see live progress). It records the exact command, full output, and exit
  code in the session log — that record is the evidence behind your success messages.
- Use the `ui.sh` helpers (`success`/`warn`/`info`/`error_msg`) instead of raw `echo`
  for status lines; they mirror to the session log automatically.
- Pure read-only queries may run bare with `2>/dev/null` and a fallback.
- Never write to the session log directly; go through `session_write` if you need a
  custom level.

## `state.env` usage

- Add keys with `write_state_values "KEY=value" …` — it preserves unrelated keys.
- Read with `state_value KEY` and **always handle `N/A`** before treating a value as
  numeric or displaying it.
- Keys record *facts about what happened* (`TOTAL_FREED_MB`, `DEPLOYED_PRESET`), not
  module internals or configuration.
- Document new keys in the key inventory in [State-System.md](State-System.md) in the
  same change.

## Extending specific subsystems

**Health score** — new inputs go into `calculate_health_score` as an additional
deduction tier with documented thresholds. Keep the 0–100 scale and floor. Cache any
newly measured metric in a `SYS_*` global so displays reuse the scored value. Update
[Health-Score.md](Health-Score.md) in the same commit.

**Report** — every new line must originate from `state.env`, the snapshot, or a
direct measurement made in the report itself. Guard every value against `N/A`. If the
PDF should show it, extend `report_pdf.py` to read the same source — the PDF is a
pure consumer and must never re-measure.

**Maintenance sub-modules** — new file under `core/maintenance/`, sourced by
`maintenance.sh`, invoked between the cleanup and state-save phases. Follow the
preview → confirm → act → **verify** → report shape. Destructive actions: user
space only, confirmed counts only, cloud-synced paths excluded.

**Diagnostics** — additions must stay read-only toward the system (writes limited to
`state.env` and the session log). Threshold-based summary lines follow the existing
tier pattern.

**Storage Platform (`core/platform/storage/`)** — the first Platform service; see
[Storage-Architecture.md](Storage-Architecture.md) and
[architecture/0002-storage-platform.md](architecture/0002-storage-platform.md).
Two rules:
- **Everything outside this directory goes through `api.sh`'s `storage::*`
  functions.** Never read `.jbtoolkit/metadata.env`/`state.env` directly,
  never call `volume.sh`/`engine.sh` internals from another module. If the
  function you need doesn't exist yet, add it to `api.sh` as a thin wrapper
  — don't reach past it.
- **A new migration profile** (Photos Library, Steam Library, Docker, VMs,
  Cloud Sync, Backups, Media Libraries, an arbitrary directory) is a new
  directory under `core/platform/storage/profiles/<id>/`: a `profile.env`
  (`PROFILE_ID`, `PROFILE_LABEL`, `DEST_SUBDIR` — quote values with spaces,
  it's sourced as bash) plus a `scan.sh` defining exactly two callbacks,
  `storage_profile_<id>_source_root` and `storage_profile_<id>_scan`. Never
  touches `engine.sh`. If a new capability seems to need more than these two
  callbacks, that need is either generic enough to add to every profile's
  contract (update Storage-Architecture.md in the same change) or it doesn't
  belong in a profile at all — per-profile `execute`/`verify` hooks were
  explicitly rejected because copying and verification have zero
  profile-specific variance and must stay that way for the safety guarantee
  to hold.

**Deployment catalog** — the catalog is data, governed by the contracts in
[Catalog-Format.md](Catalog-Format.md). Two layers only, as of v2.2: an
application is a **directory** (`catalog/applications/<id>/app.conf`) so it
can grow assets later; every application declares its `INSTALL_METHOD`
(`brew`/`cask` are automated; `mas`/`pkg`/`dmg`/`manual` are honest manual
steps, never failures); a package identifier exists in exactly **one**
`app.conf` line, and you verify it against the real installation method
(`brew info --formula/--cask`) before committing it; `CATEGORY` places the
application in exactly **one** section of the Application Catalog browser
(as of v2.2.1 — one app, one category, no duplicate entries; see
[architecture/0007-catalog-consistency.md](architecture/0007-catalog-consistency.md))
— purely presentational, no Deployment logic ever branches on a category
name. A preset (one `[id]` section in `catalog/presets.conf`, one file for
all of them as of v2.2.1) is **nothing more than** `NAME`/`DESCRIPTION`/
`ORDER`/`APPS` — a flat list of application IDs. There is no bundle/profile
grouping layer to keep in sync; menus regenerate from data, never from code.
`JB_PICK=true` without a `JB_PICK_NOTE` is invalid: a recommendation without
its reasoning is just a favorite. Keep every file flat `KEY=value`,
human-editable in any text editor — no YAML, no JSON, no SQLite (applications
and presets are both parsed with the same `awk`-based reader as `state.env`,
presets.conf's `[id]` sections included; this is unrelated to the Storage
Platform's `profile.env`, which *is* `source`d as bash — don't confuse the
two formats). See
[Deployment-Architecture.md](Deployment-Architecture.md) for the current
pipeline and [architecture/0006-deployment-flattening.md](architecture/0006-deployment-flattening.md)
for why bundles/profiles were removed; [Deployment-Design.md](Deployment-Design.md)
is the pre-v2.2 design history.

As of v2.3.0 every application also carries `HOMEPAGE`, `LICENSE`,
`PACKAGE_TYPE`, and `ARCHITECTURE` — metadata with no consumer in Deployment
today, populated because the information is cheapest to gather at add-time,
not because anything reads it yet (see
[CATALOG_CONSTITUTION.md](CATALOG_CONSTITUTION.md) §8 and
[CATALOG_STANDARD.md](CATALOG_STANDARD.md) for the complete schema and the
philosophy behind it). `ID`/`PACKAGE` were renamed to `APP_ID`/`PACKAGE_NAME`
in the same pass; the old names are hard validation errors, not silent
no-ops, same treatment as the v2.0.0 `BREW`/`CASK` keys.

## Testing expectations

There is no test framework; verification is manual and honest:

1. `bash -n <file>` on every touched file (syntax gate — always).
2. `shellcheck` the touched files; fix what it flags or know why you didn't.
3. Run the affected flow end-to-end on a real machine and read the session log —
   confirm the `CMD`/`EXIT` entries show what you expected.
4. Exercise the failure path you added (decline the prompt, kill the network,
   whatever applies), not just the happy path.
5. Verify every user-visible message your change prints is true under both paths.

## Commits

Small, logical commits — one concern per commit, in the style of the existing
history. Subject line: imperative, specific ("Count confirmed deletions rather than
pre-scan estimates"), body explains *why* when the diff alone doesn't.

---

## Things contributors should NOT do

- **Don't make modules source or call each other.** Ever. Shared logic goes to
  `utils.sh`; shared data goes through `state.env`.
- **Don't duplicate shared utilities.** Before writing a helper, check `utils.sh` and
  [Module-Overview.md](Module-Overview.md) — `dir_size_mb`, `parse_selection`,
  `run_cmd`, the brew cache probably already do what you need.
- **Don't bypass `state.env`.** No custom dotfiles, no parsing another module's log
  output, no exported variables between modules.
- **Don't add menu clutter.** Menus stay at ~7 visible items. Depth over breadth: a
  submenu that answers one question beats a long list that answers none.
- **Don't introduce speculative abstractions.** No plugin registries, no config
  layers, no "manager" functions for a single caller. Build for the third use case
  when it arrives, not before.
- **Don't print success you didn't verify.** No `success` after a command whose exit
  code you ignored; no totals from pre-scan estimates.
- **Don't touch Homebrew state without invalidating the cache.** Any
  install/uninstall/upgrade/cleanup/bundle is followed by `brew_cache_reset()`.
- **Don't write outside user space** in maintenance paths, and don't delete anything
  without a preview-and-confirm gate.
- **Don't mix languages.** Spanish for the user, English for the code.
