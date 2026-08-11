# Verification 0003 (Module Contract Validation, Final Re-verification): Boundary Verification executed against `Deployment.Installer`'s twice-corrected Module Contract

**Program entry:** [VERIFICATION_PROGRAM.md #0003](../VERIFICATION_PROGRAM.md#0003--boundary-verification)
**Verification Level(s):** Boundary (broadened to also check Consumes/
Produces/Collaborates With, per the pattern established across this
series)
**Date:** 2026-08-06
**Role performing this verification:** Verification Engineer (see
[ENGINEERING_ROLES.md](../ENGINEERING_ROLES.md))

**Relationship to prior reports.** `0003-boundary-verification-deployment-installer.md`
found the original `Deployment.Planner` collaboration incomplete.
`0003-boundary-verification-deployment-installer-corrected.md` confirmed
that fix and found the `Bootstrap` collaboration incomplete in turn (two
of three `ask_yes_no` sites and one `print_section` site were unrecorded).
The Architect corrected the `Bootstrap` entry to name all of those. This
report re-executes the complete verification from scratch, per explicit
instruction not to verify only the corrected claim and not to assume
completeness — and, on that fuller re-enumeration, finds the `Bootstrap`
entry still incomplete, in a way neither prior pass caught, plus one
further, smaller gap in the `Deployment.Transaction` entry.

## Purpose

Determine whether every atomic claim in `Deployment.Installer`'s Module
Contract, as it exists after two correction cycles, holds true against
`core/deployment/install.sh`, with the `Bootstrap` collaboration
specifically re-derived from an independent, from-scratch enumeration of
every external call in the file rather than a check against the claim's
own current wording.

## Scope

**Authoritative source:** `Deployment.Installer`'s Module Contract,
[MODULE_STANDARD.md §14](../../architecture/MODULE_STANDARD.md), as it
reads today — 18 atomic claims.

**Evidence source:** `core/deployment/install.sh`, re-read in full;
every identifier the file calls, individually traced to its defining file
via `grep -rn "^<name>()"` across `core/` — not limited to names already
appearing in the Contract's text — to build the collaborator list
independently rather than confirm the existing one.

**Not checked:** `Architecture.md`, `Deployment-Architecture.md`, ADRs, or
prior Verification Reports, as architectural sources.

## Method

Every external identifier referenced in `install.sh` was extracted and
individually traced to its defining file: `brew_formula_installed`,
`brew_cask_installed`, `brew_available`, `brew_cache_reset`, `retry`,
`run_cmd`, `log`, `write_state_values` (→ `core/utils.sh`); `print_section`,
`ask_yes_no`, `success`, `warn`, `error_msg`, `info` (→
`core/bootstrap/ui.sh`); `export_deployment_plan` (→
`core/deployment/planner.sh`); `txn_begin`, `txn_finish`, `txn_export` (→
`core/deployment/transaction.sh`); `render_transaction` (→
`core/deployment/render.sh`). Each was checked against every
`Collaborates With` entry, not only the one under correction. Every
`PLAN_*` and `TXN_*` variable read (not just written) was separately
enumerated and checked against `Consumes`.

## Evidence

```
git status --porcelain -- core/deployment/install.sh [and all files
  checked in prior passes] → clean; no implementation file changed

Functions defined in core/bootstrap/ui.sh, confirmed by definition:
  core/bootstrap/ui.sh:13  print_section()
  core/bootstrap/ui.sh:24  success()
  core/bootstrap/ui.sh:29  warn()
  core/bootstrap/ui.sh:34  error_msg()
  core/bootstrap/ui.sh:43  info()
  core/bootstrap/ui.sh:92  ask_yes_no()
  — all six in one file; none also defined in core/utils.sh (checked to
    rule out a shadowed/duplicate definition)

Call sites in install.sh, by function:
  print_section  → line 78                          (1 site)
  ask_yes_no     → lines 130, 153, 179               (3 sites)
  info           → lines 79, 102, 133, 159, 183, 199 (6 sites)
  success        → line 86                           (1 site)
  error_msg      → lines 89, 148                      (2 sites)
  warn           → lines 97, 131, 227                 (3 sites)

Current Bootstrap entry names only print_section and ask_yes_no — 2 of the
6 functions, 4 of the 16 total call sites, this file supports.

install.sh:268   "LAST_DEPLOYMENT=$TXN_END" — reads $TXN_END, set by
  transaction.sh's txn_finish() (transaction.sh:85), after install.sh's
  own txn_finish("$result") call at line 263 — a real read of a
  Deployment.Transaction-owned field, not a write

Deployment.Menu (adopted, §7) cross-check:
  menu.sh:260,292  warn "..."
  menu.sh:334,339  info "..."
  — both defined in core/bootstrap/ui.sh, the same file Deployment.Menu's
    adopted Contract already cites for print_section; neither warn nor
    info appears in that Contract's Bootstrap entry
```

## Observations

| # | Observation | Evidence |
|---|---|---|
| 1 | The `Deployment.Planner` collaboration, corrected in the prior cycle, is confirmed complete and accurate on this from-scratch pass — both the raw-state read and the `export_deployment_plan()` call are real, evidenced, and exhaustively accounted for; no third interaction with `Deployment.Planner` was found. |  |
| 2 | The `Bootstrap` collaboration, corrected in the prior cycle to add `print_section` and the third `ask_yes_no` site, is still incomplete: `success`, `warn`, `error_msg`, and `info` are four more functions defined in the identical file (`core/bootstrap/ui.sh`) already cited for `print_section`/`ask_yes_no`, called at 12 further sites, none named. The prior correction's own re-enumeration was not exhaustive — it traced the specific functions already suspected of undercounting, not every identifier in the file back to its source file. | call-site table above |
| 3 | `install.sh` reads `$TXN_END`, a field `Deployment.Transaction` sets, once — to build one of the five `write_state_values` keys. Neither `Consumes` nor the `Deployment.Transaction` `Collaborates With` entry (which describes only lifecycle calls and outbound writes) records this inbound read. | `install.sh:268`; `transaction.sh:85` |
| 4 | The same shape of gap found in Observation 2 exists in `Deployment.Menu`'s already-adopted Contract: `menu.sh` calls `warn` and `info` directly, both from `core/bootstrap/ui.sh`, and neither appears in that Contract's `Bootstrap` entry, which currently names only `detect_machine_family` and `print_section`. Recorded as a Contract Consistency Observation, per this task's instructions — not scored against `Deployment.Installer`, and `Deployment.Menu`'s Contract was not modified. |  `menu.sh:260,292,334,339` |

## Result

| Claim checked | Result |
|---|---|
| Responsibility 1 — executes automatic-track packages via Homebrew, with retry | VERIFIED |
| Responsibility 2 — determines real starting state at execution time, independently re-verified | VERIFIED |
| Responsibility 3 — gates execution behind two runtime confirmations | VERIFIED |
| Responsibility 4 — classifies final outcome from confirmed-failure count | VERIFIED |
| Consumes 1 — raw Installation Plan state, no accessor | VERIFIED (see Observation 3 — a separate, real Transaction-side read exists uncovered by any Consumes claim) |
| Consumes 2 — real-time Homebrew index, at multiple points | VERIFIED |
| Consumes 3 — real filesystem state of `/Applications` | VERIFIED |
| Produces 1 — most of Transaction's outcome content, written directly, no mutator | VERIFIED |
| Produces 2 — sole owner of Plan-derived Homebrew installation | VERIFIED |
| Produces 3 — five keys written into shared session state store | VERIFIED |
| Collaborates With — `Deployment.Planner` | VERIFIED — confirmed complete (Observation 1) |
| Collaborates With — `Deployment.Transaction` | **INCOMPLETE** — accurate as written, silent on the `$TXN_END` read (Observation 3) |
| Collaborates With — `Deployment.Renderer` | VERIFIED |
| Collaborates With — `Deployment.Confirm` | VERIFIED |
| Collaborates With — `Bootstrap` | **INCOMPLETE** — accurate as written, covers 2 of 6 real functions from the same file (Observation 2) |
| Constraint 1 — never reads the catalog | VERIFIED |
| Constraint 2 — never decides plan membership or reclassifies track | VERIFIED |
| Constraint 3 — never proceeds past a gate silently | VERIFIED |

**16 / 18 claims fully verified. The `Deployment.Planner` correction holds
completely. 0 contradictions. 0 ambiguous claims. 0 claims with missing
evidence. 2 incomplete `Collaborates With`/`Consumes` findings remain — one
new in this pass (`Bootstrap`, again), one not previously identified at
all (`Deployment.Transaction`'s `$TXN_END` read).**

## Confidence

**High** on every row. The `Bootstrap` and `Deployment.Transaction`
findings are both resolved to specific line numbers and independently
confirmed definitions, not inference — the same standard applied
throughout this series.

## Contract Consistency Observations

**`Deployment.Menu`'s adopted Contract (§7) has the same shape of gap
found in Observation 2.** `menu.sh` calls `warn` and `info` directly, both
defined in `core/bootstrap/ui.sh` — the file that Contract's `Bootstrap`
entry already partially cites for `print_section`. Neither `warn` nor
`info` is named in that entry. This is recorded here only, per this task's
instructions: `Deployment.Menu`'s Contract was not modified, and this does
not affect `Deployment.Installer`'s Result above.

## Recommendations

None. Per this task's explicit restriction, no fix is proposed for either
remaining finding or for the Contract Consistency Observation.

## Is `Deployment.Installer` ready for adoption?

**Not stated as ready for adoption.** Two real, evidenced incompleteness
findings remain: the `Bootstrap` entry, corrected once already, is still
short four functions from the same file; and the `Deployment.Transaction`
entry does not record a real inbound read. Per the standard already
applied twice to this module, both are treated as blocking adoption until
corrected.

## Does this reveal a Contract issue, an implementation issue, a Module Contract model issue, or only Contract Consistency observations?

**A Contract issue, twice over, plus a separate Contract Consistency
Observation — not an implementation issue, not a model issue.**
`install.sh` behaves exactly as sound architecture would want at every
site named in this report — status messages, a state-store read, nothing
defective. Both remaining gaps are incompleteness in what the Contract
records, not in what the code does. Worth naming plainly: this is the
third pass to find an incomplete `Collaborates With` entry for this one
module, each time via a more exhaustive enumeration than the last — a
fact about how hard demonstrating completeness is by construction (proving
an absence requires checking everything, where finding one more instance
only requires checking one thing), not evidence that any single
correction was performed carelessly.

## History

| Date | Result | Note |
|---|---|---|
| 2026-08-06 | 18/18 claims VERIFIED, 1 uncovered collaboration found (`Deployment.Planner`) | Initial Boundary Verification |
| 2026-08-06 | 17/18 claims VERIFIED, `Deployment.Planner` correction confirmed complete, 1 new uncovered collaboration found (`Bootstrap`) | Re-verification after first correction |
| 2026-08-06 | 16/18 claims VERIFIED, `Bootstrap` correction found still incomplete, 1 further gap found (`Deployment.Transaction`) | Final re-verification after second correction |
