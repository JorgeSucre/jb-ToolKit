# Execution Flow

## Launcher lifecycle (`jb`)

```mermaid
flowchart TD
    START([./jb]) --> SRC[source core/utils.sh]
    SRC --> SESS[init_session:<br/>create session log + system snapshot,<br/>export JB_SESSION_LOG / JB_SYSTEM_SNAPSHOT]
    SESS --> TRAPS[install_session_traps<br/>ERR + EXIT recorders]
    TRAPS --> MENU{Menu loop}
    MENU -->|1| B[bash core/bootstrap.sh]
    MENU -->|2| D[bash core/diagnostics.sh]
    MENU -->|3| M[bash core/maintenance.sh]
    MENU -->|4| DEP[bash core/deployment.sh]
    MENU -->|5| R[bash core/report.sh]
    MENU -->|6| EXIT([exit 0])
    B --> PAUSE[pause: Enter to return]
    D --> PAUSE
    M --> PAUSE
    DEP --> PAUSE
    R --> PAUSE
    PAUSE --> MENU
```

Details that matter:

- `init_session` runs **once per launcher session**. It creates
  `logs/session_<stamp>.log`, generates `logs/system_snapshot_<stamp>.txt`, records
  both basenames in `state.env`, and prunes each artifact family to the 20 most
  recent. Modules inherit the session via exported environment variables; their own
  `init_session` call is a guard that only fires when run standalone.
- `run_script` logs launch/exit of each module and prints an error line if the module
  exits non-zero — but returns to the menu either way. A failed module never kills
  the launcher.
- `Ctrl-C` is trapped to a clean "👋 Saliendo…" exit.

## Module 1 — Bootstrap (`core/bootstrap.sh`)

Five user-visible stages (`print_stage`, counter `[n/5]` with per-stage elapsed
time). Bootstrap owns the machine's base tooling; all software selection lives in
the Deployment library, reached through the onboarding wizard.

```mermaid
flowchart TD
    A[Check internet: ping github.com] -->|fail| ABORT1([exit 1])
    A --> B[Stage 1: install_clt<br/>xcode-select, poll up to 5 min]
    B --> C[Admin check: dseditgroup → HAS_SUDO]
    C --> D[install_brew: up to 3 attempts<br/>curl installer → run --visible]
    D -->|fail| ABORT2([print_completion false, exit 1])
    D --> E[configure_brew + validate_brew<br/>resolve BREW_BIN, eval shellenv]
    E --> F[Stage 2: update_brew_indexes<br/>skip if FETCH_HEAD < 24h old]
    F --> G[ensure_base_tools: fastfetch via the engine,<br/>verified after install]
    G -->|missing after install| ABORT3([print_completion false, exit 1])
    G --> H[offer_package_updates:<br/>preview → confirm → upgrade each →<br/>verify remaining with fresh query]
    H --> I[Stage 3: detect_rosetta + print_hardware_summary]
    I --> J[Stage 4: run_onboarding_wizard<br/>validate catalog → ¿Cómo se usará este Mac?]
    J -->|Omitir| K
    J -->|preset / empezar vacío| DEP[start_deployment_flow — the SAME function<br/>the Deployment menu calls:<br/>Application Catalog → planner → confirmation → installer]
    DEP --> K[Stage 5: optimization summary,<br/>final result, print_completion]
```

Bootstrap is the only module with hard abort points: everything downstream of a
missing Homebrew or missing base tools would be meaningless. An invalid catalog
does **not** abort Bootstrap — the wizard is skipped with a warning, because the
base setup is still valuable.

## Module 2 — Diagnostics (`core/diagnostics.sh`)

1. `fastfetch` system summary if installed; otherwise a manual CPU/RAM/disk/uptime
   summary built from `sysctl`, cached score metrics, `df`, and `uptime`.
2. `calculate_health_score` — one call computes the score **and** caches
   `SYS_CPU_LOAD`, `SYS_RAM_PCT`, `SYS_DISK_PCT` for reuse (single measurement,
   consistent display).
3. Top-5 unique processes by CPU (`ps` + dedupe by lowercased basename).
4. Health score rendered as a 10-segment bar with color-coded status label.
5. State write: `SCORE_BEFORE`/`SCORE_AFTER` (both set to the current score — a
   diagnostic defines the new baseline), `LAST_DIAGNOSTIC`, cached metrics.
6. Executive summary (threshold-based bullets) and a recommendation to run
   Maintenance.

Diagnostics is **read-only** with respect to the system; its only writes are
`state.env` and the session log.

## Module 3 — Maintenance (`core/maintenance.sh`)

```mermaid
flowchart TD
    A[initialize_state:<br/>zero counters, carry SCORE_AFTER → SCORE_BEFORE] --> B[Quick checks: Spotlight, swap pressure]
    B --> C[preview_cleanup: scan counts + size estimates<br/>labeled with ~]
    C --> D{ask_yes_no:<br/>¿Continuar?}
    D -->|no| SKIP[MAINTENANCE_SKIPPED=true<br/>exit 0 — nothing touched]
    D -->|yes| E[cleanup_homebrew<br/>before/after measured]
    E --> F[cleanup_caches → cleanup_logs → cleanup_trash<br/>find -delete, then re-count:<br/>confirmed = initial − remaining]
    F --> G[run_storage_analysis:<br/>cloud sync status, large files ≥1GB,<br/>LaunchAgents listing — read-only]
    G --> H[run_apps_cleanup:<br/>score apps, show top 12,<br/>user selects → move to ~/.Trash]
    H --> I[run_performance_optimization:<br/>menu — light / aggressive / restore / skip]
    I --> J[calculate_post_maintenance_score]
    J --> K[save_maintenance_state → state.env]
    K --> L[print_maintenance_summary:<br/>freed MB, items removed, profile, score delta]
    L --> M[Safety claims footer + elapsed + completion]
```

The decline path is a first-class flow: preview → "no" → zero mutations → clean exit.

## Module 4 — Deployment (`core/deployment.sh`)

One workflow, one selection model — see
[Deployment-Architecture.md](Deployment-Architecture.md) and
[architecture/0006-deployment-flattening.md](architecture/0006-deployment-flattening.md)
for why this replaced the earlier Profiles→Bundles→Applications hierarchy.

```mermaid
flowchart TD
    A[Validate catalog V1–V9<br/>invalid = abort, name the files] --> B[Quick Presets: flat list from data<br/>+ Empezar vacío, 0 nesting]
    B -->|preset or empty| LOAD[load_preset_into_selection<br/>or reset_selection<br/>incompatible apps recorded, never silent]
    LOAD --> HWFOLD[apply_hardware_recommendations:<br/>HW_RECOMMEND ∩ this machine,<br/>not yet installed, folded into the SAME selection]
    HWFOLD --> CAT[Application Catalog:<br/>one continuous list grouped by CATEGORY,<br/>toggle add/remove, JB_PICK apps marked ⭐ inline,<br/>incompatible apps shown ⛔ not selectable]
    CAT -->|0| CANC0[Selection cancelled] --> B
    CAT -->|Enter| E[Planner: build_plan_from_selection —<br/>classifies SELECTED_APPS into<br/>automatic track, manual track, named JB Picks]
    E --> H[Confirmation screen: preset,<br/>automatic/manual/pick/compat-exclusion counts]
    H -->|E| X[Explain view: provenance,<br/>manual steps + URLs, reasons] --> H
    H -->|G| T[Diff view: preset vs. final selection<br/>kept / added / removed] --> H
    H -->|0| B
    H -->|I| GATE{ask_yes_no:<br/>¿Preparar este equipo?}
    GATE -->|no| CANC[Cancelled transaction recorded] --> H
    GATE -->|yes| EXPORT[Export plan → logs/] --> PART[Partition: already installed<br/>brew query / Applications check]
    PART --> PRE[Pre-flight, read-only:<br/>brew info per pending package<br/>✓ available · ❌ no disponible · ✋ manual]
    PRE -->|unavailable found| GATE2{¿Continuar sin ellas?}
    GATE2 -->|no| CANC
    GATE2 -->|yes| ENG
    PRE -->|all available| ENG[Engine PER APP:<br/>retry 3 5 brew install / --cask]
    ENG --> VERIFY[brew_cache_reset →<br/>per-app verification]
    VERIFY --> DONE[Transaction + state.env +<br/>result screen: named outcomes]
    DONE --> URLS[Offer download page<br/>per manual app] --> B
```

The planner is the only decision-maker past selection; the installer executes
plan records verbatim (they carry method + package specs — it never reads the
catalog). Each application installs independently: one failure or unavailable
package never aborts the rest. Results are **verified outcomes**: installed
counts come from a fresh Homebrew query, manual steps are named and never
counted as failures, failures carry their reasons, and the Installation
Transaction (`logs/deployment_txn_*.env`) records what actually happened. CLI:
`--validate`, `--doctor`, `--resolve`, `--explain`, `--tree`, `--plan` — six
representations of the same plan (CLI plans load a preset with zero manual
edits; the Application Catalog is interactive-only).

## Module 5 — Report (`core/report.sh`)

1. Double-run guard: `JB_REPORT_ALREADY_RUN` env check.
2. System section: fastfetch (host/OS) or fallback, CPU, RAM (own measured
   calculation), disk (single `df -H /`), Homebrew formula/cask counts (cached
   queries).
3. Score comparison: `SCORE_BEFORE` vs `SCORE_AFTER` from `state.env` with delta.
4. Summary section driven entirely by `state.env` values (`TOTAL_FREED_MB`,
   `FILES_REMOVED`, `PERFORMANCE_PROFILE`, `LAST_MAINTENANCE`), each guarded
   against `N/A`.
5. Optional PDF: checks `reportlab`, offers `pip install --user`, exports
   `JB_PDF_OUTPUT`, runs `report_pdf.py`, verifies the file exists before claiming
   success, records `LAST_PDF_REPORT`.
6. Generated-artifacts listing: PDF, snapshot, session log — each verified with
   `-f` before being reported as available.

See [Reporting.md](Reporting.md) for the data pipeline.
