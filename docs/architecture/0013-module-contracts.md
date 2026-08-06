# ADR-0013: Introduce Module Contracts

## Context

JB Toolkit's architecture has always been described in prose: a subsystem
table in `Architecture.md`, a wide "Explicitly NOT its job" column in
`Deployment-Architecture.md`, and rule-of-thumb text in `CONTRIBUTING.md`'s
"Where code belongs." This documentation served human readers well, but
three completed Verifications found it insufficient as evidence a
Verification Engineer could check mechanically, without re-deriving what
"the architecture says" means for a given file each time.

Verification 0003 (Boundary) found that `Deployment-Architecture.md`'s
Menus row stated, in prose, that filtering was explicitly not
`core/deployment/menu.sh`'s job — a claim contradicted by search and
category/pick/hardware filtering already in production since v2.3.2, never
caught because nothing about a free-text table cell forces a re-check
against the behavior it describes. The same verification found a second
claim, "Platform provides services only," that corresponded to no
documented text anywhere — a reasonable-sounding idea that had never
actually been written down, so the verification could only report its
absence, not confirm or deny it.

Verification 0002 (Dependency) found that `core/deployment.sh` sources
`core/bootstrap/hardware.sh` with no corresponding edge in `Architecture.md`'s
diagram, and that `Deployment-Architecture.md`'s own library-file inventory
for Deployment omits `doctor.sh`, which `core/deployment.sh` genuinely
sources. In both cases, the set of files a module actually touches had
drifted from the set prose said it touches, undetected, because nothing
enumerated the set in a form a diff or a grep could check against reality.

In response, the Engineering Architect role designed a structured Module
Contract model, recorded in `docs/architecture/MODULE_STANDARD.md`: seven
fields — Purpose, Responsibilities, Consumes, Produces, Collaborates With,
Constraints, Defined By — with every architectural claim expressed as one
atomic, individually falsifiable sentence, carrying at most one
Verification Level tag.

The model was not adopted on design review alone. It went through two
rounds of refinement, then validation against module shapes deliberately
different from its own worked example — a pure-data module
(`Deployment.Catalog`) and a service module (`Platform`) — to test whether
it generalized beyond a menu screen. Finally, a Verification Engineer
executed Boundary Verification against the `Deployment.Menu` Module
Contract using only that Contract as the architectural source, with
`Architecture.md`, `Deployment-Architecture.md`, `Module-Overview.md`,
ADRs, and prior Verification Reports explicitly withheld. That first pass
found 14 of the Contract's 17 atomic claims fully verifiable from the
Contract alone. The remaining three findings were: a claim asserting a
filter mode (`category`) that does not exist in
`core/deployment/menu.sh`; a Collaborates With claim ("Menu does not know
Bootstrap exists") contradicted by direct calls into
`core/bootstrap/hardware.sh` and `core/bootstrap/ui.sh`; and a Constraint
whose correctness could be confirmed only by reading files beyond the
Contract and `menu.sh`, because a literal word it uses (`manual`) also
names an unrelated concept elsewhere in the code. Separately, three real
collaborators (`Deployment.Planner`, `Deployment.Confirm`,
`Deployment.Renderer`) had call-graph edges in `menu.sh` with no
corresponding claim in the Contract at all.

The Engineering Architect role then corrected only the `Deployment.Menu`
Contract, tracing each change to one of these findings, without modifying
the Module Contract model itself. A second Boundary Verification, executed
independently and without assuming the correction was valid, checked all
20 resulting atomic claims against `core/deployment/menu.sh` from scratch
and verified all 20.

This satisfies the two preconditions `MODULE_STANDARD.md` §8 stated before
adoption could reasonably be considered: more than one module shape worked
through by hand, and a Verification Engineer actually executing a
verification against a hand-written Contract to test whether the claim
format holds up in practice. The remaining §8 precondition — a decision on
repository-wide versus incremental adoption — is not a design question the
model itself takes a position on, and is resolved by the decision below.

## Decision(s)

### The Module Contract becomes the canonical architectural representation of a module

JB Toolkit adopts the Module Contract, as defined in
`docs/architecture/MODULE_STANDARD.md`, as the representation a module's
architecture is measured against. A Module Contract expresses seven
fields — Purpose, Responsibilities, Consumes, Produces, Collaborates With,
Constraints, Defined By — and every module should eventually be
represented by exactly one.

This is decided on the evidence in Context: prose descriptions of the same
module drifted from its real behavior in three separate, independently
found ways (0002, 0003 twice), and a Module Contract, once corrected, was
shown by direct execution to close that gap for a real module —
`Deployment.Menu`, 20 of 20 claims verified against implementation with no
other document consulted.

What was explicitly rejected in reaching this decision is recorded in
"Alternatives considered" below.

### Every architectural claim is atomic, and carries at most one Verification Level

Every claim under Responsibilities, Consumes, Produces, Collaborates With,
and Constraints is written as one atomic sentence, true or false entirely
on its own. Each claim carries at most one Verification Level tag
(`[checked by: <Level>]`); a claim with no tag is not yet covered by any
verification, and that absence is recorded as a visible fact rather than
left implicit.

This is decided because atomicity is what made the `Deployment.Menu`
verification's findings possible to state precisely: the false `category`
filter-mode claim and the incomplete Bootstrap claim were each isolable to
one sentence and one piece of contradicting code, rather than requiring a
judgment call about whether an entire paragraph "still sounds right."

### Engineering Verifications consume Module Contracts wherever one exists

Authority, Dependency, and Boundary Verification read a module's Module
Contract instead of reconstructing evidence from `Architecture.md`,
`Deployment-Architecture.md`, or `Module-Overview.md`, once that module has
one. This makes the Module Contract the executable architectural
specification for that module during Engineering Verification: each atomic
claim is checked directly against implementation evidence rather than
interpreted from prose first, exactly as the two Boundary Verification
passes against `Deployment.Menu`'s Contract in Context did — 14 of 17
claims resolved from the Contract and `menu.sh` alone in the first pass, 20
of 20 in the second, with no other document consulted either time. A
module without a Module Contract continues to be verified against its
existing prose documentation.

### Adoption is incremental, module by module

Repository-wide migration is not decided here. `Deployment.Menu` is the
only module whose Module Contract is adopted as canonical by this
decision. Every other module continues to be represented, and verified,
by its existing prose documentation until it receives its own Module
Contract that has been through the same sequence described in Context:
written, validated for shape, corrected against findings from an
independent Boundary Verification, and re-verified. `MODULE_STANDARD.md`
§8 left this question explicitly open, taking no position on it; deciding
it here, rather than deferring it again, is itself part of what this ADR
settles.

## Alternatives considered

**Continue using descriptive architecture only.** Rejected — this had
already been the state of the project for its entire history, and the
Verifications cited in Context found real, undetected drift between that
prose and the implementation it described more than once. Continuing would
mean accepting recurrence of the same failure mode rather than removing
it.

**Introduce a separate, verification-specific document per module,
alongside existing architecture documentation.** Rejected — this would
create two documents describing the same module's boundary, each free to
drift from the other exactly the way the pre-existing three-document split
(a table row, a diagram, a paragraph) already had. `MODULE_STANDARD.md` §3
states the relevant design goal directly: give every module's architecture
exactly one authoritative document, not a fourth one added to the existing
three.

## Consequences

### Immediate

`docs/architecture/MODULE_STANDARD.md`'s own "Status: design proposal, not
adopted" framing is superseded by this decision.

`Deployment.Menu`'s Module Contract (`MODULE_STANDARD.md` §7), corrected as
of the verification cycle described in Context, is adopted as that
module's canonical representation. Authority, Dependency, and Boundary
Verification of `Deployment.Menu` read that Contract going forward.
`Deployment-Architecture.md`'s Menus row is not deleted or amended by this
decision — it remains available, but the Module Contract is what
verification now reads first.

Boundary Verification of a module with an adopted Contract no longer
requires reconstructing evidence from `Architecture.md`,
`Deployment-Architecture.md`, or `Module-Overview.md` — demonstrated
directly by the second verification pass in Context, which checked
`Deployment.Menu` against its Contract alone and reached 20 of 20 without
consulting any of the three.

### Deferred, from incremental adoption

No other module receives a Module Contract as a direct consequence of this
decision. `Deployment.Catalog` and `Platform` have Contracts written and
validated for shape (`MODULE_STANDARD.md` §9), but neither has been
independently boundary-verified the way `Deployment.Menu` was, and neither
is adopted as canonical here — writing and shape-validating a Contract and
verifying it against real implementation are demonstrated in Context to be
different steps, and only both together preceded `Deployment.Menu`'s
adoption. Every other module in the repository is untouched: it continues
to be represented, and verified, exactly as it was before this decision.

Maintaining a Module Contract is an added cost for every module that
receives one: it must be kept current as implementation changes, in
addition to whatever prose documentation already described that module,
for as long as both continue to exist side by side for that module. This
cost recurs each time incremental adoption extends to another module.

## Future implications

The Module Contract model, as adopted, does not define how an
implementation's files or functions map to a named module for verification
purposes. The `Deployment.Menu` verification in Context had to assume
`core/deployment/menu.sh` was the module's boundary; the Contract itself
states no such mapping, and whether functions like
`start_deployment_flow`/`run_deployment_menu` are inside or outside
`Deployment.Menu` was not decidable from the Contract text alone. This was
found during verification, not resolved by it, and no evidence gathered so
far establishes it as a deliberate design choice — it remains open.

The model also does not state whether a module's use of shared,
non-architectural infrastructure (`core/utils.sh`, sourced by nearly every
module) belongs in that module's Collaborates With field. The
`Deployment.Menu` verification found this omission but could not determine,
from the Contract or from any other evidence gathered, whether it is a gap
or a correct exclusion — this too remains open rather than settled by this
decision.

Neither gap blocked `Deployment.Menu`'s adoption — the verification that
found them completed successfully around them — but both will recur for
every future module a Contract is written for, since neither is specific
to `Deployment.Menu`. Resolving them requires revisiting the Module
Contract model itself (adding a field, or a stated convention), which this
decision does not do.

The decision to migrate incrementally means `Deployment-Architecture.md`,
`Architecture.md`, and `Module-Overview.md` remain authoritative for every
module without an adopted Contract, for as long as that continues to be
true — a future engineer should not assume Module Contract coverage is
complete just because this ADR exists. Revisiting the pace or scope of
adoption would be justified by the same kind of evidence this decision
itself relied on: a Verification Report finding that a Contract, once
written and boundary-verified for another module, holds up the way
`Deployment.Menu`'s did — or finding that it does not.
