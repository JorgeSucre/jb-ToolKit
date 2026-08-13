# Module Contract Migration Lessons

## Purpose

This document records engineering experience gained while migrating five
Deployment-layer modules to the Module Contract model
([MODULE_STANDARD.md](../architecture/MODULE_STANDARD.md)) following its
adoption in [ADR-0013](../architecture/0013-module-contracts.md). It is
not an ADR, not a Standard, not a specification, and not a process
document — it establishes no rule and changes no document it describes.
It is a retrospective: what actually happened, across five real migrations
and nine Boundary Verification passes, recorded so that a future
contributor repeating this process does not have to rediscover it from
scratch.

Every statement below traces to a specific migration and a specific
Verification Report. Where evidence is limited to one module, this
document says so rather than generalizing beyond what was observed.

## Validation Summary

**Modules taken through the full draft cycle:** `Deployment.Menu`,
`Deployment.Selection`, `Deployment.Planner`, `Deployment.Confirm`,
`Deployment.Renderer`, `Deployment.Installer`.

**Boundary Verification passes executed:** thirteen — `Deployment.Menu`
(2), `Deployment.Selection` (2), `Deployment.Planner` (1),
`Deployment.Confirm` (2), `Deployment.Renderer` (2), `Deployment.Installer`
(4). `Deployment.Planner` is the only module whose first draft required no
correction and therefore no second pass; `Deployment.Installer` is the
only module that required three correction cycles rather than one.

**Atomic claims checked at final verification:** 20 (`Deployment.Menu`) +
19 (`Deployment.Selection`) + 24 (`Deployment.Planner`) + 13
(`Deployment.Confirm`) + 23 (`Deployment.Renderer`) + 18
(`Deployment.Installer`) = 117, all VERIFIED at the point each module's
cycle closed.

**Adopted Contracts:** six. `Deployment.Menu` was the first, adopted
directly by ADR-0013's own Decision — the original precedent this entire
migration follows. `Deployment.Selection`, `Deployment.Planner`,
`Deployment.Confirm`, `Deployment.Renderer`, and `Deployment.Installer`
each reached a fully-verified state and an explicit "ready for adoption"
statement in their final Verification Report, then were formally adopted
in turn once `MODULE_STANDARD.md` §§10–14 recorded them as having
completed ADR-0013's own "Adoption is incremental, module by module"
sequence — drafted, independently Boundary-Verified, corrected where
findings existed, and re-verified. No per-module ADR was created or
required; ADR-0013 remains the sole governing adoption decision for all
six.

**Not part of this migration:** `Deployment.Catalog` and `Platform` have
Contracts (`MODULE_STANDARD.md` §9), but those were written to pressure-test
whether the model generalizes to different module shapes, before ADR-0013
existed — neither has been through Boundary Verification. They are
referenced here only where directly relevant.

## Patterns Observed

**First drafts usually, but not always, contained a defect.** Four of the
five modules' first drafts produced at least one CONTRADICTED or AMBIGUOUS
claim: `Deployment.Menu` (2 contradictions, 3 missing collaborators),
`Deployment.Selection` (2 contradictions, 1 ambiguous claim),
`Deployment.Confirm` (1 contradiction), `Deployment.Renderer` (1 ambiguous
claim). `Deployment.Planner`'s first draft verified 24/24 with no
correction needed. The model did not manufacture a finding to avoid a
clean result — its own governing standard treats absence of findings as a
valid outcome, and `Deployment.Planner`'s report recorded exactly that
rather than inventing a defect.

**Every correction converged in exactly one cycle.** Four modules required
correction (`Deployment.Menu`, `Deployment.Selection`, `Deployment.Confirm`,
`Deployment.Renderer`); all four reached a clean re-verification on the
first attempt after correction. No module required a third Boundary
Verification pass.

**No implementation file was ever modified.** Across all nine verification
passes and all four correction cycles, every fix was made to Contract text
alone; `core/deployment/*.sh` and `core/bootstrap/*.sh` were confirmed
unchanged (via `git status`) before every re-verification. Where the
question was posed explicitly — `Deployment.Confirm`'s and
`Deployment.Renderer`'s reports both asked directly whether their finding
was a Contract issue or an implementation issue — both answered Contract
issue, with the implementation named as behaving correctly in each case.

**MODULE_STANDARD.md changed early, then held.** The `Produces` field's
definition was refined twice, both directly triggered by
`Deployment.Selection`'s first draft (the raw Selected Applications
representation `Deployment.Planner` reads directly). The second of those
refinements removed implementation-specific wording (references to
accessors, raw representations) in favor of a single, technology-independent
test: whether another module relies on a fact for its own correctness.
After that point, three more full migration cycles — including
`Deployment.Renderer`, the largest and most-connected module verified —
produced real Contract defects but never required a further change to
`MODULE_STANDARD.md` §§1–6. A dedicated architectural investigation
comparing `Deployment.Selection`'s and `Deployment.Planner`'s raw-state
exposure patterns explicitly considered whether the model needed a new
distinction to tell them apart, and concluded it did not: both were
already correctly, identically covered by the existing `Produces`
definition.

**ADR-0013 was never revised.** It was written once, after
`Deployment.Menu` completed its own correct-then-verify cycle, and no
migration afterward required amending it.

**A defect found in one module's Contract can implicate an already-adopted
Contract, without being that module's own failure.** `Deployment.Renderer`'s
verification found that `Deployment.Menu`'s adopted Contract does not
record, from its own side, that `Deployment.Renderer` reads
`CATALOG_MENU_HW_IDS` — a variable `Deployment.Menu` owns — directly. This
happened once, was recorded as a "Contract Consistency Observation" rather
than scored against `Deployment.Renderer`, and `Deployment.Menu`'s Contract
was left unmodified, since amending an adopted Contract was outside every
task's authorized scope in this effort.

## What the Model Proved

**A Module Contract, alone, is sufficient evidence for Boundary
Verification.** Demonstrated five times — every verification in this
series was executed with `Architecture.md` and `Deployment-Architecture.md`
explicitly withheld, using only the Contract text as the architectural
authority, and every one reached a definite result.

**Verification does not depend on trusting the Architect's correction.**
Every re-verification treated all claims, including previously-verified
ones, as unproven again — explicitly instructed and explicitly followed —
and reached the same or an improved result each time, never a regression.

**The model separates recording a dependency from endorsing it.** Every
raw-state read found during this effort — `Deployment.Planner` reading
`Deployment.Selection`'s raw representation, five modules reading
`Deployment.Planner`'s raw Plan/Transaction state with no accessor,
`Deployment.Renderer` reading `Deployment.Menu`'s raw hardware-recommendation
cache — was recorded as a `Produces`/`Collaborates With` claim without
triggering a single implementation change or a recommendation to refactor.
Verification Reports that found these facts consistently declined to judge
whether the underlying architecture was sound, stating this was out of
scope by design.

**The model distinguishes an instance-level defect from a model-level
gap.** Two findings from `Deployment.Menu`'s early validation — no field
states which implementation files constitute a module's boundary; no rule
states whether shared infrastructure like `core/utils.sh` belongs in
`Collaborates With` — were explicitly left unresolved because no Contract
correction could address them; they were model-level, not instance-level,
and every task's restrictions correctly kept them out of scope for a
single module's correction.

## Common Types of Contract Defects

**Overly absolute wording.** Three separate instances, each falsified by
one real counter-example: `Deployment.Selection`'s Constraint 2 ("nothing
that reads it branches control flow on its value" — falsified by
`Deployment.Renderer`'s `plan_source_label`); `Deployment.Confirm`'s
Constraint 3 ("does not render anything itself" — falsified by three lines
of direct `echo`/`printf` output); `Deployment.Renderer`'s Produces 1
("not consumed by any other module as data" — technically falsified by two
command-substitution capture sites, though the underlying architectural
fact held).

**Claiming a capability that does not exist.** `Deployment.Menu`'s
Responsibility 3 asserted a `category` filter mode; the implementation had
exactly two real filter modes (`picks`, `hardware`), never a third.

**Claiming single-mechanism uniformity where two independent
implementations exist.** `Deployment.Selection`'s Responsibility 3 claimed
installed status is "checked the same way for every caller"; `install.sh`
determines the identical fact through its own separately duplicated logic,
never by calling `Deployment.Selection`'s function.

**Incomplete or one-directional collaboration records.**
`Deployment.Menu`'s original `Collaborates With` omitted three real,
evidenced edges (`Deployment.Planner`, `Deployment.Confirm`,
`Deployment.Renderer`) entirely, and stated its real relationship with
`Bootstrap` as one-directional ("Menu does not know Bootstrap exists")
when the evidence showed a real edge in both directions.

**Imprecision between a function actually called and a capability reached
indirectly.** `Deployment.Selection`'s `Collaborates With` → `Deployment.Menu`
claimed Menu calls "add/remove/toggle" directly; only `selection_toggle`
is ever called directly, with add/remove reachable only as its internal
implementation. This was the one finding in the series classified
AMBIGUOUS rather than CONTRADICTED, because the underlying capability was
real even though the literal function-name enumeration was not.

## Lessons for Future Module Authors

**Describe what the code does, not what the module's name or comments
imply it does.** `Deployment.Confirm`'s own header comment already stated
plainly that the y/n installation gate lives in `Deployment.Installer`, not
in `confirm.sh` — the risk this lesson guards against is trusting a
module's name ("Confirm") over what its code actually owns, not a failure
to find documentation.

**An absolute claim needs one real counter-example to fail.** Every
"nothing does X" or "does not do Y" claim found defective in this series
was falsified by a single line of code, not by a systemic pattern.
Narrower, more qualified claims (`Deployment.Planner`'s Constraint 4,
"the classification logic never branches on it," scoped to one specific
function rather than "nothing that reads it") held up where broader
versions of the same idea did not.

**Record a raw-state read as a fact, not as a problem to justify.**
Every leak found and correctly recorded in this series was written as a
plain statement of what reads what, directly — `Deployment.Selection`'s
"read directly by `Deployment.Planner`... not through an accessor,"
`Deployment.Renderer`'s "read directly from Menu's own module-level
variable, not through an accessor Menu exposes." None of these claims
argued for or against the pattern.

**When a fact is told from two modules' Contracts, both sides need to
actually say it.** `Deployment.Menu`'s adopted Contract does not record
`Deployment.Renderer`'s read of `CATALOG_MENU_HW_IDS`, even though
`Deployment.Renderer`'s Contract does. A collaborator relationship
recorded on only one side of a pair is an incomplete record even when the
side that does record it is accurate.

## Lessons for Verification Engineers

**Check the literal wording, not the evident intent.** Every contradiction
found in this series was a case where the claim's plain-language reading
was false, even though a more charitable reading might have been true. A
Verification Engineer who read `Deployment.Selection`'s Constraint 2 as
"provenance never affects installation decisions" (true) rather than
"nothing that reads it branches on its value" (what it actually said,
and false) would have missed a real, correctable defect.

**A missing collaborator is found by reconstructing the call graph
independently, not by checking the Contract's own list.** `Deployment.Menu`'s
three missing collaborators were found only by enumerating every function
the module calls and locating each definition — the Contract's own text
gave no indication anything was missing. This is the one respect in which
Boundary Verification, in this series, could not rely on the Contract
alone.

**A finding about one module's evidence can implicate a different,
already-adopted Contract.** When this happened (`Deployment.Renderer`
verification, `Deployment.Menu`'s Contract), the correct handling — used
once in this series — was to record it as a separate, informational
observation, score it against neither Contract's own result, and leave the
adopted Contract unmodified.

**Whether a claim survives re-verification after correction is not
guaranteed by the correction being well-reasoned.** Every correction in
this series was re-verified from scratch, and every one held — but the
process treated that as a result to confirm, not an assumption to carry
forward, in every single case.

## What Remains Open

**Five Contracts' adoption status was ambiguous for a period after
Boundary Verification completed — now resolved, not an open item.**
`Deployment.Selection`, `Deployment.Planner`, `Deployment.Confirm`,
`Deployment.Renderer`, and `Deployment.Installer` each reached a
fully-verified state and an explicit "ready for adoption" statement in
their own Verification Reports, but for a period afterward
`MODULE_STANDARD.md`'s own "Status" line for each of their sections still
read "first draft, not verified, not adopted," unchanged since drafting —
unlike `Deployment.Menu`, none had yet received an explicit adoption act.
A governance-model review determined that ADR-0013's own "Adoption is
incremental, module by module" sequence — drafted, independently
Boundary-Verified, corrected where findings existed, and re-verified — is
what the ADR itself defines as sufficient, and does not require a
dedicated ADR per module. `MODULE_STANDARD.md` §§10–14 were updated
accordingly; all five Contracts are now adopted.

**One Contract Consistency Observation is unresolved.**
`Deployment.Menu`'s adopted Contract does not record
`Deployment.Renderer`'s read of `CATALOG_MENU_HW_IDS`. Correcting it would
mean amending an adopted Contract, which was outside every task's
authorized scope in this effort.

**Two model-level gaps identified during `Deployment.Menu`'s original
validation remain unaddressed.** The model still has no field for which
implementation files or functions constitute a module's boundary, and no
stated rule for whether shared infrastructure (`core/utils.sh`) belongs in
`Collaborates With`. Both were re-confirmed as open, not resolved, during
this migration effort.

**Whether repository-wide Contract-to-Contract consistency needs its own,
repeatable verification is unresolved.** The one Contract Consistency
Observation found in this series was discovered incidentally, while
verifying a different module's Contract, not through any dedicated check
for it. Whether that should become a standing verification of its own is
not decided here.

**The remaining modules in the Deployment pipeline** — `Deployment.Transaction`,
`Bootstrap`, and every module outside Deployment entirely (`Maintenance`,
`Diagnostics`, `Reporting`, `Platform`) — have no Module Contract yet.
`Deployment.Installer` has since received one (see the bullet above).
`Deployment.Catalog` and `Platform` have Contracts that were
shape-validated but never boundary-verified. Whether or when migration
continues is not addressed here.
