# Verification 0003 (Module Contract Validation, Corrected Contract): Boundary Verification executed against `Deployment.Menu`'s corrected Module Contract

**Program entry:** [VERIFICATION_PROGRAM.md #0003](../VERIFICATION_PROGRAM.md#0003--boundary-verification)
**Verification Level(s):** Boundary
**Date:** 2026-08-06
**Role performing this verification:** Verification Engineer (see
[ENGINEERING_ROLES.md](../ENGINEERING_ROLES.md))

**Relationship to prior reports.** `0003-boundary-verification.md` checked
`Deployment.Menu` against `Deployment-Architecture.md`. `0003-boundary-verification-module-contract-validation.md`
(the immediately preceding report) checked the *original* `Deployment.Menu`
Module Contract in isolation and found it insufficient in three ways. Between
that report and this one, the Engineering Architect role corrected the
Contract, tracing every change to a specific finding in that report. This
report treats the corrected Contract as if written by someone unfamiliar
with that history and re-derives every conclusion from `menu.sh` directly.
The prior report is cited below only to name which finding a given claim
corresponds to — never as evidence for whether that claim is true now.

## Purpose

Determine whether the corrected `Deployment.Menu` Module Contract is
sufficient, by itself, to perform Boundary Verification — repeating the
same evaluation as the prior report (ownership of Responsibilities,
respect for Constraints, Consumes/Produces/Collaborates With accuracy)
against the corrected text, from scratch, with no presumption that the
correction succeeded.

## Scope

**Authoritative source:** `Deployment.Menu`'s Module Contract,
[MODULE_STANDARD.md §7](../../architecture/MODULE_STANDARD.md#7-worked-example-deploymentmenu),
as it reads after the Phase 1 correction — 20 atomic claims (3
Responsibilities, 3 Consumes, 2 Produces, 6 Collaborates With, 6
Constraints; up from 17 before correction, reflecting the 3 collaborators
added).

**Evidence source:** `core/deployment/menu.sh`, plus fresh definition
lookups (`grep`) into every file a called function resolves to, plus two
lookups not performed in the prior report: `core/bootstrap/wizard.sh` (to
verify the Bootstrap-initiated half of the Bootstrap claim, which the prior
report did not independently re-check) and `selection.sh`'s `selection_add`
(to verify where the `manual` provenance value is actually written).

**Not checked:** `Architecture.md`, `Deployment-Architecture.md`,
`Module-Overview.md`, ADRs, or `0003-boundary-verification.md` (the
original, pre-Contract report) — all forbidden as architectural sources
under this task's rules.

## Method

Same as the prior report: every bullet under Responsibilities, Consumes,
Produces, Collaborates With, and Constraints extracted as one atomic claim;
each checked against a specific `menu.sh` line or a specific called
function's definition; no claim marked true on the strength of the prior
report's conclusion alone. Two claims (Bootstrap's inbound half, and the
`manual`-provenance clarification's accuracy) were checked against evidence
the prior report did not itself gather, specifically to avoid inheriting an
unverified assumption.

## Evidence

```
menu.sh:108-122, 153-175, 204     _catalog_terminal_columns / _catalog_print_grid,
                                    called every render loop iteration
menu.sh:303-307                    selection_toggle "$id" manual — accessor call
menu.sh:223                        catalog_matches_query — text match
menu.sh:48-56                      case "$filter_mode" in "" | picks | hardware —
                                    exactly two real filter modes, no third
menu.sh: 0 executable references to SELECTED_APPS (grep -n 'SELECTED_APPS' menu.sh
                                    → 3 hits, all comments)
menu.sh: 0 references to catalog/ paths
menu.sh:195                        detect_machine_family() — defined core/bootstrap/hardware.sh:57
menu.sh:206                        print_section() — defined core/bootstrap/ui.sh:13
core/bootstrap/wizard.sh:52,54     start_deployment_flow(...) called directly —
                                    confirms the Bootstrap-initiated half of the claim
core/deployment/selection.sh:46-51 selection_add() { ... SELECTED_APPS+="$app|$provenance" ... } —
                                    Selection writes the provenance value; Menu supplies it
                                    at the toggle call site (menu.sh:306)
menu.sh:343                        build_plan_from_selection — defined core/deployment/planner.sh:118
menu.sh:345                        run_plan_confirmation — defined core/deployment/confirm.sh:10
menu.sh:287                        render_application_detail — defined core/deployment/render.sh:94
core/deployment/selection.sh:92    app_incompatibility_reason() — defined in Selection, called
                                    (not reimplemented) at menu.sh:233
menu.sh:191-193, 142               categories from list_app_categories(); names from app_field();
                                    no hardcoded literal found
menu.sh:202-204, 267               app_ids/cols reset once per outer loop iteration, read once
                                    at the single "Selección:" prompt before any mutation
```

## Observations

| # | Observation | Evidence |
|---|---|---|
| 1 | Responsibility 3, corrected, now names exactly the two real filter modes the code implements (`picks`, `hardware`) plus text search — no third, unimplemented mode remains claimed. | `menu.sh:51-55` |
| 2 | The Bootstrap Collaborates With claim, corrected, now states both directions the code actually exhibits: Bootstrap calling into Menu's entry point (confirmed independently via `wizard.sh:52,54`, not previously checked in the prior report) and Menu calling directly into two Bootstrap-namespaced files. Both halves hold. | `wizard.sh:52,54`; `menu.sh:195,206` |
| 3 | The three collaborators added in the correction (`Deployment.Planner`, `Deployment.Confirm`, `Deployment.Renderer`) each name one real, single call site with a locatable definition. All three hold as stated. | `menu.sh:343,345,287` and the three target files' definitions |
| 4 | Constraint 3's added parenthetical, distinguishing selection-provenance `manual` from Planner's automatic/manual install-track classification, is accurate: `selection_add` (`selection.sh:46-51`) is what writes the provenance value into `SELECTED_APPS`, and `menu.sh:306` is where the value is supplied — the parenthetical's "recorded when... toggled here" describes the supply site, not the write site, a minor imprecision that does not make the clarification misleading. This claim no longer requires a Verification Engineer to consult `selection.sh` or `planner.sh` to avoid a false-positive reading — the ambiguity the prior report flagged (Observation 6, prior report) is resolved *within the Contract's own text*. | `selection.sh:46-51`; `menu.sh:306` |
| 5 | Two findings from the prior report were not, and could not be, addressed by any Contract correction: (a) the Contract still has no field stating which functions or line ranges of `menu.sh` constitute "`Deployment.Menu`" for verification purposes (prior report, Observation 4); (b) the Contract still gives no basis for deciding whether `core/utils.sh` (source of `has_external_display`, `parse_selection`, `warn`, all called directly by `menu.sh`) belongs in `Collaborates With` or is correctly excluded as shared infrastructure (prior report, Observation 5). Both concern what the **model's** seven fields can express, not what this **instance** states within them — Phase 1 correctly left both untouched, since fixing them would require adding a field or a model-level rule, not editing a Contract's prose. | Absence, confirmed by re-reading `MODULE_STANDARD.md §4-§5`'s field list: no field answers "which code is this module" or "should shared utility files appear in Collaborates With" |

## Result

| Claim checked | Result |
|---|---|
| Responsibility 1 — responsive, column-adaptive rendering | VERIFIED |
| Responsibility 2 — toggle input applied via Selection accessors | VERIFIED |
| Responsibility 3 — narrows by text match + JB-Pick + hardware filter modes | VERIFIED |
| Consumes 1 — Selected Applications set via accessors only | VERIFIED |
| Consumes 2 — Catalog data via accessors only | VERIFIED |
| Consumes 3 — real terminal width at render time | VERIFIED |
| Produces 1 — Selected Applications set updates via Selection | VERIFIED |
| Produces 2 — rendered Application Catalog screen | VERIFIED |
| Collaborates With — `Deployment.Selection` | VERIFIED |
| Collaborates With — `Deployment.Catalog` | VERIFIED |
| Collaborates With — `Bootstrap` (bidirectional, corrected) | VERIFIED |
| Collaborates With — `Deployment.Planner` | VERIFIED |
| Collaborates With — `Deployment.Confirm` | VERIFIED |
| Collaborates With — `Deployment.Renderer` | VERIFIED |
| Constraint 1 — never silently narrows the Selected Applications set itself | VERIFIED |
| Constraint 2 — never independently determines compatibility | VERIFIED |
| Constraint 3 — never classifies into automatic/manual install tracks (with disambiguation) | VERIFIED |
| Constraint 4 — no hardcoded catalog-derived names | VERIFIED |
| Constraint 5 — numbering stable within a render | VERIFIED |
| Constraint 6 — column layout degrades without non-POSIX capability | VERIFIED |

**20 / 20 claims verified.**

**The Module Contract is sufficient to perform Boundary Verification for
Deployment.Menu.**

This verdict is scoped precisely: it means every atomic claim the corrected
Contract makes is true and independently checkable against `menu.sh` alone.
It does not mean the Module Contract *model*'s two remaining, model-level
gaps (Observation 5 above) have been resolved — they haven't, and no
Contract correction could resolve them. Those gaps did not, in practice,
prevent this Contract from being written correctly or verified completely;
they remain open findings about the model's field coverage, not about this
instance's accuracy.

## Confidence

**High** on all 20 claims. Every claim resolved to a specific `menu.sh`
line and a specific target-function definition, with no claim requiring
inference or a document outside the permitted scope.

## Recommendations

*(Per the Standard's Rule 2 — do not change the Result above.)*

1. The two model-level gaps in Observation 5 are worth the Engineering
   Architect's attention independently of this exercise, since they will
   recur for every future module, not just `Deployment.Menu` — but
   resolving them requires touching the model (adding a field or a stated
   convention), which this task's rules correctly kept out of scope here.

## History

| Date | Result | Note |
|---|---|---|
| 2026-08-06 | 20/20 VERIFIED | Verification against the corrected Contract |
