# Verification 0003 (Module Contract Validation): Boundary Verification executed against `Deployment.Menu`'s Module Contract only

**Program entry:** [VERIFICATION_PROGRAM.md #0003](../VERIFICATION_PROGRAM.md#0003--boundary-verification)
**Verification Level(s):** Boundary
**Date:** 2026-08-06
**Role performing this verification:** Verification Engineer (see
[ENGINEERING_ROLES.md](../ENGINEERING_ROLES.md))

**Relationship to `0003-boundary-verification.md`.** This is not a
re-verification of that report and does not amend or supersede it. That
report checked `Deployment.Menu` against `Deployment-Architecture.md`. This
report checks the same module against a different, narrower authoritative
source — the `Deployment.Menu` Module Contract in
[MODULE_STANDARD.md §7](../../architecture/MODULE_STANDARD.md) — under an
explicit rule that no other architecture document may be consulted, even
where one exists and would settle a question faster. The subject under test
here is the Module Contract model itself, not `Deployment.Menu`'s
correctness.

## Purpose

Prove, or disprove, that a Module Contract alone contains enough
architectural information to execute Boundary Verification against
`core/deployment/menu.sh` — specifically, whether `Deployment.Menu`: owns
only its documented Responsibilities, respects every documented Constraint,
consumes only what `Consumes` allows, produces only what `Produces`
declares, and collaborates only with the collaborators named in
`Collaborates With` — using only the Contract text as the standard of
correctness, with no recourse to `Deployment-Architecture.md`,
`Architecture.md`, `Module-Overview.md`, ADRs, or prior Verification
Reports.

## Scope

**Authoritative source used:** `Deployment.Menu`'s Module Contract,
[MODULE_STANDARD.md §7](../../architecture/MODULE_STANDARD.md#7-worked-example-deploymentmenu),
verbatim, as it reads today. No other section of `MODULE_STANDARD.md` was
treated as authoritative over `Deployment.Menu` itself (§9's `Deployment.Catalog`
and `Platform` Contracts were read only to identify their own declared
`Collaborates With` claims naming `Deployment.Menu`, for cross-checking —
never as evidence about what `Deployment.Menu` itself is allowed to do).

**Evidence source:** `core/deployment/menu.sh` in full (359 lines), plus
direct `grep`/definition lookups into every file a function call in
`menu.sh` resolves to, to determine where each called function is actually
defined. This is evidence-gathering about the implementation, not
consultation of a forbidden architecture document — no `docs/` file outside
`MODULE_STANDARD.md` was read for architectural claims.

**Not checked:** whether `Deployment.Menu`'s real, intended architecture
(as `Deployment-Architecture.md` would state it) is itself sound. A finding
below that the Contract is silent on some real behavior is not a claim that
the behavior is wrong — only that the Contract does not say.

## Method

1. Extracted every atomic claim from `Deployment.Menu`'s Contract
   (Responsibilities ×3, Consumes ×3, Produces ×2, Collaborates With ×3,
   Constraints ×6 — 17 claims total) verbatim from `MODULE_STANDARD.md §7`.
2. Read `core/deployment/menu.sh` in full.
3. For each claim, located the specific line(s) of `menu.sh` that either
   satisfy or bear on it.
4. For every function `menu.sh` calls that it does not define itself, ran
   `grep -rn "^<fn>()" core/` to find its defining file, to determine the
   real collaborator set independent of what the Contract names.
5. Searched `menu.sh` for direct references to `SELECTED_APPS` and to
   `catalog/` paths, to check the `Consumes`/accessors-only claims without
   assuming the accessor functions behave as named.
6. Cross-checked one ambiguous term (`manual`, used both as a
   `selection_toggle` provenance argument in `menu.sh` and, per the
   Contract's Constraint 3, as a name for an install-track classification)
   against `selection.sh`'s parameter name and `planner.sh`'s comments, to
   determine whether they are the same concept or a lexical collision.

An independent Verification Engineer re-running steps 1–6 against the same
revision of `menu.sh` and the same Contract text would reach the same
per-claim conclusions — every conclusion below cites a specific line number.

## Evidence

**Responsibilities vs. code:**
```
menu.sh:108-122  _catalog_terminal_columns()   — 1/2/3-column breakpoints
menu.sh:153-175  _catalog_print_grid()          — row-major grid rendering
menu.sh:303-307  selection_toggle "$id" manual  — toggle applied via accessor
menu.sh:48-56    _app_matches_filter()          — filter_mode: "" | picks | hardware (2 modes, not 3)
menu.sh:223      catalog_matches_query "$id" "$search_query"  — text search
```

**Constraints vs. code:**
```
menu.sh: no write to SELECTED_APPS outside selection_toggle; filter_mode/
         search_query changes never touch selection state (grep for
         "SELECTED_APPS" in menu.sh returns only 3 comment lines, 0
         executable references)
core/deployment/selection.sh:92  app_incompatibility_reason() — defined in
         Selection, called (not reimplemented) at menu.sh:233
core/deployment/selection.sh:62  selection_toggle() { local app="$1"
         provenance="${2:-manual}" ... }  — "manual" here is a provenance
         tag, not an install-method track
core/deployment/planner.sh:8-10,80  comments: "...into automatic/manual
         tracks..." / "automatic track (brew/cask) or the manual track
         (mas/pkg/dmg/manual)" — a distinct classification, computed in
         planner.sh from INSTALL_METHOD, never referenced in menu.sh
menu.sh:191-193  categories built from list_app_categories() only
menu.sh:142      name="$(app_field "$id" NAME)" — no hardcoded name literal
         found anywhere in menu.sh
menu.sh:202-204  app_ids=() and cols reset once per outer while-loop
         iteration, populated once, read once at the "Selección:" prompt
         (line 267) before any mutation — numbering cannot change while
         awaiting input
menu.sh:111-121  stty size </dev/tty, then tput cols, then $COLUMNS —
         column count 1 path in _catalog_print_grid/_catalog_render_entry
         is a plain sequential printf loop, no terminal capability beyond
         ANSI color codes
```

**Consumes/Produces vs. code:**
```
grep -n 'SELECTED_APPS' menu.sh   → 3 hits, all comments (lines 24, 26, 177)
grep -n 'catalog/' menu.sh        → 0 hits
menu.sh:204  cols="$(_catalog_terminal_columns)"  — called every render,
         inside the outer while-loop, not once at screen open
```

**Collaborates With vs. real call graph** (every non-local function `menu.sh`
calls, and where each is defined):
```
selection_contains, selection_toggle, selection_count,
load_preset_into_selection, reset_selection      → core/deployment/selection.sh
app_field, apps_in_category, list_app_categories,
catalog_matches_query, apps_recommended_for_hardware → core/deployment/catalog.sh
detect_machine_family                             → core/bootstrap/hardware.sh
print_section                                      → core/bootstrap/ui.sh
has_external_display, parse_selection, warn        → core/utils.sh
build_plan_from_selection                          → core/deployment/planner.sh
run_plan_confirmation                              → core/deployment/confirm.sh
render_application_detail                          → core/deployment/render.sh
```

## Observations

| # | Observation | Evidence |
|---|---|---|
| 1 | Responsibilities claim 3 bundles four distinct narrowing mechanisms into one atomic claim ("text match and by category/JB-Pick/hardware-recommendation filter modes"), but `filter_mode`'s `case` statement recognizes only two toggle modes, `picks` and `hardware` — there is no `category` filter mode. Category is a display-grouping structure (every category always renders, in its own header) rather than a narrowing filter a technician can activate or deactivate. | `menu.sh:48-56` (case statement, no `category` branch); `menu.sh:265` (`[P] Solo JB Picks · [H] Recomendadas para este Mac` — no category-filter key offered) |
| 2 | The Contract's Bootstrap collaboration claim is stated as strictly one-directional and asserts `Deployment.Menu` has no awareness of Bootstrap ("Bootstrap initiates this relationship, Menu does not know Bootstrap exists"). Real code contradicts the second half of that sentence directly: `run_application_catalog` itself calls `detect_machine_family` (defined in `core/bootstrap/hardware.sh`) and `print_section` (defined in `core/bootstrap/ui.sh`) — an outbound call into Bootstrap-namespaced files, not merely being called by Bootstrap. | `menu.sh:195` (`detect_machine_family`); `menu.sh:206` (`print_section "🗂️ Catálogo de aplicaciones"`); definitions at `core/bootstrap/hardware.sh:57`, `core/bootstrap/ui.sh:13` |
| 3 | Three real, checkable call-graph edges exist from code inside `menu.sh` with no corresponding `Collaborates With` claim at all: `build_plan_from_selection` (`core/deployment/planner.sh:118`, called from `start_deployment_flow`), `run_plan_confirmation` (`core/deployment/confirm.sh:10`, called from `start_deployment_flow`), and `render_application_detail` (`core/deployment/render.sh:94`, called from `run_application_catalog`). None of Planner, Confirm, or Renderer appears in the Contract's `Collaborates With` list. | `menu.sh:287, 343, 345` |
| 4 | The Contract has no field stating which functions or line ranges of `menu.sh` constitute "`Deployment.Menu`" for verification purposes. `menu.sh` contains `run_application_catalog` (the screen itself), plus `start_deployment_flow` and `run_deployment_menu` (orchestration that calls into Planner and Confirm). Whether the latter two are "inside" this Contract is not decidable from the Contract text alone; Purpose's closing clause ("...the entry point into the Deployment workflow itself") reads as including them, which is the interpretation this report used, but the Contract never states this as a boundary. | `MODULE_STANDARD.md §7` Purpose; `menu.sh:323-346, 357-359` |
| 5 | `core/utils.sh` (source of `has_external_display`, `parse_selection`, `warn`, all called directly by `menu.sh`) is never named as a collaborator, and is also never named anywhere in the Contract model as a category of thing a Contract should or shouldn't list (shared infrastructure vs. a module in its own right). This report could not determine, from the Contract alone, whether omitting `core/utils.sh` from `Collaborates With` is a gap or a deliberate, correct exclusion. | `menu.sh:267 (read via parse_selection), 260/292 (warn), 197 (has_external_display)`; absence in `MODULE_STANDARD.md §5`'s `Collaborates With` definition of any stated exclusion for shared utility files |
| 6 | Constraint 3 ("must not classify... into automatic/manual install tracks") and a literal string in the code it governs (`selection_toggle "$id" manual` at `menu.sh:306`) share the word "manual" for two unrelated concepts — a selection-provenance tag (`selection.sh:62`, parameter name `provenance`) versus an install-method track (`planner.sh:8-10,80`, computed from `INSTALL_METHOD`). The Contract text does not warn of this collision; resolving it required reading `selection.sh`'s parameter name and `planner.sh`'s comments, neither of which is `menu.sh` itself. | `selection.sh:62`; `planner.sh:8-10,80`; `menu.sh:306` |
| 7 | Every other claim checked (Responsibilities 1–2; Constraints 1, 2, 4, 5, 6; all of Consumes; all of Produces; Collaborates With for Selection and Catalog) was fully and directly checkable from the Contract's own wording against `menu.sh`, with no ambiguity and no need to consult any other document. | See per-claim evidence above |

## Result

| Claim checked | Result |
|---|---|
| Responsibility 1 — responsive, column-adaptive rendering | VERIFIED |
| Responsibility 2 — toggle input applied via Selection accessors | VERIFIED |
| Responsibility 3 — narrows by text match | VERIFIED |
| Responsibility 3 — narrows by JB-Pick filter mode | VERIFIED |
| Responsibility 3 — narrows by hardware-recommendation filter mode | VERIFIED |
| Responsibility 3 — narrows by **category** filter mode | **ARCHITECTURAL VIOLATION** — no such filter mode exists in code; the claim as literally written is false for this sub-clause (Observation 1) |
| Constraint 1 — never silently narrows the Selected Applications set itself | VERIFIED |
| Constraint 2 — never independently determines compatibility | VERIFIED |
| Constraint 3 — never classifies into automatic/manual install tracks | VERIFIED WITH OBSERVATIONS (Observation 6 — holds, but only checkable by reading two files besides `menu.sh` and the Contract) |
| Constraint 4 — no hardcoded catalog-derived names | VERIFIED |
| Constraint 5 — numbering stable within a render | VERIFIED |
| Constraint 6 — column layout degrades without non-POSIX capability | VERIFIED |
| Consumes 1 — Selected Applications set via accessors only | VERIFIED |
| Consumes 2 — Catalog data via accessors only | VERIFIED |
| Consumes 3 — real terminal width at render time | VERIFIED |
| Produces 1 — Selected Applications set updates via Selection | VERIFIED |
| Produces 2 — rendered Application Catalog screen | VERIFIED |
| Collaborates With — `Deployment.Selection` | VERIFIED |
| Collaborates With — `Deployment.Catalog` | VERIFIED |
| Collaborates With — `Bootstrap` | **ARCHITECTURAL VIOLATION** — the claim's own "Menu does not know Bootstrap exists" clause is contradicted by direct calls into `core/bootstrap/hardware.sh` and `core/bootstrap/ui.sh` (Observation 2) |
| Real edges to Planner, Confirm, Renderer | **NOT COVERED BY ANY CLAIM** — not a Result State from the Standard's list, since no claim exists to evaluate as true or false (Rule 4: report the absence, don't invent a contract); recorded as Observation 3, not forced into a Result row |

No claim produced a `BOUNDARY VIOLATION`, `SHARED AUTHORITY`, or `NOT
APPLICABLE` result.

## Confidence

**High** on every row above except Constraint 3, where confidence is
**Medium** — not because the conclusion (holds) is in doubt, but because
reaching it required evidence outside both `menu.sh` and the Contract text
(Observation 6), which is a weaker evidentiary path than every other row,
each resolved from `menu.sh` and the Contract alone.

## Module Contract Validation

**1. Was the Module Contract sufficient to execute the verification?**
Mostly, but not completely. 14 of 17 claims were fully checkable from the
Contract's text and `menu.sh` alone, several of them (Consumes, Produces,
the accessor-only Constraints) more cleanly than a prose document would
have allowed. Three findings required stepping outside that boundary: one
Constraint needed a second file's parameter name to disambiguate a lexical
collision (Observation 6); the Bootstrap and category-filter findings
needed no outside document, but only because the Contract's own claims
happened to be self-falsifying against `menu.sh` directly — a lucky case,
not a property the model guarantees.

**2. Which parts became easier than with `Deployment-Architecture.md`?**
Consumes and Produces were the clearest gain: checking "never a raw
internal representation" reduced mechanically to `grep -n 'SELECTED_APPS'
menu.sh` and confirming every hit was a comment — a single command against
a single, named claim, rather than judging a paragraph. The Constraints
list gave five independently checkable, one-line facts where a prose table
cell would have required deciding, unaided, which sentence in a paragraph
was actually a rule versus color commentary.

**3. Which parts became harder?**
`Collaborates With` was harder, not easier, than expected — not because
the field's format is wrong, but because its **completeness** cannot be
checked from the Contract alone. A prose document under Dependency
Verification's normal method is checked by diffing its diagram against
every real `source`/call edge; here, the Contract lists three collaborators
and gives no way to know, from the Contract itself, that this list should
have been six. The gap was only found by independently enumerating every
function `menu.sh` calls and locating each definition — the exact
from-scratch reconstruction §3's Design Goals says this model exists to
eliminate. For Collaborates With specifically, in this instance, it did
not.

**4. Did you need architectural information that was not present in the
Module Contract? If yes, identify it precisely; do not invent it.**
Yes, in two distinct ways:
- To resolve Observation 6 (the `manual` collision), `selection.sh`'s
  `selection_toggle` parameter name (`provenance`) and `planner.sh`'s
  automatic/manual track comments were both necessary. Neither is present
  in, or referenced by, `Deployment.Menu`'s Contract.
- To determine whether Planner, Confirm, and Renderer *should* appear in
  `Collaborates With` (as opposed to merely *not* appearing), the actual
  architectural intent behind those three edges would be needed — and that
  intent, if documented anywhere, lives in exactly the kind of document
  this exercise was forbidden from consulting. This report does not know,
  and explicitly does not guess, whether these are correct undocumented
  relationships or real boundary problems; it can only report that the
  Contract is silent on all three.

**5. Did the Module Contract reduce subjective interpretation?**
For 14 of 17 claims, yes, substantially — each reduced to a `grep`/read
against one sentence, with no judgment call about what a paragraph "really
meant." For the three claims that produced findings, the Contract did not
reduce interpretation so much as relocate it: instead of judging whether a
paragraph "still sounds right" (the old failure mode this model was built
to fix), the judgment became "is this specific atomic claim, checked
against this specific line of code, true or false" — narrower and more
defensible, but still a judgment, and in the Collaborates With case, one
the Contract's completeness could not itself guarantee.

**6. Could Verification 0003 be executed in the future using Module
Contracts as its only architectural input?**

**Partial.** For `Responsibilities` and `Constraints` — the two fields §6
of `MODULE_STANDARD.md` itself names as what Boundary Verification
consumes — the answer is close to yes: every claim in both fields this
report checked was self-contained and independently falsifiable, and the
one genuine defect found (Responsibility 3's category sub-clause) was
caught *because* the claim was atomic enough to test, not despite it. But
this report's explicit scope also asked whether Menu consumes, produces,
and collaborates only as declared — and for `Collaborates With`
specifically, the Contract format has no mechanism to prove a negative:
nothing in the Contract, or in the model's own field definitions, would
have told a Verification Engineer working from the Contract alone that its
collaborator list was short by three real entries. That gap was found only
by reconstructing the call graph independently — the same manual,
from-scratch process the model exists to replace. Until `Collaborates
With`'s completeness can itself be checked against real evidence (e.g. by
generating the real call graph and diffing it against the field, the way
Dependency Verification already does under the current process), a Module
Contract is a sufficient replacement for `Deployment-Architecture.md`'s
prose for Responsibilities and Constraints, but not yet a safe sole
replacement for the collaborator inventory a full Boundary Verification
also needs to trust.

## Recommendations

*(Recorded per the Standard's Rule 2 — these do not change the Result
above, and are proposals for the Engineering Architect role, not findings
this report treats as authoritative on its own.)*

1. Responsibility 3's category sub-clause is either a stale claim (the
   filter mode existed and was removed) or a gap in `menu.sh` (the filter
   mode was intended and never built). Worth a one-line check against
   whichever document actually tracks that history before deciding which.
2. The three undeclared collaborators (Planner, Confirm, Renderer) and the
   Bootstrap-direction mismatch are exactly the kind of finding
   `MODULE_STANDARD.md §8`'s second bullet anticipated ("a Verification
   Engineer should attempt to actually execute... Boundary Verification
   against a hand-written module entry, to test whether... the claim
   format needs revision") — this report is that attempt, and its result
   suggests `Collaborates With` may need a way to be checked for
   completeness, not just per-claim correctness, before the model is
   relied on as a sole source.

## History

| Date | Result | Note |
|---|---|---|
| 2026-08-06 | See Result table above — mixed: 15 VERIFIED/VERIFIED WITH OBSERVATIONS, 2 ARCHITECTURAL VIOLATION, 1 real-edge set not covered by any claim | Initial verification |
