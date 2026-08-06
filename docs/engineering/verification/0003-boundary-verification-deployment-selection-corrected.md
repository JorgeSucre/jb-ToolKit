# Verification 0003 (Module Contract Validation, Corrected Contract): Boundary Verification executed against `Deployment.Selection`'s corrected Module Contract

**Program entry:** [VERIFICATION_PROGRAM.md #0003](../VERIFICATION_PROGRAM.md#0003--boundary-verification)
**Verification Level(s):** Boundary (broadened to also check Consumes/
Produces/Collaborates With, per the pattern established for
`Deployment.Menu` and `Deployment.Planner`)
**Date:** 2026-08-06
**Role performing this verification:** Verification Engineer (see
[ENGINEERING_ROLES.md](../ENGINEERING_ROLES.md))

**Relationship to the prior report.** `0003-boundary-verification-deployment-selection.md`
checked the original Contract and found 16 verified, 2 contradicted
(Responsibility 3, Constraint 2), and 1 ambiguous (Collaborates With →
`Deployment.Menu`). Between that report and this one, the Engineering
Architect corrected exactly those three claims, tracing each change to the
finding it resolves. This report treats the corrected Contract as
unverified from scratch — no claim, including the 16 that previously
passed, is accepted on the strength of the prior result.

## Purpose

Determine whether every atomic claim in `Deployment.Selection`'s corrected
Module Contract holds true against `core/deployment/selection.sh` and its
real callers, re-executing the same method as the original verification
without assuming any claim — corrected or not — is now correct.

## Scope

**Authoritative source:** `Deployment.Selection`'s Module Contract,
[MODULE_STANDARD.md §10](../../architecture/MODULE_STANDARD.md), as it
reads after the Architect's correction — 19 atomic claims (4
Responsibilities, 4 Consumes, 4 Produces, 4 Collaborates With, 3
Constraints; same count as before — the correction rewrote three claims,
it did not add or remove any).

**Evidence source:** `core/deployment/selection.sh`, plus every external
reference to its functions and globals across `core/`, re-gathered fresh
in this pass rather than carried over from the prior report.

**Not checked:** `Architecture.md`, `Deployment-Architecture.md`, ADRs, or
prior Verification Reports, as architectural sources. Confirmed first,
before re-checking claims, that no implementation file was touched between
reports (`git status --porcelain` against every file this Contract
concerns returns clean) — establishing that any claim's truth value could
only have changed because of the Contract edit, not a code change.

## Method

Identical to the original verification: every claim extracted verbatim,
checked against a specific line or a specific function's full body, with
special attention to the three corrected claims and an explicit refusal to
assume the correction succeeded. For the three corrected claims
specifically, the exact evidence that produced the original finding was
re-run rather than reused, to confirm the correction actually addresses
what the code does today rather than merely rephrasing the prior text.

## Evidence

**Responsibility 3, re-checked:**
```
menu.sh:139        app_already_installed "$id" && installed_slot="✔ "
render.sh:105,165  app_already_installed "$id"  (two call sites)
install.sh          grep for app_already_installed → zero hits; the file's
                     own installed-status logic (brew_formula_installed/
                     brew_cask_installed calls, /Applications fallback,
                     confirmed present independently) is not a call into
                     this module
```

**Collaborates With → `Deployment.Menu`, re-checked:**
```
menu.sh:207,338  selection_count
menu.sh:233      app_incompatibility_reason "$id"
menu.sh:306      selection_toggle "$id" manual   — the only toggle/add/
                 remove-family call in the file; grep for selection_add
                 and selection_remove in menu.sh: zero hits
menu.sh:328      load_preset_into_selection "$preset_id"
menu.sh:330      reset_selection
selection.sh:61-69  selection_toggle()'s full body — calls selection_remove
                 or selection_add internally, confirming toggle is the one
                 entry point through which add/remove occur
```

**Constraint 2, re-checked:**
```
planner.sh:90    case "$method" in   — the classification switch named in
                 the corrected claim; $method is INSTALL_METHOD, never
                 $provenance
render.sh:19-28  case "$provenance" in preset:*) ... *) printf "selección
                 manual\n" ;; esac   — confirms the branch exists exactly
                 as the corrected claim states
menu.sh, install.sh  grep for "provenance": zero hits in either file
                 (install.sh reads the field into an unused `_source`
                 variable instead, confirmed in the prior report)
```

## Observations

| # | Observation | Evidence |
|---|---|---|
| 1 | The corrected Constraint 2's parenthetical describes `Deployment.Renderer`'s default-case label as `"manual selection"`. The literal string the code prints is `"selección manual"` (Spanish) — the Contract's phrase is an English gloss, not a quoted literal, unlike the constraint's other backtick-quoted identifiers (`INSTALL_METHOD`). The underlying claim — that Renderer branches on the provenance value to choose between a preset-derived label and a fixed non-preset label — is true regardless of which language the label is quoted in. This is recorded as an observation, not a violation: the atomic claim being checked is the branching behavior, not the exact printed bytes, and no other part of the Contract treats display strings as claims in their own right. |  `render.sh:28` vs. `MODULE_STANDARD.md` §10 Constraint 2 |

## Result

| Claim checked | Result |
|---|---|
| Responsibility 1 — owns the set, no separate preset/manual representation | VERIFIED |
| Responsibility 2 — determines compatibility (ARCHS, MIN_MACOS) | VERIFIED |
| Responsibility 3 — installed-status ownership split (Menu/Renderer direct, Installer independent) | VERIFIED |
| Responsibility 4 — loads a preset, replaces wholesale, records incompatible instead of dropping | VERIFIED |
| Consumes 1 — Catalog application data via accessors only | VERIFIED |
| Consumes 2 — preset application list via Catalog's preset accessors | VERIFIED |
| Consumes 3 — real macOS version and architecture at compatibility-check time | VERIFIED |
| Consumes 4 — session-level Homebrew list cache at installed-check time | VERIFIED |
| Produces 1 — updates to the set via own add/remove/toggle functions | VERIFIED |
| Produces 2 — raw representations read directly by `Deployment.Planner` | VERIFIED |
| Produces 3 — compatibility determination (yes/no + reason) | VERIFIED |
| Produces 4 — installed-status determination | VERIFIED |
| Collaborates With — `Deployment.Menu` (toggle-only membership mutation) | VERIFIED |
| Collaborates With — `Deployment.Renderer` | VERIFIED |
| Collaborates With — `Deployment.Planner` | VERIFIED |
| Collaborates With — `Deployment` | VERIFIED |
| Constraint 1 — first-occurrence-wins on duplicate add | VERIFIED |
| Constraint 2 — provenance opaque to installation decisions; Renderer's display-only branch named | VERIFIED |
| Constraint 3 — does not classify into install tracks or determine install method | VERIFIED |

**19 / 19 claims verified. Zero contradictions. Zero ambiguous claims. Zero
claims with missing evidence.**

**Deployment.Selection Module Contract is ready for adoption.**

This verdict is scoped precisely, consistent with every prior report in
this series: it means all 19 atomic claims are true and independently
checkable against `core/deployment/selection.sh` and its real callers
alone. It does not evaluate whether the underlying architecture (two
independent installed-status implementations; a Plan built from a raw,
unaccessored read of this module's state) is good design — those
questions were addressed separately (the Planner/Selection architectural
investigation) and are not reopened here.

## Confidence

**High** on all 19 claims, including the corrected three. Observation 1 is
noted at Medium confidence in isolation — it concerns a display-string
gloss, not a behavior — but does not lower confidence in the Result it's
attached to, since the claim being verified is the branch's existence, not
the string's exact wording.

## Recommendations

None. Per this task's explicit restriction, no fix, rewrite, or
architectural judgment is offered — not even for Observation 1, which is
recorded as a fact for a future Documentation Engineer or Architect to
weigh, not as a defect this report is asking to be resolved.

## History

| Date | Result | Note |
|---|---|---|
| 2026-08-06 | 16/19 VERIFIED, 2 CONTRADICTED, 1 AMBIGUOUS | Initial Boundary Verification |
| 2026-08-06 | 19/19 VERIFIED | Re-verification against the corrected Contract |
