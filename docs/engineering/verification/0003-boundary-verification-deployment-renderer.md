# Verification 0003 (Module Contract Validation): Boundary Verification executed against `Deployment.Renderer`'s Module Contract

**Program entry:** [VERIFICATION_PROGRAM.md #0003](../VERIFICATION_PROGRAM.md#0003--boundary-verification)
**Verification Level(s):** Boundary (broadened to also check Consumes/
Produces/Collaborates With, per the pattern established for `Deployment.Menu`,
`Deployment.Planner`, `Deployment.Selection`, and `Deployment.Confirm`)
**Date:** 2026-08-06
**Role performing this verification:** Verification Engineer (see
[ENGINEERING_ROLES.md](../ENGINEERING_ROLES.md))

**Relationship to other reports.** This checks `Deployment.Renderer`'s
Module Contract ([MODULE_STANDARD.md §13](../../architecture/MODULE_STANDARD.md))
against `core/deployment/render.sh` and every real caller/callee it
touches. `Deployment-Architecture.md` and `Architecture.md` were not
consulted as architectural sources. `Deployment.Menu`'s adopted Contract
(§7) was read only to check one specific cross-reference this Contract's
own text names — never as an architectural source for what
`Deployment.Renderer` itself should do.

## Purpose

Determine whether every atomic claim in `Deployment.Renderer`'s Module
Contract holds true against `core/deployment/render.sh` and its real
collaborators, with particular attention to whether presentation,
formatting, and explanation are accurately separated from state ownership,
installation logic, and system decisions — and whether every named
collaboration (`Deployment.Menu`, `Deployment.Selection`,
`Deployment.Planner`, `Deployment.Confirm`, `Deployment.Installer`,
`Deployment.Transaction`, Storage `Platform`) is independently supported.

## Scope

**Authoritative source:** `Deployment.Renderer`'s Module Contract,
[MODULE_STANDARD.md §13](../../architecture/MODULE_STANDARD.md), verbatim,
as it reads today — 23 atomic claims (4 Responsibilities, 5 Consumes, 2
Produces, 9 Collaborates With, 3 Constraints).

**Evidence source:** `core/deployment/render.sh` in full (471 lines, 14
functions); every external reference to each of its 8 externally-called
functions and to `CATALOG_MENU_HW_IDS`, across the entire repository,
including `core/bootstrap/wizard.sh` and `core/deployment.sh`.

**Not checked:** `Architecture.md`, `Deployment-Architecture.md`, ADRs, or
prior Verification Reports, as architectural sources. Whether the
underlying architecture is good design is out of scope.

## Method

Extracted all 23 claims verbatim. For each, ran `grep -rn` for the
specific function, variable, or field named, across `core/`, and read the
surrounding context of every hit rather than assuming a match confirms the
claim. Specifically checked, rather than assumed: whether `render.sh`
ever reimplements a compatibility/installed/membership check instead of
calling the module that owns it; whether any `render_*` function's return
value is captured via command substitution anywhere in the repository
(bearing on the `Produces` claim that rendered output is "not consumed by
any other module as data"); and whether `Deployment.Menu`'s already-adopted
Contract records the same `CATALOG_MENU_HW_IDS` fact this Contract records
on `Deployment.Renderer`'s side, per this task's Contract Consistency
Observation instructions.

## Evidence

```
render.sh:103-111  render_application_detail's status block — if/elif/elif/else
                    on app_incompatibility_reason, app_already_installed,
                    CATALOG_MENU_HW_IDS membership, in that order
render.sh: grep for "catalog/" and "SELECTED_APPS" → one hit, a comment
                    (line 176), zero executable references
render.sh: grep for "ARCHS", "MIN_MACOS", "/Applications" → one hit, a
                    comment (line 92) explaining why ARCHS isn't shown
                    separately; no executable compatibility/installed check
                    reimplemented anywhere in the file
transaction.sh: txn_begin(), txn_finish(), txn_export() — no accessor
                    function for reading any TXN_* field exists
render.sh: 13 distinct TXN_* fields read directly across render_transaction
                    (lines 403-470)
render.sh:107        CATALOG_MENU_HW_IDS read directly; menu.sh:43,198 —
                    Menu owns and populates it; no accessor exists on
                    either side
render.sh: grep for '^\s*[A-Z_][A-Z0-9_]*=' → zero hits (no global write
                    anywhere in the file)
render.sh: grep for "platform" (case-insensitive) → zero hits
menu.sh:287          render_application_detail called directly
wizard.sh:39,42      render_category called directly (render_preset nested
                    as its second argument at line 39)
confirm.sh:18,28,32  render_confirmation, render_plan, render_plan_tree
                    called directly
install.sh:273       render_transaction called directly
deployment.sh:43,86,93,100  render_preset, render_plan_summary, render_plan,
                    render_plan_tree all called directly, in CLI-dispatch
                    code
render.sh:183,185,189,190  detect_machine_family, has_external_display,
                    selection_contains, apps_recommended_for_hardware —
                    all inside _plan_recommended_unselected
grep -rn '\$(render_' core/  → two hits: deployment.sh:43 and wizard.sh:39,
                    both `$(render_preset "$id")`, both immediately
                    embedded into another printf/render_category call for
                    display — not inspected, parsed, or branched on by
                    either caller
```

**`Deployment.Menu`'s adopted Contract, §7, checked for the same fact:**
```
Produces:  "Updates to the Selected Applications set..."; "The rendered
           Application Catalog screen." — no claim naming CATALOG_MENU_HW_IDS
Collaborates With → Deployment.Renderer: "calls render_application_detail
           directly to show the Application View for a chosen item." —
           states only the inbound call; does not state that Renderer
           reads Menu's own hardware-recommendation cache back
```

## Observations

| # | Observation | Evidence |
|---|---|---|
| 1 | `render_preset`'s return value is captured via `$(...)` command substitution at two real call sites (`deployment.sh:43`, `wizard.sh:39`), which is architecturally "consumption" in the mechanical sense the `Produces` claim's wording denies ("not consumed by any other module as data"). In both cases, though, the captured string is immediately re-embedded into another display line, never inspected, parsed, or branched on — neither caller's own correctness depends on the string's content, only on it being printable text. The claim's wording and its evidence disagree on the literal reading; they agree on the reading that matters for the model's own `Produces` test (§5: does another module rely on the fact for its own correctness). |  `deployment.sh:43`; `wizard.sh:39` |
| 2 | Every other Consumes/Collaborates With claim describing a raw, accessor-free read (`PLAN_*`, `TXN_*`, `CATALOG_MENU_HW_IDS`) was independently confirmed to have no corresponding accessor function anywhere in the module that owns the data — these are not claims of "an accessor exists but isn't used," they are claims of "no accessor exists at all," and both were checked, not assumed, for `Deployment.Planner` and `Deployment.Transaction` alike. | `transaction.sh` function list; prior confirmation for `planner.sh` |

## Result

| Claim checked | Result |
|---|---|
| Responsibility 1 — Application Detail view, status precedence, metadata, related | VERIFIED |
| Responsibility 2 — Plan in three forms (explain, summary, tree) | VERIFIED |
| Responsibility 3 — confirmation summary and transaction result | VERIFIED |
| Responsibility 4 — category/preset one-liners for Bootstrap wizard and CLI | VERIFIED |
| Consumes 1 — Catalog data via accessors only | VERIFIED |
| Consumes 2 — Selection determinations via accessors only | VERIFIED |
| Consumes 3 — raw Plan/Transaction state, no accessor | VERIFIED |
| Consumes 4 — Menu's hardware-recommendation cache, raw | VERIFIED |
| Consumes 5 — real machine family and external-display status | VERIFIED |
| Produces 1 — rendered output, not consumed by any other module as data | **AMBIGUOUS** — technically captured via `$(...)` at two real call sites, but never inspected or relied upon for the capturing module's own correctness (Observation 1) |
| Produces 2 — derived view-only comparisons, recomputed, never stored | VERIFIED |
| Collaborates With — `Deployment.Catalog` | VERIFIED |
| Collaborates With — `Deployment.Selection` | VERIFIED |
| Collaborates With — `Deployment.Menu` | VERIFIED |
| Collaborates With — `Deployment.Planner` | VERIFIED |
| Collaborates With — `Deployment.Confirm` | VERIFIED |
| Collaborates With — `Deployment.Installer` | VERIFIED |
| Collaborates With — `Deployment.Transaction` | VERIFIED |
| Collaborates With — `Deployment` | VERIFIED |
| Collaborates With — `Bootstrap` | VERIFIED |
| Constraint 1 — never mutates shared state | VERIFIED |
| Constraint 2 — never independently determines compatibility/installed/membership | VERIFIED |
| Constraint 3 — never persists a derived comparison | VERIFIED |

**22 / 23 claims verified. 0 contradictions. 1 ambiguous claim. 0 claims
with missing evidence.**

## Confidence

**High** on every row, including the ambiguous one — Observation 1's
disagreement is precisely characterized (two named call sites, both read
in full), not a gap in available evidence.

## Contract Consistency Observations

*(Informational only, per this task's instructions — these do not affect
`Deployment.Renderer`'s Result above, and no adopted Contract was
modified.)*

**`Deployment.Menu`'s adopted Contract (§7) does not record the
`CATALOG_MENU_HW_IDS` fact from its own side.** `Deployment.Renderer`'s
Contract records, on its own side, that `render_application_detail` reads
`CATALOG_MENU_HW_IDS` — a variable `Deployment.Menu` owns and populates —
directly, with no accessor. Checking `Deployment.Menu`'s adopted Contract
for the matching fact: its `Produces` field names only two claims (neither
referencing `CATALOG_MENU_HW_IDS`), and its `Collaborates With` →
`Deployment.Renderer` entry states only the inbound call
(`render_application_detail` being called), not the outbound raw read.
This is the same asymmetry `Deployment.Renderer`'s own drafting notes
already flagged; this verification independently confirms it holds against
`Deployment.Menu`'s Contract text as currently adopted. Per this task's
instructions, this is recorded here only — `Deployment.Menu`'s Contract was
not modified, and this does not count against `Deployment.Renderer`'s
Result above.

## Recommendations

None. Per this task's explicit restriction, no fix or rewrite is proposed
for the ambiguous claim or for the Contract Consistency Observation.

## Is `Deployment.Renderer` ready for adoption?

**Not stated as ready for adoption.** 22 of 23 claims verify cleanly, and
zero claims were contradicted — but one claim (`Produces` 1) did not
resolve to a clean VERIFIED, so per this task's success criteria the
explicit "ready for adoption" statement is withheld rather than rounded up
from 22/23.

## Does this reveal a Contract issue, an implementation issue, a Module Contract model issue, or only Contract Consistency observations?

**A Contract issue, plus a separate Contract Consistency Observation —
not an implementation issue, not a model issue.** The ambiguity in
`Produces` 1 is a wording-precision matter: the implementation behaves
exactly as a reasonable architecture would want (nothing depends on
rendered text for correctness), but the claim's literal phrasing
("not consumed... as data") doesn't account for the mechanical fact that
`$(...)` capture is, technically, consumption. Nothing about
`core/deployment/render.sh` or its callers is defective. Separately, the
Contract Consistency Observation above is exactly that — an observation
about `Deployment.Menu`'s adopted Contract's own coverage, not a defect in
`Deployment.Renderer`'s Contract or in the seven-field model, which is
precisely what let this asymmetry be named and cross-checked in the first
place.

## History

| Date | Result | Note |
|---|---|---|
| 2026-08-06 | 22/23 VERIFIED, 1 AMBIGUOUS | Initial Boundary Verification of `Deployment.Renderer`'s Module Contract |
