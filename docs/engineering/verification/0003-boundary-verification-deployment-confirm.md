# Verification 0003 (Module Contract Validation): Boundary Verification executed against `Deployment.Confirm`'s Module Contract

**Program entry:** [VERIFICATION_PROGRAM.md #0003](../VERIFICATION_PROGRAM.md#0003--boundary-verification)
**Verification Level(s):** Boundary (broadened to also check Consumes/
Produces/Collaborates With, per the pattern established for
`Deployment.Menu`, `Deployment.Planner`, and `Deployment.Selection`)
**Date:** 2026-08-06
**Role performing this verification:** Verification Engineer (see
[ENGINEERING_ROLES.md](../ENGINEERING_ROLES.md))

**Relationship to other reports.** This checks `Deployment.Confirm`'s
Module Contract ([MODULE_STANDARD.md §12](../../architecture/MODULE_STANDARD.md))
against `core/deployment/confirm.sh` and every real caller/callee it
touches. `Deployment-Architecture.md` and `Architecture.md` were not
consulted as architectural sources. Every claim was checked fresh in this
pass, including the negative ("does not...") claims the brief specifically
flagged as a significant share of this Contract.

## Purpose

Determine whether every atomic claim in `Deployment.Confirm`'s Module
Contract holds true against `core/deployment/confirm.sh` and its real
collaborators, with particular attention to whether the module is
accurately described as coordinating the confirmation workflow rather than
rendering, deciding, installing, or persisting state itself.

## Scope

**Authoritative source:** `Deployment.Confirm`'s Module Contract,
[MODULE_STANDARD.md §12](../../architecture/MODULE_STANDARD.md), verbatim,
as it reads today — 13 atomic claims (2 Responsibilities, 2 Consumes, 1
Produces, 5 Collaborates With, 3 Constraints).

**Evidence source:** `core/deployment/confirm.sh` in full (55 lines, one
function); every external reference to `run_plan_confirmation`; the full
bodies of `render_confirmation`, `render_plan`, `render_plan_tree`
(`render.sh`) and `run_plan_installation` (`install.sh`), read to confirm
where the actual install-commit gate lives.

**Not checked:** `Architecture.md`, `Deployment-Architecture.md`, ADRs, or
prior Verification Reports, as architectural sources. Whether the
underlying architecture (a stateless coordinator, an install-commit gate
that lives one layer down from where its name would suggest) is good
design is out of scope — only whether the Contract's claims are true.

## Method

Extracted all 13 claims verbatim, checked each against a specific line in
`confirm.sh` or a specific collaborator's function definition. For the
three Constraint claims specifically — each an absolute ("does not...",
"owns no...") statement — searched `confirm.sh` for every line that
produces output or mutates state, not just the lines already cited in the
Contract's own supporting prose, to avoid confirming a negative claim by
checking only the evidence the Architect happened to cite for it.

## Evidence

```
confirm.sh:14      [[ "$PLAN_READY" -eq 1 ]] || return 0   — raw read
confirm.sh:16-52   while true; do render_confirmation; ...; case "$choice"
                    in [Ee]) render_plan ;; [Gg]) render_plan_tree ;;
                    [Ii]) run_plan_installation ... ;; 0|[Bb]) return 0 ;;
                    esac; done
confirm.sh:39      if run_plan_installation && [[ "$TXN_RESULT" != "cancelled" ]]; then
                    return 0; fi   — raw read of TXN_RESULT
confirm.sh: full-file grep for `^\s*[A-Z_]*=` (a global variable
                    assignment) → zero hits; only `local choice` exists
confirm.sh:20-22   echo ""; echo "[E] Explicar plan   [G] Ver árbol   [I]
                    Instalar   [0] Volver"; printf "Selecciona una
                    opción: "   — direct terminal output, not a call into
                    render.sh or any other file
menu.sh:345        run_plan_confirmation   — called with no `||`, no
                    return-value capture, as the last statement of
                    start_deployment_flow(); grep for run_plan_confirmation
                    elsewhere in core/ → zero other hits
render.sh:194,262,355  render_plan(), render_plan_tree(), render_confirmation()
                    — all three defined, exactly the three named in the
                    Contract
install.sh:138     run_plan_installation()
install.sh:153     if ! ask_yes_no "¿Preparar este equipo con la plantilla
                    $PLAN_PRESET_NAME?"; then ... — the install-commit gate,
                    confirmed inside run_plan_installation, not confirm.sh
```

## Observations

| # | Observation | Evidence |
|---|---|---|
| 1 | `confirm.sh` prints its own options line and input prompt directly (`echo`/`printf`, lines 20-22) rather than through any `render.sh` function. This is the one piece of terminal output in the file not accounted for by a call into `Deployment.Renderer`. | `confirm.sh:20-22`; zero calls into `render.sh` on those lines |
| 2 | `Produces`' claim that "its only effect on the rest of the system is the sequence of calls it makes into other modules" is worded narrowly enough to survive Observation 1: read in context, "effect on the system" refers to inter-module effects (matching the sentence's own qualifier, "...the sequence of calls it makes into other modules"), not terminal I/O directed at the technician. `Constraint` 3's claim is not worded with that qualifier — it states an unqualified "does not render anything itself" — so the same evidence resolves differently against the two claims. |  |
| 3 | Every other negative claim in this Contract (`Constraint` 1: no install-commit gate here; `Constraint` 2: owns no state) was checked against the same exhaustive scan used for `Constraint` 3, and both held with no counter-evidence found — `ask_yes_no` appears nowhere in `confirm.sh`, and no global variable is assigned anywhere in the file. | `confirm.sh`, full-file grep for `ask_yes_no` and for variable assignment: both zero hits |

## Result

| Claim checked | Result |
|---|---|
| Responsibility 1 — runs the review loop, dispatches by technician choice | VERIFIED |
| Responsibility 2 — keeps loop open on blocked/cancelled install, ends on back or completed attempt | VERIFIED |
| Consumes 1 — plan readiness, read directly | VERIFIED |
| Consumes 2 — installation outcome, read directly | VERIFIED |
| Produces 1 — no durable artifact; only inter-module effect is its calls | VERIFIED (Observation 2) |
| Collaborates With — `Deployment.Menu` | VERIFIED |
| Collaborates With — `Deployment.Planner` | VERIFIED |
| Collaborates With — `Deployment.Renderer` | VERIFIED |
| Collaborates With — `Deployment.Installer` | VERIFIED |
| Collaborates With — `Deployment.Transaction` | VERIFIED |
| Constraint 1 — does not own the installation-commit decision | VERIFIED |
| Constraint 2 — owns no state of its own | VERIFIED |
| Constraint 3 — does not render anything itself | **CONTRADICTED** — `confirm.sh:20-22` prints its options menu and prompt directly, not through `Deployment.Renderer` (Observation 1) |

**12 / 13 claims verified. 1 contradiction. 0 ambiguous claims. 0 claims
with missing evidence.**

`Deployment.Confirm`'s broader characterization — coordinating the
confirmation workflow rather than rendering, deciding, installing, or
persisting state — holds as a description of the module's *substance*
(the Plan's data, the transaction outcome, and every screen presenting
either are all produced elsewhere). It does not hold as the literal,
absolute claim `Constraint` 3 makes about *all* output.

## Confidence

**High** on all 13 claims. The one contradiction is High confidence, not
borderline: `confirm.sh:20-22` is quoted evidence, not an inference, and
no call into `render.sh` occurs on those lines.

## Recommendations

None. Per this task's explicit restriction, no fix or rewrite is proposed
for the contradiction.

## Does this reveal a Contract issue, an implementation issue, or a Module Contract model issue?

**A Contract issue.** The implementation itself shows no defect: a
confirmation loop printing its own static menu line and input prompt,
immediately adjacent to the `read` that consumes it, is ordinary control
structure, not evidence of a boundary being crossed carelessly — nothing
about `confirm.sh:20-22` behaves incorrectly or unexpectedly. The Module
Contract model's own mechanics are exactly what caught this: an atomic,
absolute claim (`[checked by: Boundary]`) was checked against a specific
piece of code and found false, precisely the falsifiability the model is
built to provide (`MODULE_STANDARD.md` §4). The mismatch is localized to
`Constraint` 3's wording — "does not render anything itself" claims more
than `Produces`' more carefully qualified claim did for the identical
underlying fact (Observation 2) — which is a property of this one
Contract instance, not of the seven-field model or of the code it
describes.

## History

| Date | Result | Note |
|---|---|---|
| 2026-08-06 | 12/13 VERIFIED, 1 CONTRADICTED | Initial Boundary Verification of `Deployment.Confirm`'s Module Contract |
