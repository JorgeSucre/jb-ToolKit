# Verification 0003 (Module Contract Validation, Corrected Contract): Boundary Verification executed against `Deployment.Renderer`'s corrected Module Contract

**Program entry:** [VERIFICATION_PROGRAM.md #0003](../VERIFICATION_PROGRAM.md#0003--boundary-verification)
**Verification Level(s):** Boundary (broadened to also check Consumes/
Produces/Collaborates With, per the pattern established across this
series)
**Date:** 2026-08-06
**Role performing this verification:** Verification Engineer (see
[ENGINEERING_ROLES.md](../ENGINEERING_ROLES.md))

**Relationship to the prior report.** `0003-boundary-verification-deployment-renderer.md`
checked the original Contract and found 22 verified, 0 contradicted, 1
ambiguous (`Produces` 1), plus one Contract Consistency Observation about
`Deployment.Menu`'s adopted Contract. Between that report and this one, the
Engineering Architect corrected only `Produces` 1, tracing the change to
the ambiguity finding. This report treats the corrected Contract as
unverified from scratch — all 23 claims are re-checked against fresh
evidence, not carried over from the prior result.

## Purpose

Determine whether every atomic claim in `Deployment.Renderer`'s corrected
Module Contract holds true against `core/deployment/render.sh` and its
real collaborators, confirming specifically that technical capture (via
command substitution) does not by itself constitute architectural
dependency, and that the corrected `Produces` 1 wording matches
`MODULE_STANDARD.md` §5's own definition of the field.

## Scope

**Authoritative source:** `Deployment.Renderer`'s Module Contract,
[MODULE_STANDARD.md §13](../../architecture/MODULE_STANDARD.md), as it
reads after the Architect's correction — 23 atomic claims, same count as
before; only `Produces` 1's wording changed.

**Evidence source:** `core/deployment/render.sh` and every external
reference to its 8 externally-called functions and to
`CATALOG_MENU_HW_IDS`, re-gathered fresh; both real `$(render_preset ...)`
capture sites (`deployment.sh:43`, `wizard.sh:39`) read in full, not just
at the capturing line.

**Not checked:** `Architecture.md`, `Deployment-Architecture.md`, ADRs, or
prior Verification Reports, as architectural sources. Confirmed first that
no implementation file changed since the prior report.

## Method

Identical to the original verification. For `Produces` 1 specifically: read
both capture sites (`deployment.sh:43` and `wizard.sh:39`) in their full
surrounding context — not just the line containing `$(render_preset ...)`
— to determine what each caller actually does with the captured string,
rather than re-asserting the prior report's characterization of them.

## Evidence

```
git status --porcelain -- core/deployment/render.sh core/deployment/menu.sh
  core/deployment/confirm.sh core/deployment/install.sh core/deployment/planner.sh
  core/deployment/selection.sh core/deployment/catalog.sh core/deployment/transaction.sh
  core/deployment.sh core/bootstrap/wizard.sh core/bootstrap/hardware.sh
  → clean; no implementation file changed since the prior report

deployment.sh:40-43   for id in $(list_presets_ordered); do
                           printf "   • %-14s %s\n" "$id" "$(render_preset "$id")"
                       done
                       — render_preset's output is one %s argument to printf;
                         no conditional, no parsing, no branch on its content

wizard.sh:35-42       print_section "🚀 ¿Cómo se usará este Mac?"
                       for ((index=0; index<count; index++)); do
                           render_category "$((index + 1))" "$(render_preset "${preset_ids[$index]}")" 0
                       done
                       render_category "$((count + 1))" "Empezar vacío" 0
                       — render_preset's output is passed as an argument
                         into render_category (another Deployment.Renderer
                         function), itself just printf "%s) %s\n" "$1" "$2"
                         — the captured text flows into more presentation,
                         never into a decision

render.sh:103-111     status precedence block, unchanged, re-confirmed
                       identical to the original verification pass
render.sh: grep for '^\s*[A-Z_][A-Z0-9_]*=' → zero hits (still no global
                       write anywhere in the file)
render.sh: grep for "platform" (case-insensitive) → zero hits
menu.sh:287; wizard.sh:39,42; confirm.sh:18,28,32; install.sh:273;
  deployment.sh:43,86,93,100; render.sh:183,185  — all 8 external call
  sites and both hardware-detection calls re-confirmed present, unchanged
```

## Observations

None beyond what the prior report already recorded. The correction and the
re-gathered evidence agree exactly: neither capture site inspects,
parses, or branches on `render_preset`'s output — one embeds it directly
in a `printf` format string, the other passes it straight into a second
presentation function.

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
| Produces 1 — rendered output no other module relies on for correctness | VERIFIED |
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

**23 / 23 claims verified. Zero contradictions. Zero ambiguous claims. Zero
claims with missing evidence.**

**Deployment.Renderer Module Contract is ready for adoption.**

Confirmed specifically, per this task's special attention: technical
capture via command substitution, evidenced at both real call sites, does
not rise to architectural dependency in either case — neither caller
inspects or branches on the captured text, both treat it as opaque
display content. The corrected wording states exactly this test, matching
`MODULE_STANDARD.md` §5's own definition of `Produces` ("whether another
module actually relies on the fact for its own correctness"). As with
every prior report in this series, this verdict is scoped to the
Contract's 23 claims being true and independently checkable — it is not a
judgment on whether the underlying architecture is good design.

## Confidence

**High** on all 23 claims, including the corrected one — resolved by
reading both capture sites in full, not by inference.

## Contract Consistency Observations

Unchanged from the prior report, and not re-litigated here since it
concerns a different, adopted Contract this task does not authorize
modifying: `Deployment.Menu`'s adopted Contract (§7) still does not record,
from its own side, that `Deployment.Renderer` reads `CATALOG_MENU_HW_IDS`
directly. This remains informational only and does not affect
`Deployment.Renderer`'s Result above.

## Recommendations

None.

## Does this reveal a Contract issue, an implementation issue, a Module Contract model issue, or only Contract Consistency observations?

**Neither — this pass confirms the prior finding was a Contract issue, and
that it is now resolved.** No implementation file changed between the two
verification passes; only `Produces` 1's wording changed, and that change
alone was sufficient to bring the claim in line with code that was never
itself in question. The standing Contract Consistency Observation about
`Deployment.Menu` remains open but unaffected — it was never scored
against `Deployment.Renderer` and isn't resolved or worsened by this
correction.

## History

| Date | Result | Note |
|---|---|---|
| 2026-08-06 | 22/23 VERIFIED, 1 AMBIGUOUS | Initial Boundary Verification |
| 2026-08-06 | 23/23 VERIFIED | Re-verification against the corrected Contract |
