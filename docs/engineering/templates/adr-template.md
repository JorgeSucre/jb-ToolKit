<!--
Architecture Decision Record template.
Governed by: ../../architecture/README.md (when to write one, how ADRs evolve)
Authored by: the Engineering Architect role (../ENGINEERING_ROLES.md)

File location: docs/architecture/NNNN-<slug>.md, NNNN is the next unused
four-digit number — numbers are permanent and sequential, never reused,
never reordered even if a later ADR supersedes an earlier one.

An ADR is a historical record of a decision, not documentation of the
current implementation. Write it once, at the time of the decision; amend
it only with a dated addendum when a later decision changes its status
(see ../../architecture/README.md, "How ADRs evolve") — never rewrite it
to match code that has since moved on.

Delete this comment block when using the template.
-->

# ADR-NNNN: <Decision Title> (vX.Y.Z, if tied to a release)

## Context

What situation made this decision necessary? What was true before it, what
prompted the question, and what would happen if no decision were made.
Include real evidence where it exists — a prior incident, a verification
finding, direct user feedback — not a hypothetical justification.

If this ADR is correcting or reversing an earlier one, say so explicitly
here and name it: "ADR-NNNN reversed the `l` command ADR-0011 introduced,
after real-world use showed..." is the standard this project holds itself
to (see [architecture/0012-terminal-ui-refinement.md](../../architecture/0012-terminal-ui-refinement.md)
for the pattern). A reversal is not a failure to hide; it's evidence the
process is working.

## Decision(s)

The decision itself, stated plainly first, then the reasoning. For a
decision with several distinct parts, use one `###` subsection per part
rather than one large undifferentiated block — each subsection should be
independently skimmable by a reader who only cares about that one part.

For each part, address:

- **What was decided**, in terms specific enough to implement from.
- **Why**, tied to a named Engineering Principle or a concrete piece of
  evidence — not asserted as self-evidently correct.
- **What was explicitly rejected** as part of reaching this decision, and
  why it fell short (a full rejected alternative belongs in "Alternatives
  considered" below; a rejection specific to one part of a multi-part
  decision can stay inline here).

## Alternatives considered

Every genuinely distinct alternative that was evaluated and not chosen,
each with the specific reason it was rejected. An ADR with no alternatives
listed is a decision that wasn't actually weighed against anything — even
a two-line "rejected: X, because Y" is stronger than an empty section. If
a proposal in the originating request was rejected outright, it belongs
here with the same rigor as an alternative you thought of yourself.

## Consequences

What changed as a direct result of this decision — files touched,
behavior changed, invariants gained or given up. Distinguish what was
**required** to change from what was **deliberately left untouched**; both
are consequences worth recording, and "explicitly not touched" prevents a
future reader from assuming a wider blast radius than actually occurred.

## Future implications

What this decision constrains or enables later. If it creates a tension
the project is deliberately not resolving yet (a known limitation, a
deferred generalization), name it here rather than silently letting a
future engineer rediscover it. If a future change would need to revisit
this decision, say what evidence would justify doing so — the same
standard this ADR itself was held to.
