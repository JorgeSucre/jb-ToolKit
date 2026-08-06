# Verification 0002: Dependency Verification

**Program entry:** [VERIFICATION_PROGRAM.md #0002](../VERIFICATION_PROGRAM.md#0002--dependency-verification)
**Verification Level(s):** Dependency
**Date:** 2026-08-06
**Role performing this verification:** Verification Engineer (see
[ENGINEERING_ROLES.md](../ENGINEERING_ROLES.md) — role, not identity)

## Purpose

Verify that module dependencies throughout the repository comply with the
architecture documented in `docs/Architecture.md`'s "Module dependency
graph." Answers exactly one question: do module dependencies comply with
the documented architecture? Not duplication, not complexity, not
implementation quality of what's inside a dependency — those are other
Verification Levels.

## Scope

**In scope:** every `source` statement in `jb` and every file under
`core/` (orchestrators `core/*.sh` and library files under
`core/bootstrap/`, `core/deployment/`, `core/maintenance/`,
`core/platform/storage/`); cross-module function-call evidence for the
highest-risk seams (Diagnostics↔Deployment, Diagnostics↔Maintenance,
Maintenance↔Deployment, Maintenance↔Bootstrap, Deployment↔Bootstrap);
the documented dependency graph in `docs/Architecture.md` as the
authoritative contract being checked against (Verification Ethics #5,
#6 — the documented contract is what's verified, not a personal or
task-prompt preference; see Verification-System Observation 1 below for
why `docs/Architecture.md`, not the task's own illustrative example, was
treated as authoritative).

**Explicitly not in scope:** `catalog/` and `docs/engineering/` were
confirmed to have no `source` relationship to `core/` (catalog is data,
not shell code; the engineering layer is documentation) and were not
further analyzed. A full, exhaustive function-by-function call-graph audit
of every function in every file was not performed — targeted greps on
named, representative functions/namespaces were used instead (see
Method). A full encapsulation audit (whether a module reaches into
another's *internal data shape*, not just whether it calls an undeclared
function) is Program entry 0011 and was not performed here.

## Method

1. Extracted every `source` statement from `jb` and all six `core/*.sh`
   orchestrators via `grep -n "^source" <file>`.
2. Extracted every `source` statement from every file under
   `core/bootstrap/`, `core/deployment/`, `core/maintenance/`,
   `core/platform/storage/` (including `profiles/`) the same way, to
   check for sourcing that happens below the orchestrator level (a
   precondition for circular dependencies).
3. Compared the resulting graph, edge by edge, against
   `docs/Architecture.md`'s "Module dependency graph" mermaid diagram and
   its accompanying "shared function libraries" prose paragraph.
4. Grepped for three specific cross-module signals to detect hidden
   coupling without a full call-graph: the `storage::` namespace (expected
   confined to Maintenance + Platform), the deployment-entry function
   `start_deployment_flow` (expected defined in the Deployment library,
   called only from `core/deployment.sh` and `core/bootstrap/wizard.sh`),
   and targeted negative checks (Diagnostics/Maintenance/Deployment
   grepped for each other's namespaced functions, expecting zero hits).

Every command and its literal output is reproduced in Evidence. Any
independent Verification Engineer running the same commands against the
same revision will get the same output.

## Evidence

**E1.** `grep -n "^source" jb core/bootstrap.sh core/diagnostics.sh core/maintenance.sh core/deployment.sh core/report.sh`:
```
jb:                 core/utils.sh
bootstrap.sh:       core/utils.sh, core/bootstrap/ui.sh, core/bootstrap/stages.sh,
                    core/bootstrap/brew.sh, core/bootstrap/hardware.sh,
                    core/deployment/{catalog,selection,planner,render,menu,
                    confirm,transaction,install}.sh, core/bootstrap/wizard.sh
diagnostics.sh:     core/utils.sh, core/bootstrap/ui.sh
maintenance.sh:     core/utils.sh, core/bootstrap/ui.sh,
                    core/maintenance/{cleanup,apps,performance,state,storage}.sh,
                    core/platform/storage/{volume,plan,transaction,engine,api}.sh
deployment.sh:      core/utils.sh, core/bootstrap/ui.sh, core/bootstrap/hardware.sh,
                    core/deployment/{catalog,doctor,selection,planner,render,
                    menu,confirm,transaction,install}.sh
report.sh:          core/utils.sh, core/bootstrap/ui.sh
```

**E2.** `grep -n "^source" core/deployment/*.sh core/bootstrap/*.sh core/maintenance/*.sh` →
zero results. No library file under these three directories sources
anything.

**E3.** `find core/platform -name "*.sh" | xargs grep -n "^source"` →
`core/platform/storage/engine.sh:66: source "$dir/profile.env"` — a
dynamic path, resolved at runtime to whichever profile
(`profiles/home/profile.env` or `profiles/downloads/profile.env`) is
selected. `find core/platform/storage -iname "*profile*"` confirms both
files exist under `profiles/`.

**E4.** `docs/Architecture.md`, "Module dependency graph" (mermaid block,
lines ~79–130): shows `BOOT --> HW[bootstrap/hardware.sh]` as the only
edge into `hardware.sh`. No `DEP --> HW` edge exists anywhere in the file
(`grep -n "hardware" docs/Architecture.md` returns exactly two hits: the
directory-tree comment at line 44 and the diagram edge at line 107 — both
Bootstrap-only).

**E5.** `core/deployment.sh`, line 13: `source
"$BASE_DIR/core/bootstrap/hardware.sh"` — a real, direct source statement,
confirmed by direct read of the file.

**E6.** `grep -n "detect_machine_family\|has_external_display" core/deployment/*.sh`:
```
core/deployment/render.sh:183:    detect_machine_family
core/deployment/render.sh:184:    family="$MACHINE_FAMILY"
core/deployment/render.sh:185:    has_external_display && has_ext=1
core/deployment/menu.sh:195:    detect_machine_family
core/deployment/menu.sh:196:    family="$MACHINE_FAMILY"
core/deployment/menu.sh:197:    has_external_display && has_ext=1
```
Both functions are defined in `core/bootstrap/hardware.sh`. This is an
active, load-bearing call, not dead/defensive sourcing.

**E7.** `docs/Architecture.md`'s "shared function libraries" paragraph
names exactly three shared libraries: `core/bootstrap/ui.sh`,
`core/deployment/*.sh`, `core/platform/storage/*.sh`.
`core/bootstrap/hardware.sh` is not among them.

**E8.** Comparing E1's `bootstrap.sh` and `deployment.sh` deployment-library
source lists: `bootstrap.sh` sources 8 files (catalog, selection, planner,
render, menu, confirm, transaction, install); `deployment.sh` sources 9
(the same 8 plus `doctor.sh`). `docs/Architecture.md`'s `DSUB` node text
lists exactly the same 8 files `bootstrap.sh` sources — `doctor.sh` is not
named in the diagram at all, despite being a real file
`core/deployment.sh` sources (`grep -n "doctor.sh" core/deployment.sh` →
line 15).

**E9.** `grep -rln "storage::" core/` → exactly
`core/maintenance.sh`, `core/platform/storage/api.sh`,
`core/platform/storage/volume.sh`. No hit outside Maintenance/Platform.

**E10.** `grep -rn "start_deployment_flow" core/` → defined once
(`core/deployment/menu.sh:323`), called from
`core/deployment/menu.sh:358` (`run_deployment_menu`'s own forward) and
`core/bootstrap/wizard.sh:52,54`. No other call site anywhere in `core/`.

**E11.** Targeted negative greps, each returning zero results:
`grep -n "storage::\|run_application_catalog\|start_deployment_flow\|cleanup_homebrew\|preview_cleanup\|run_apps_cleanup" core/diagnostics.sh`;
`grep -rn "start_deployment_flow\|run_application_catalog\|validate_catalog\|install_clt\|install_brew\b" core/maintenance.sh core/maintenance/*.sh`;
`grep -rn "storage::\|cleanup_homebrew\|preview_cleanup\|run_apps_cleanup\|run_performance_optimization" core/deployment.sh core/deployment/*.sh`.

## Observations

| # | Observation | Evidence |
|---|---|---|
| 1 | No orchestrator (`core/*.sh`) sources or is sourced by another orchestrator; all cross-orchestrator interaction is via `logs/state.env` (per E1, no orchestrator path appears as a source target of another) | E1 |
| 2 | No library file under `core/bootstrap/`, `core/deployment/`, or `core/maintenance/` sources anything — every dependency edge originates at the orchestrator level, with one documented exception (Observation 3) | E2 |
| 3 | `core/platform/storage/engine.sh` sources a profile's `profile.env` via a dynamic (runtime-resolved) path, not a static one — the mechanism behind the documented "pluggable profiles" claim | E3 |
| 4 | `core/deployment.sh` sources `core/bootstrap/hardware.sh` and actively calls two of its functions; this edge does not appear in `docs/Architecture.md`'s dependency diagram, and `hardware.sh` is not listed among the three files/directories the same document names as shared infrastructure | E4, E5, E6, E7 |
| 5 | `core/bootstrap.sh`'s and `core/deployment.sh`'s deployment-library source lists have drifted: `deployment.sh` sources `doctor.sh`, `bootstrap.sh` does not, and the documented `DSUB` library node lists only the 8 files `bootstrap.sh` sources, silently omitting the 9th file a real orchestrator depends on | E8 |
| 6 | The `storage::` namespace is confined exactly to its two documented consumers (Maintenance orchestrator, Platform library itself); no leakage found | E9 |
| 7 | `start_deployment_flow`, the documented single entry point through which Bootstrap consumes the Deployment library, has exactly the call sites the architecture describes and no others | E10 |
| 8 | No cross-module function call found between Diagnostics, Maintenance, and Deployment beyond what is already documented | E11 |

## Result

| Claim checked | Result |
|---|---|
| No dependency exists between module orchestrators | VERIFIED |
| No circular dependency exists in the `source` graph | VERIFIED |
| `core/bootstrap/ui.sh` is shared infrastructure sourced by every orchestrator as documented | VERIFIED |
| `core/platform/storage/*.sh` is sourced only by Maintenance, as documented | VERIFIED |
| `core/deployment/*.sh` is sourced by both Deployment and Bootstrap, as documented | VERIFIED WITH OBSERVATIONS (Observation 5 — the two source lists have already drifted by one file) |
| `core/deployment.sh`'s dependency on `core/bootstrap/hardware.sh` is documented | **ARCHITECTURAL VIOLATION** — a real, active, load-bearing dependency exists in the implementation with no corresponding edge or classification in the documented graph (Observation 4) |
| `docs/Architecture.md`'s `DSUB` library-node inventory matches what `core/deployment.sh` actually sources | **ARCHITECTURAL VIOLATION** — `doctor.sh` is sourced but not listed (Observation 5) |
| The `storage::` namespace respects its documented boundary | VERIFIED |
| Bootstrap's consumption of the Deployment library goes exclusively through `start_deployment_flow`, as documented | VERIFIED |
| No hidden coupling exists between Diagnostics, Maintenance, and Deployment | VERIFIED, within the scope of the specific signals checked (see Confidence) |
| `catalog/` has no `source`-level dependency relationship with `core/` | VERIFIED (data, not shell code — confirmed by scope check, not by exhaustive search) |

## Confidence

**High** for Observations 1, 2, 4, 5, 6, 7 — each is a direct `grep`
count or line citation compared against another direct citation; the
`hardware.sh` finding in particular (Observation 4) is corroborated by
three independent pieces of evidence (the diagram, the prose list, and
the active call sites), not a single grep.

**Medium** for Observation 8 (no hidden coupling found) — this was
established through targeted, named-function greps on the highest-risk
seams, not an exhaustive call-graph analysis of every function in every
file; a coupling through a function name not anticipated in the target
list would not have been caught by this method.

**Low** for nothing in this report — every claim above is backed by
directly reproduced command output.

## Recommendations

Each traces to a specific Observation; none is speculative.

1. **Add the missing `core/deployment.sh → core/bootstrap/hardware.sh`
   edge to `docs/Architecture.md`'s dependency diagram**, and decide
   whether `hardware.sh` should join the documented "shared function
   libraries" list (it is consumed by two orchestrators, the same
   condition that triggered `ui.sh`, `deployment/*.sh`, and
   `platform/storage/*.sh` being classified that way) (Observation 4).
2. **Add `doctor.sh` to the `DSUB` library node's file list**, or state
   explicitly that Bootstrap's Deployment-library subset intentionally
   excludes it (Observation 5).
3. Both of the above are documentation corrections with no implementation
   change implied — whether they also warrant a structural fix (e.g., one
   shared file listing the Deployment library's files instead of it being
   duplicated across two orchestrators, which is the underlying condition
   that let Observation 5 happen unnoticed) is an Engineering Architect
   decision, not something this verification recommends on its own.

## History

| Date | Result | Note |
|---|---|---|
| 2026-08-06 | Mixed — see Result table | Initial verification |
