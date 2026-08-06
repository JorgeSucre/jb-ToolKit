<!--
Verification Report template.
Governed by: ../ENGINEERING_VERIFICATION_STANDARD.md — this template's
sections are exactly its "Required Report Structure": Purpose, Scope,
Method, Evidence, Observations, Result, Confidence, Recommendations. Do
not omit a section; write "None" or "N/A" rather than deleting one.
Program entry this report fulfills: ../VERIFICATION_PROGRAM.md
Produced by: the Verification Engineer role (../ENGINEERING_ROLES.md)

File naming: docs/engineering/verification/NNNN-<slug>.md, where NNNN is
the four-digit entry number from VERIFICATION_PROGRAM.md (e.g.
0001-authority-verification.md). Do not renumber a report once filed. A
re-verification of the same entry is a new file
(NNNN-<slug>-YYYY-MM-DD.md, or an addendum recorded in History below) — it
never overwrites the prior report's conclusion in place (Verification
Ethics #6: verification never rewrites history).

Delete this comment block when using the template.
-->

# Verification NNNN: <Title, matching the Verification Program entry>

**Program entry:** [VERIFICATION_PROGRAM.md #NNNN](../VERIFICATION_PROGRAM.md#nnnn--title)
**Verification Level(s):** <Authority | Dependency | Boundary | Encapsulation | State | Duplication | Complexity | Platform — see ENGINEERING_VERIFICATION_STANDARD.md, "Verification Levels">
**Date:** YYYY-MM-DD
**Role performing this verification:** Verification Engineer (see
[ENGINEERING_ROLES.md](../ENGINEERING_ROLES.md) — name the role, not an
identity)

## Purpose

Copy the Purpose from the Verification Program entry and make it concrete
— not "the grid works," but "the catalog renders in 3 columns when the
real controlling terminal is 150+ columns wide."

## Scope

What was checked, precisely, including which component(s), file(s), or
subsystem(s). State the boundary explicitly — what was **not** checked is
as important as what was, so a reader doesn't assume coverage that wasn't
performed.

## Method

The exact steps taken to gather evidence — commands run, environment used,
what was held constant, what was varied. Enough detail that an independent
Verification Engineer could reproduce the same check against the same
revision and reach substantially the same conclusion (Verification Ethics
#9, Consistency Over Novelty). "I read the code and it looks correct" is
not a method; it is the absence of one.

## Evidence

Raw output, execution traces, diffs, or file contents that directly
support each observation below — not a paraphrase of them. Quote command
output verbatim. Every piece of evidence identifies its source (file,
command, execution trace). If evidence is large, reference where it's
archived rather than summarizing it into a claim with no way to check it.

## Observations

Factual findings — not yet judged as problems. Per the Standard: "An
observation is a factual finding that does not necessarily indicate a
problem." Distinguish observations from recommendations and from
violations; a verification with zero violations and several honest
observations is a complete, successful report, not an incomplete one
(Verification Ethics #2: absence of findings is a valid result).

| # | Observation | Evidence |
|---|---|---|
| | | |

## Result

One state per claim in scope, using exactly these values (see
[ENGINEERING_VERIFICATION_STANDARD.md](../ENGINEERING_VERIFICATION_STANDARD.md),
"Result States"):

- **VERIFIED** — the documented contract is satisfied.
- **VERIFIED WITH OBSERVATIONS** — satisfied; see Observations above, none
  of which contradicts the contract.
- **SHARED AUTHORITY** — more than one module owns decision-making for the
  same concept; state whether this sharing is already documented as
  intentional (then this is a pass) or not (then it is a concern).
- **BOUNDARY VIOLATION** — implementation bypasses a documented
  architectural boundary.
- **ARCHITECTURAL VIOLATION** — implementation directly contradicts
  documented architecture. If the divergence instead means the *ADR* no
  longer reflects implementation, that is a **Documentation Observation**,
  not this — see [ENGINEERING_VERIFICATION_STANDARD.md](../ENGINEERING_VERIFICATION_STANDARD.md),
  "Relationship with Architecture Decision Records." Verification reports
  the divergence either way; it never resolves it by assumption.
- **NOT APPLICABLE** — out of scope for the inspected component.

| Claim checked | Result |
|---|---|
| | |

## Confidence

High / Medium / Low, per claim where it isn't uniform — reflecting
evidence quality, not reviewer certainty (see the Standard's "Confidence
Levels"). Report uncertainty honestly (Verification Ethics #7) rather than
rounding a Medium up to a High to make the report feel more conclusive.

## Recommendations

Optional. Never redefines the Result above — a system can be VERIFIED and
still carry a recommendation. For each: why it may be valuable, expected
impact, suggested priority. If a recommendation implies the architecture
itself should change, it is a proposal for the Engineering Architect, not
a verification finding — route it to a new or amended ADR rather than
treating the recommendation as authoritative on its own.

## History

| Date | Result | Note |
|---|---|---|
| YYYY-MM-DD | | Initial verification |
