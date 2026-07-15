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
    MENU -->|4| R[bash core/report.sh]
    MENU -->|5| EXIT([exit 0])
    B --> PAUSE[pause: Enter to return]
    D --> PAUSE
    M --> PAUSE
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

Five user-visible stages (`print_stage`, counter `[n/5]` with per-stage elapsed time).

```mermaid
flowchart TD
    A[Check internet: ping github.com] -->|fail| ABORT1([exit 1])
    A --> B[Stage 1: install_clt<br/>xcode-select, poll up to 5 min]
    B --> C[Admin check: dseditgroup → HAS_SUDO]
    C --> D[install_brew: up to 3 attempts<br/>curl installer → run --visible]
    D -->|fail| ABORT2([print_completion false, exit 1])
    D --> E[configure_brew + validate_brew<br/>resolve BREW_BIN, eval shellenv]
    E --> F[Stage 2: update_brew_indexes<br/>skip if FETCH_HEAD < 24h old]
    F --> G[Stage 3: detect_rosetta + print_hardware_summary]
    G --> H[select_brewfile: arch variant<br/>Brewfile.apple / Brewfile.intel fallback]
    H --> I[offer_hardware_recommendations<br/>machine-family package suggestions]
    I --> J[select_optional_packages<br/>interactive multi-select]
    J --> K[Stage 4: prepare_brewfile → /tmp copy]
    K --> L[filter_brewfile_to_selection<br/>keep fastfetch + selected; validate result]
    L -->|fail| ABORT3([cleanup + exit 1])
    L --> M[build_external_package_list<br/>installed vs Brewfile diff]
    M --> N[ask_external_package_updates]
    N --> O[build_outdated_package_list<br/>cached brew outdated ∩ Brewfile]
    O --> P[update_toolkit_packages<br/>brew upgrade each + cleanup + brew_cache_reset]
    P --> Q[update_external_packages<br/>fresh outdated query, user-approved only]
    Q --> R[sync_brewfile: retry 3× brew bundle]
    R -->|fail| ABORT4([cleanup + exit 1])
    R --> S[Verify fastfetch actually installed]
    S -->|missing| ABORT5([exit 1])
    S --> T[Stage 5: summaries, cleanup temp Brewfile,<br/>print_completion]
```

Bootstrap is the only module with hard abort points: everything downstream of a
missing Homebrew or failed bundle would be meaningless.

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

## Module 4 — Report (`core/report.sh`)

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
