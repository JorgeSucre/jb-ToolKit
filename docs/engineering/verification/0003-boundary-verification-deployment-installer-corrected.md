# Verification 0003 (Module Contract Validation, Corrected Contract): Boundary Verification executed against `Deployment.Installer`'s corrected Module Contract

**Program entry:** [VERIFICATION_PROGRAM.md #0003](../VERIFICATION_PROGRAM.md#0003--boundary-verification)
**Verification Level(s):** Boundary (broadened to also check Consumes/
Produces/Collaborates With, per the pattern established across this
series)
**Date:** 2026-08-06
**Role performing this verification:** Verification Engineer (see
[ENGINEERING_ROLES.md](../ENGINEERING_ROLES.md))

**Relationship to the prior report.** `0003-boundary-verification-deployment-installer.md`
checked the original Contract and found 18/18 existing claims verified,
plus one real collaboration (`export_deployment_plan()`) with no
corresponding claim. Between that report and this one, the Engineering
Architect corrected the `Collaborates With → Deployment.Planner` entry to
record both interactions. This report treats the corrected Contract as
unverified from scratch — every claim, including the 17 untouched ones, is
re-checked against fresh evidence, and the collaborator-completeness check
that found the original gap is re-run in full rather than assumed to have
already found everything there was to find.

## Purpose

Determine whether every atomic claim in `Deployment.Installer`'s corrected
Module Contract holds true against `core/deployment/install.sh` and its
real collaborators, confirming specifically that the corrected
`Deployment.Planner` entry now records both the passive `PLAN_*` dependency
and the active `export_deployment_plan()` call, completely, accurately, and
independently of the prior report's characterization of them.

## Scope

**Authoritative source:** `Deployment.Installer`'s Module Contract,
[MODULE_STANDARD.md §14](../../architecture/MODULE_STANDARD.md), as it
reads after the Architect's correction — 18 atomic claims, same count as
before; only the `Deployment.Planner` entry's wording changed.

**Evidence source:** `core/deployment/install.sh`, re-read in full; every
external function call in the file re-enumerated from scratch — not
limited to the functions the Contract's own text already names, to check
for any collaboration still missing a claim, the same way the original gap
was found.

**Not checked:** `Architecture.md`, `Deployment-Architecture.md`, ADRs, or
prior Verification Reports, as architectural sources. Confirmed first that
no implementation file changed since the prior report.

## Method

Identical to the original verification, with one addition: rather than
re-checking only the `Deployment.Planner` entry the Architect corrected,
every external function `install.sh` calls was re-enumerated from the raw
source, and each one mapped to its owning module or to shared
infrastructure, to test whether the corrected Contract's collaborator list
is now complete — not just whether the one corrected claim is accurate.

## Evidence

```
git status --porcelain -- core/deployment/install.sh [and every file the
  prior report checked] → clean; no implementation file changed

install.sh:153-155   if ! ask_yes_no "¿Preparar este equipo..."; then
                          plan_file="$(export_deployment_plan)"
                          txn_begin "$(basename "$plan_file")"
                          ...
install.sh:163-164   plan_file="$(export_deployment_plan)"
                      txn_begin "$(basename "$plan_file")"
                      — confirms: exactly one export_deployment_plan() call
                        per invocation, immediately before txn_begin, on
                        whichever of the two branches is taken

Every external function call in install.sh, re-enumerated:
  ask_yes_no (×3: lines 130, 153, 179), brew_available, brew_cache_reset,
  brew_cask_installed, brew_formula_installed, error_msg,
  export_deployment_plan, info, log, print_section (line 78),
  render_transaction, retry, run_cmd, success, txn_begin, txn_export,
  txn_finish, warn, write_state_values

install.sh:78    print_section "🔎 Comprobando el despliegue"
core/bootstrap/ui.sh:13   print_section() { ... }   — same file as
                  ask_yes_no (ui.sh:92); not named anywhere in the
                  Contract's Bootstrap entry

install.sh:130    if ask_yes_no "¿Abrir la página de descarga de $name?"; then
                  — inside _offer_manual_downloads, a third ask_yes_no call
                  site distinct from the two the Bootstrap entry describes
                  as "this module's own runtime gates"
```

## Observations

| # | Observation | Evidence |
|---|---|---|
| 1 | The corrected `Deployment.Planner` entry is fully accurate: `export_deployment_plan()` is called exactly once per invocation, at exactly one of the two described branch points, immediately before `txn_begin` on either path. Both the passive `PLAN_*` dependency and this active call are now stated, and both are independently evidenced. | `install.sh:153-155,163-164` |
| 2 | `install.sh:78` calls `print_section` — defined in `core/bootstrap/ui.sh`, the same file as `ask_yes_no` — and this call has no corresponding claim anywhere in the Contract's `Bootstrap` entry, which names only "its confirmation-prompt function." | `install.sh:78`; `core/bootstrap/ui.sh:13` |
| 3 | `ask_yes_no` itself is called three times, not two: `install.sh:153` and `:179` are the two runtime gates the `Bootstrap` entry describes; `install.sh:130`, inside `_offer_manual_downloads`, asks whether to open a manual application's download page — a real, separate use the entry's "for both of this module's own runtime gates" framing does not cover. | `install.sh:130` |
| 4 | This is not a re-confirmation of something the prior report already flagged — the prior report's evidence for the `Bootstrap` entry cited only the two gate call sites the claim's own text named, rather than independently enumerating every call into `core/bootstrap/ui.sh` the way this pass did (and the way the original `Deployment.Planner` gap was found). This is a genuine gap in the prior verification pass's own thoroughness, not a new implementation fact. |  |

## Result

| Claim checked | Result |
|---|---|
| Responsibility 1 — executes automatic-track packages via Homebrew, with retry | VERIFIED |
| Responsibility 2 — determines real starting state at execution time, independently re-verified | VERIFIED |
| Responsibility 3 — gates execution behind two runtime confirmations | VERIFIED |
| Responsibility 4 — classifies final outcome from confirmed-failure count | VERIFIED |
| Consumes 1 — raw Plan state, no accessor | VERIFIED |
| Consumes 2 — real-time Homebrew index, at multiple points | VERIFIED |
| Consumes 3 — real filesystem state of `/Applications` | VERIFIED |
| Produces 1 — most of Transaction's outcome content, written directly, no mutator | VERIFIED |
| Produces 2 — sole owner of Plan-derived Homebrew installation | VERIFIED |
| Produces 3 — five keys written into shared session state store | VERIFIED |
| Collaborates With — `Deployment.Planner` (corrected) | VERIFIED — both interactions confirmed complete, accurate, and independently evidenced (Observation 1) |
| Collaborates With — `Deployment.Transaction` | VERIFIED |
| Collaborates With — `Deployment.Renderer` | VERIFIED |
| Collaborates With — `Deployment.Confirm` | VERIFIED |
| Collaborates With — `Bootstrap` | **INCOMPLETE** — accurate as far as it states, but silent on a second real function (`print_section`) and a third real call site of the function it does name (Observations 2–3); not a contradiction of what is written, but a missing-collaboration finding of the same kind the prior report found for `Deployment.Planner` |
| Constraint 1 — never reads the catalog | VERIFIED |
| Constraint 2 — never decides plan membership or reclassifies track | VERIFIED |
| Constraint 3 — never proceeds past a gate silently | VERIFIED |

**17 / 18 claims fully verified. The corrected `Deployment.Planner` entry
resolves completely. 0 contradictions. 0 ambiguous claims. 0 claims with
missing evidence. 1 remaining missing-collaboration finding, newly
identified in this pass, on a claim the correction did not touch.**

## Confidence

**High** on every row, including the new finding — resolved by exhaustive
enumeration of every external call in the file, not by inference, the same
standard applied to the claim that was corrected.

## Contract Consistency Observations

None found. `Deployment.Installer` has no evidenced interaction with
`Deployment.Menu` — the only currently-adopted Contract.

## Recommendations

None. Per this task's explicit restriction, no fix is proposed for the
`Bootstrap` finding.

## Is `Deployment.Installer` ready for adoption?

**Not stated as ready for adoption.** The correction under review succeeded
completely — the `Deployment.Planner` entry now accurately and completely
describes both real interactions, exactly as required. But re-running the
same collaborator-completeness check against every claim, not only the
corrected one, found that the `Bootstrap` entry has the same shape of gap
the `Deployment.Planner` entry had before this correction. Per the standard
already applied to this module once, a real, evidenced missing
collaboration is treated as blocking adoption until corrected.

## Does this reveal a Contract issue, an implementation issue, a Module Contract model issue, or only Contract Consistency observations?

**A Contract issue — a second incomplete `Collaborates With` entry — and
nothing else.** `install.sh:78` and `:130` behave exactly as sound
architecture would want: a status header before pre-flight output, and an
optional courtesy prompt before opening a URL. Nothing about the
implementation is defective. The gap is that the `Bootstrap` entry
describes one function and two of its three real call sites, not all of
what the module actually calls into `core/bootstrap/ui.sh`.

## History

| Date | Result | Note |
|---|---|---|
| 2026-08-06 | 18/18 claims VERIFIED, 1 uncovered collaboration found (`Deployment.Planner`) | Initial Boundary Verification |
| 2026-08-06 | 17/18 claims VERIFIED, `Deployment.Planner` correction confirmed complete, 1 new uncovered collaboration found (`Bootstrap`) | Re-verification against the corrected Contract |
