# Architecture

JB Toolkit is a modular Bash application for macOS maintenance and deployment,
structured as a **menu-driven launcher that executes five independent module scripts
as child processes**. Modules share code by sourcing a common utility layer and share
runtime data through a file-based state system.

## Top-level layout

```
jb-ToolKit/
├── jb                      # Interactive launcher (entry point)
├── brewfile                # Package manifest (Brewfile format)
├── README.md               # User-facing documentation (Spanish)
├── docs/                   # Engineering documentation (this directory)
├── catalog/                # Deployment data: applications/bundles/profiles (+ reserved vendors/)
│                           #   Pure data — no code parses it yet (Deployment Phases 3–5 pending)
├── logs/                   # Runtime artifacts: state.env, session logs, snapshots, PDFs
└── core/
    ├── utils.sh            # Foundation layer — sourced by every module
    ├── bootstrap.sh        # Module 1: initial machine setup
    ├── diagnostics.sh      # Module 2: system scan + health score
    ├── maintenance.sh      # Module 3: cleanup + optimization
    ├── report.sh           # Module 4: executive report + PDF
    ├── report_pdf.py       # PDF generator (Python / reportlab)
    ├── deployment.sh       # Module 5: workstation deployment (launcher option 4)
    ├── deployment/         # Deployment sub-modules (see docs/Deployment-Architecture.md)
    │   ├── catalog.sh      # Catalog access, hierarchy queries, V1–V10 validator
    │   ├── doctor.sh       # Advisory maintainability diagnostics
    │   ├── resolve.sh      # Bundles → apps with provenance, compatibility filter
    │   ├── planner.sh      # Deployment Plan builder + export (PLAN_* contract)
    │   ├── render.sh       # Presentation: summary/explain/tree/confirmation/result
    │   ├── menu.sh         # Catalog-generated navigation, Custom, JB Picks browser
    │   ├── confirm.sh      # Confirmation loop; [I] executes the plan
    │   ├── transaction.sh  # Installation Transaction (execution record)
    │   └── install.sh      # Plan executor via the Bootstrap engine + verification
    ├── bootstrap/          # Bootstrap sub-modules
    │   ├── ui.sh           # Shared UI primitives (used by ALL modules)
    │   ├── stages.sh       # Numbered stage progress ([1/5], elapsed time)
    │   ├── brew.sh         # Homebrew install / validate / bundle sync
    │   ├── packages.sh     # Package selection, filtering, updates
    │   └── hardware.sh     # Hardware profile display, Rosetta detection
    └── maintenance/        # Maintenance sub-modules
        ├── cleanup.sh      # Cache / log / Trash / Homebrew cleanup
        ├── storage.sh      # Large-file scan, cloud sync, LaunchAgents
        ├── apps.sh         # App risk scoring and user-driven removal
        ├── performance.sh  # Performance profiles (light / aggressive / restore)
        └── state.sh        # Maintenance state lifecycle + executive summary
```

## Subsystems

| Subsystem | Location | Responsibility |
|---|---|---|
| **Launcher** | `jb` | Menu loop; runs modules via `bash <script>`; owns the session |
| **Foundation** | `core/utils.sh` | Config, colors, state I/O, session logging, `run_cmd`, health score, Homebrew access + query cache, size helpers, `parse_selection`, hardware primitives |
| **UI layer** | `core/bootstrap/ui.sh` | `print_section`, `success`/`warn`/`info`/`error_msg` (all also write to the session log), banner, completion footer, `ask_yes_no`, elapsed time |
| **Bootstrap** | `core/bootstrap.sh` + `core/bootstrap/*` | CLT check, Homebrew install, hardware-based recommendations, Brewfile filtering and sync, package updates |
| **Diagnostics** | `core/diagnostics.sh` | System summary, top processes, health score, state write |
| **Maintenance** | `core/maintenance.sh` + `core/maintenance/*` | Preview-confirm-clean workflow, storage analysis, app cleanup, performance profiles, post-score |
| **Reporting** | `core/report.sh`, `core/report_pdf.py` | Terminal executive report; optional PDF built from `state.env` + system snapshot |
| **Deployment** | `core/deployment.sh` + `core/deployment/*` | Catalog-driven menus, Deployment Planner, plan review, execution via the Bootstrap engine, Installation Transaction record (see [Deployment-Architecture.md](Deployment-Architecture.md)) |
| **State** | `logs/state.env` | Key-value persistence across module processes and sessions |

## Module dependency graph

```mermaid
graph TD
    JB[jb launcher] -->|bash| BOOT[core/bootstrap.sh]
    JB -->|bash| DIAG[core/diagnostics.sh]
    JB -->|bash| MAINT[core/maintenance.sh]
    JB -->|bash| DEP[core/deployment.sh]
    JB -->|bash| REP[core/report.sh]

    subgraph Foundation
        UTILS[core/utils.sh]
        UI[core/bootstrap/ui.sh]
    end

    JB -->|source| UTILS
    BOOT -->|source| UTILS
    DIAG -->|source| UTILS
    MAINT -->|source| UTILS
    REP -->|source| UTILS

    BOOT -->|source| UI
    DIAG -->|source| UI
    MAINT -->|source| UI
    REP -->|source| UI

    BOOT -->|source| STAGES[bootstrap/stages.sh]
    BOOT -->|source| BREW[bootstrap/brew.sh]
    BOOT -->|source| PKGS[bootstrap/packages.sh]
    BOOT -->|source| HW[bootstrap/hardware.sh]

    MAINT -->|source| CLEAN[maintenance/cleanup.sh]
    MAINT -->|source| APPS[maintenance/apps.sh]
    MAINT -->|source| PERF[maintenance/performance.sh]
    MAINT -->|source| MSTATE[maintenance/state.sh]
    MAINT -->|source| STOR[maintenance/storage.sh]

    DEP -->|source| UTILS
    DEP -->|source| UI
    DEP -->|source| DSUB[deployment/catalog.sh, resolve.sh,<br/>planner.sh, render.sh, menu.sh, confirm.sh]
    DEP -.->|reads| CATDATA[(catalog/)]

    REP -->|python3| PDF[core/report_pdf.py]

    UTILS -.->|reads/writes| STATE[(logs/state.env)]
    PDF -.->|reads| STATE
    PDF -.->|reads| SNAP[(system_snapshot_*.txt)]
```

Key property: **there are no dependencies between the four modules.** Bootstrap,
Diagnostics, Maintenance, and Report never source or call each other. They communicate
exclusively through `logs/state.env` and the shared session log.

## Process model

The launcher runs each module with `bash "$script"` — a **child process**, not a
`source`. Consequences:

- Module-level globals (e.g., `APP_METADATA_CACHE`, the Homebrew query cache) live and
  die with one module run. Nothing leaks between modules.
- Data that must survive a module run goes through `logs/state.env`
  (see [State-System.md](State-System.md)).
- The session identity (`JB_SESSION_LOG`, `JB_SYSTEM_SNAPSHOT`) is `export`ed by the
  launcher's `init_session`, so child modules inherit it via the environment. Each
  module also calls `init_session` defensively; it is a no-op when the variables are
  already set, which makes modules runnable standalone (a fallback session is created).

## Layering rules (as implemented)

1. `utils.sh` depends on nothing else in the project. Everything depends on it.
2. `ui.sh` depends only on `utils.sh` (colors, `session_write`). Despite living under
   `bootstrap/`, it is the UI layer for **all** modules.
3. Sub-modules (`bootstrap/*`, `maintenance/*`) are function libraries: they define
   functions and module-level variables but perform no work at source time beyond
   cheap initialization (e.g., an `uname -m` check).
4. Orchestrator scripts (`bootstrap.sh`, `maintenance.sh`, `diagnostics.sh`,
   `report.sh`) own control flow, ordering, and exit codes.

## Error-handling strategy

- Entry points enable strict-ish modes (`set -Eeuo pipefail` in `jb`, `bootstrap.sh`,
  `report.sh`; `maintenance.sh` omits `-e` and `diagnostics.sh` omits `-u` —
  see [Future-Roadmap.md](Future-Roadmap.md), Potential Future Improvements).
- Non-critical failures are absorbed with `|| true` or `|| warn "..."` so a cosmetic
  failure never aborts a maintenance run.
- Critical failures (no internet, no Homebrew, Brewfile sync failure) abort the module
  with `print_completion "false"` and a non-zero exit.
- `install_session_traps` (launcher only) wires `ERR` and `EXIT` traps that record the
  failing command, line, and exit code to the session log.
