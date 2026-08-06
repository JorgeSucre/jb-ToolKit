# Verification 0003: Boundary Verification

**Program entry:** [VERIFICATION_PROGRAM.md #0003](../VERIFICATION_PROGRAM.md#0003--boundary-verification)
**Verification Level(s):** Boundary
**Date:** 2026-08-06
**Role performing this verification:** Verification Engineer (see
[ENGINEERING_ROLES.md](../ENGINEERING_ROLES.md) — role, not identity)

## Purpose

Verify that every module stays within the architectural boundaries assigned
to it — that each layer only does what it is documented to do, distinct
from Dependency Verification (0002), which checked what a layer can *see*.
Per this task's Fundamental Rule, responsibilities were derived from
authoritative architecture documentation first; implementation was then
compared against those responsibilities, never the reverse.

## Scope

**In scope:** all ten rows of `docs/Deployment-Architecture.md`'s "Layer
responsibilities" table (the only granular, explicit "Explicitly NOT its
job" contract in the repository, and the Program entry's own named
primary source), checked against `core/deployment/*.sh` and `core/report.sh`;
Bootstrap, Diagnostics, and Maintenance checked against
`docs/Architecture.md`'s coarser "Subsystems" table one-line
responsibility summaries; `core/utils.sh` checked against
`docs/CONTRIBUTING.md`'s explicit three-part "when code goes in utils.sh"
test (the "God module" question); Platform (`core/platform/storage/`)
checked for a documented "services only" constraint.

**Explicitly not in scope:** a full line-by-line audit of every function in
every file (targeted evidence per documented constraint was used instead,
as in 0001/0002); `catalog/` data files (no behavioral boundary to check —
data, not code); `docs/engineering/` and `docs/architecture/` (process
documentation, not a runtime module with a responsibility boundary in the
sense this entry checks).

**Not checked at all:** exhaustive verification of every one of
`utils.sh`'s 46 functions against the three-part test — two representative
functions were sampled (see Confidence).

## Method

For each row/module: (1) extracted its documented responsibility and,
where available, its explicit "not its job" exclusions, directly from the
cited document, before looking at any code; (2) grepped the corresponding
implementation file(s) for evidence that would contradict the documented
exclusion (a decision call where none is allowed, a presentation call in a
logic-only file, a state mutation in a read-only renderer, etc.); (3) where
a candidate contradiction was found, traced its actual callers to rule out
a false positive (e.g., a `printf` used as a function's return-value
channel via command substitution is not "presentation"); (4) where the
task prompt's own illustrative wording ("Platform provides services only")
did not correspond to any text in an actual document, explicitly checked
for and confirmed its absence rather than treating the prompt's phrasing
as the contract (per the Fundamental Rule: architecture documentation is
authoritative, not the verification task's own illustrative language).
Every command and its literal output is reproduced in Evidence.

## Evidence

**E1.** `docs/Deployment-Architecture.md`, "Layer responsibilities" table
— reproduced in full; each row's "Explicitly NOT its job" column is the
primary contract for Findings 1–10 below.

**E2.** `grep -n "run_cmd\|brew install\|selection_add\|selection_toggle" core/deployment/catalog.sh` → no results.

**E3.** `grep -n "return 1\|exit 1\|CATALOG_ERRORS" core/deployment/doctor.sh` → no results (doctor.sh never fails/blocks).

**E4.** `grep -n "printf\|echo \|write_state\|write_kv" core/deployment/selection.sh` → two hits, both inside `app_incompatibility_reason()` (lines 100, 109). Read in context: both are the function's sole return-value mechanism (documented in its own header comment: "Prints the Spanish skip reason and returns 1..."). `grep -n "app_incompatibility_reason" core/deployment/*.sh` shows every call site (`menu.sh:233`, `selection.sh:155`, `render.sh:103`) captures the output via `reason="$(app_incompatibility_reason ...)"` — command substitution, never a direct write to the terminal.

**E5.** `grep -n "run_cmd\|selection_add\|selection_toggle\|brew install" core/deployment/planner.sh` → no results.

**E6.** `grep -n "selection_add\|selection_toggle\|selection_remove\|write_state\|SELECTED_APPS+=" core/deployment/render.sh` → no results.

**E7.** `grep -n "_app_matches_filter\|catalog_matches_query\|filter_mode" core/deployment/menu.sh` → 10+ hits, including the function definition `_app_matches_filter()` (line 48), its call inside the main render loop (`_app_matches_filter "$id" "$filter_mode" || continue`, line 222; `catalog_matches_query "$id" "$search_query" || continue`, line 223), and `filter_mode` being read and mutated directly within `menu.sh` (lines 186, 211, 279, 282). This code (search + JB-Picks/hardware filters) was added in v2.3.2. `docs/Deployment-Architecture.md`'s Menus row was itself last edited for v2.4.1 content (same row cites "responsive 1–3 column grid as of v2.4.1"), and in that same, recently-edited row, "filtering anything itself" is listed as explicitly not Menus' job.

**E8.** `grep -n "app_field\|catalog_field\|preset_field" core/deployment/install.sh` → no results.

**E9.** `grep -rn "^retry()" core/` → exactly one definition, `core/utils.sh:561`. `grep -rn "retry 3 5" core/` → two call sites, `core/bootstrap/brew.sh:203` and `core/deployment/install.sh:224`, both invoking the same shared function. `grep -rn "^run_cmd()" core/` → exactly one definition, `core/utils.sh:196`.

**E10.** `grep -n "if" core/deployment/transaction.sh` → zero real conditionals (all matches are comment lines containing the English word "if"); the file (141 lines) consists of `txn_begin`/`txn_finish`/`txn_export`, which stamp and write values with no branching decision logic.

**E11.** `docs/Reporting.md` line 41 and `docs/Execution-Flow.md`'s Module 5 section, item 2: "System section: fastfetch... CPU, RAM (own measured calculation), disk (single `df -H /`)" — documented as a live measurement of current system state. Item 4, separately: "Summary section driven entirely by `state.env` values." `core/report.sh:96` performs exactly this documented `df -H /` call for the System section, not for the state.env-driven Summary section.

**E12.** `wc -l core/utils.sh core/bootstrap.sh core/deployment.sh core/maintenance.sh core/diagnostics.sh core/report.sh` → `utils.sh` 732 lines / 46 functions (`grep -c "^[a-zA-Z_]*() {"`), largest file in `core/`, next largest `report.sh` at 294. `docs/CONTRIBUTING.md`'s "When code goes in utils.sh" states a three-part test (2+ consumers today, net code reduction, no new abstraction) and names `dir_size_mb`/`human_size` as examples. `grep -rl "dir_size_mb\b" core/ | grep -v utils.sh` → 5 consumer files; `grep -rl "human_size\b" core/ | grep -v utils.sh` → 2 consumer files. Both named examples independently confirmed to meet the "2+ consumers" prong.

**E13.** `grep -n "cleanup_\|preview_cleanup\|rm -rf\|find.*-delete" core/bootstrap.sh core/bootstrap/*.sh` (excluding `wizard.sh`, which legitimately hands off to the Deployment library) → no results.

**E14.** `grep -n "brew install\|start_deployment_flow\|run_application_catalog" core/maintenance.sh core/maintenance/*.sh` → no results.

**E15.** `grep -n "^source" core/diagnostics.sh` → `core/utils.sh`, `core/bootstrap/ui.sh` only (matches 0002's finding for this file).

**E16.** `grep -rn "services only\|Platform.*only\|only.*Platform" docs/Architecture.md docs/Storage-Architecture.md docs/architecture/0001-platform-philosophy.md` → no results. No document states this constraint. `grep -rn "ask_yes_no" core/platform/storage/*.sh` → 4 hits (`engine.sh` ×3, `volume.sh` ×1) — Platform does prompt the user directly. `docs/Storage-Architecture.md` line 317 explicitly documents interactive profile callbacks as part of its design ("Callbacks are just functions").

## Observations

| # | Observation | Evidence |
|---|---|---|
| 1 | Catalog, Doctor, Planner, Renderer, Installer, Transaction each show zero evidence of the specific action their documented "not its job" column excludes | E2, E3, E5, E6, E8, E10 |
| 2 | Selection's only `printf` calls are a documented return-value mechanism (not presentation), confirmed by tracing every call site to a command-substitution capture | E4 |
| 3 | Menus (`core/deployment/menu.sh`) actively implements search and category/pick/hardware filtering directly within itself — the exact action its own, recently-edited documentation row lists as explicitly not its job | E7 |
| 4 | The installation "Engine" pattern (`retry` + `run_cmd --visible`) is defined exactly once, in `core/utils.sh`, and reused (not reimplemented) by both its Bootstrap and Deployment call sites | E9 |
| 5 | `report.sh`'s live `df -H /` call is a documented, deliberate part of its "System section," textually distinct from the state.env-driven "Summary section" that the "not its job" exclusion (re-measuring/reconstructing *events*) actually targets | E11 |
| 6 | The two utils.sh functions CONTRIBUTING.md names as examples of its own placement criterion both independently verify as meeting it; the remaining 44 functions were not individually re-checked | E12 |
| 7 | Bootstrap and Maintenance show no evidence of performing each other's, or Deployment's, core responsibilities | E13, E14 |
| 8 | No document anywhere states "Platform provides services only" — this phrasing originates from the verification task's own illustrative "Questions" section, not from `docs/Architecture.md`, `docs/Storage-Architecture.md`, or `docs/architecture/0001-platform-philosophy.md`. Platform's direct use of `ask_yes_no` is therefore not checkable against a documented constraint, and the one document that does discuss Platform's interactive behavior (Storage-Architecture.md) describes it as intended | E16 |

## Result

| Claim checked | Result |
|---|---|
| Catalog performs data/access only, never decides what to install | VERIFIED |
| Doctor never fails validation or blocks | VERIFIED |
| Selection performs no presentation, planning, or persistence | VERIFIED WITH OBSERVATIONS (Observation 2 — a data-return `printf` could be misread as presentation without tracing callers) |
| Planner never executes or mutates selection | VERIFIED |
| Renderer never resolves, decides, or mutates | VERIFIED |
| Menus never filters or resolves anything itself | **ARCHITECTURAL VIOLATION** — real, active, currently-shipping code contradicts the currently-documented exclusion (Observation 3) |
| Installer never reads the catalog | VERIFIED |
| The installation engine pattern is not duplicated | VERIFIED |
| Transaction never makes decisions or estimates | VERIFIED |
| Reporting never re-measures or reconstructs past events | VERIFIED WITH OBSERVATIONS (Observation 5 — the live System-section measurement is a documented exception, not a violation, but is worth a reader's care not to conflate with the Summary section's constraint) |
| `utils.sh`'s placement criterion holds for its own named examples | VERIFIED WITH OBSERVATIONS (sampled 2 of 46 functions; see Confidence) |
| Bootstrap performs only Bootstrap responsibilities | VERIFIED |
| Maintenance performs only Maintenance responsibilities | VERIFIED |
| Diagnostics performs only Diagnostics responsibilities | VERIFIED |
| Platform "provides services only" | **NOT APPLICABLE** — no documented contract exists to check this claim against (Observation 8); per the Standard's Rule 4, absence of documentation is reported, not treated as a pass or a fail |

## Confidence

**High** for Observations 1, 3, 4, 5, 7, 8 — each is a direct `grep`
result (including confirmed absences) cross-checked against a directly
quoted document passage.

**Medium** for Observation 2 — required tracing three call sites to
confirm a negative (no direct terminal write), a slightly more inferential
step than a plain grep-for-presence/absence.

**Medium** for Observation 6 — the "God module" check for `utils.sh` was
proportionate sampling (2 of 46 functions against a documented 3-part
test), not exhaustive; a violation in one of the other 44 functions would
not have been caught by this pass.

**Low** for nothing in this report.

## Recommendations

Each traces to a specific Observation; none is speculative.

1. **Resolve the contradiction in `docs/Deployment-Architecture.md`'s
   Menus row** (Observation 3): either the documented exclusion
   ("filtering anything itself") needs to be narrowed to distinguish
   *display filtering* (search/category/pick/hardware — narrowing what's
   shown) from *selection filtering* (deciding what's installable —
   apparently the original intent, still correctly owned by
   Selection/Planner), or the filtering feature itself needs architectural
   reconsideration. Which of these is correct is an Engineering Architect
   decision — this verification can only confirm the contradiction exists
   and is real, not resolve it.
2. **Consider a full, exhaustive pass over `utils.sh`'s remaining 44
   functions** against CONTRIBUTING.md's three-part placement test
   (Observation 6), given its size relative to every other file in the
   repository — not because size alone is evidence of a violation, but
   because it was the only module in scope not checked exhaustively
   against its own documented criterion.
3. **Consider whether Platform's interactive behavior warrants an explicit
   documented boundary statement** (Observation 8) — not because evidence
   shows a violation (none was found; none could be checked), but because
   the absence of any stated contract here, on a topic significant enough
   to appear as an illustrative example in this verification's own task
   prompt, is itself worth a documented decision one way or the other.

## History

| Date | Result | Note |
|---|---|---|
| 2026-08-06 | Mixed — see Result table | Initial verification |
