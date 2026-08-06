<!--
Engineering Report template.
Governed by: ../ENGINEERING_VERIFICATION_STANDARD.md (evidence standard),
../ENGINEERING_ROLES.md (who produces this and what it does/doesn't authorize)

An Engineering Report summarizes completed engineering work for the roles
that will consume it next. It is NOT a Verification Report and does not
substitute for one: a claim in this report that a change "works" or is
"complete" is a claim, not evidence, until a Verification Engineer has
produced the corresponding entry under docs/engineering/verification/ (see
../VERIFICATION_PROGRAM.md). The Release Engineer must never release on
the strength of this report alone (../ENGINEERING_ROLES.md).

Use this template at the end of a unit of engineering work — an ADR's
implementation, a verification pass, a release preparation. Not every
section applies to every report; state "N/A" rather than omitting a
section silently, so a reader can tell "not applicable" from "forgotten."

Delete this comment block when using the template.
-->

# Engineering Report: <What This Work Was>

**Date:** YYYY-MM-DD
**Role(s) reporting:** <e.g. Implementation Engineer, Verification Engineer — see ../ENGINEERING_ROLES.md>
**Related ADR(s):** <link, or "none — non-architectural change">
**Related Verification Report(s):** <link, or "none yet — see Verification section below">

## 1. Summary

One paragraph: what changed, and why it mattered. Written for a reader who
will never open the diff.

## 2. What changed

Concrete, itemized. Group by area if the work spanned several (workflow,
layout, data model, documentation). Reference the files touched; for a
pattern repeated across many files, describe the pattern once with one or
two representative examples rather than listing every file.

## 3. Rationale

Why this approach, tied to a named Engineering Principle or a specific
piece of prior evidence (an incident, a verification finding, direct
feedback) — not asserted as self-evidently correct. If this report
accompanies an ADR, this section should be a pointer to it, not a
restatement of it (Single Source of Truth — see ../README.md).

## 4. Rejected alternatives

Every alternative approach that was seriously considered and set aside,
with the specific reason. If nothing was rejected, say so — but treat that
as worth double-checking, since most non-trivial engineering decisions
have at least one real alternative.

## 5. Verification performed

What was actually checked, by what method, with what result — not what
*should* be checked eventually. Distinguish:

- **Verified**: evidence exists (command output, a real execution trace, a
  reproduced failure and reproduced fix) and is referenced or included.
- **Not yet verified**: named explicitly, with a pointer to the
  Verification Program entry (../VERIFICATION_PROGRAM.md) it falls under,
  if one exists.

A bare assertion ("this was tested") without the evidence itself does not
satisfy this section — see [ENGINEERING_VERIFICATION_STANDARD.md](../ENGINEERING_VERIFICATION_STANDARD.md).

## 6. Performance impact

State it even when the answer is "none" — and show the reasoning (e.g. "no
new subprocess per iteration: X is cached at Y") rather than asserting it.

## 7. Architecture impact

What, if anything, changed about module boundaries, ownership, or
documented invariants. For most implementation work this should be
"none" — a report claiming architecture impact should point to the ADR
that authorized it (see ../ENGINEERING_ROLES.md, Engineering Architect
authority).

## 8. Future opportunities

Real, evidenced possibilities this work opens up or defers — not a
speculative feature list. Distinguish what's plausible from what's
actually been evaluated and deliberately deferred.

## 9. Known gaps / open questions

Anything this report knows to be incomplete, unverified, or inconsistent
with another document, named explicitly. A gap disclosed here is a normal
part of engineering work; a gap discovered later that this section could
have named is a process defect.
