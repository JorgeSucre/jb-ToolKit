# JB Toolkit Engineering Verification Standard

> _Engineering quality is not determined by opinion.
> It is demonstrated through repeatable evidence._

---

# Purpose

The Engineering Verification Standard defines how engineering work is evaluated throughout JB Toolkit.

Its purpose is not to redesign the project.

Its purpose is to verify that the implementation remains consistent with the project's documented engineering principles and architectural decisions.

Verification exists to answer one question:

> Does the implementation still satisfy its documented contracts?

The standard intentionally separates facts from recommendations.

Verification is evidence-driven.

Recommendations are optional.

---

# Relationship with the Engineering Principles

The Engineering Principles define what the project believes.

This document defines how those beliefs are verified.

Principles answer:

> What should be true?

Verification answers:

> Can we prove that it is true?

Every verification performed in JB Toolkit should trace back to one or more Engineering Principles.

---

# Verification Philosophy

Verification is not auditing.

Verification is not code review.

Verification is not refactoring.

Verification is the process of collecting objective evidence and comparing it against documented engineering contracts.

The goal is understanding.

Not criticism.

Not optimization.

Not feature development.

---

# Fundamental Rules

Every verification follows the same rules.

## Rule 1

Evidence always outweighs opinion.

Every conclusion must reference observable implementation.

---

## Rule 2

Recommendations never redefine correctness.

A system may be architecturally correct while still having possible improvements.

Recommendations must always be presented separately.

---

## Rule 3

Observations are not violations.

Finding something interesting does not imply that something is wrong.

Verification distinguishes facts from problems.

---

## Rule 4

Architecture is verified against documented contracts.

Not against personal preference.

If no documented contract exists, verification should report the absence of documentation—not invent a new contract.

---

## Rule 5

Verification must be reproducible.

Two independent engineers applying the same verification process to the same revision should reach substantially the same conclusions.

---

# Appendix A — Verification Ethics

Engineering verification is founded on intellectual honesty.

The purpose of verification is to understand the current system through evidence.

It is not an exercise in criticism, optimization, or personal preference.

Every verification performed within JB Toolkit should follow these principles.

---

## 1. Evidence Before Opinion

Every conclusion must be supported by verifiable evidence.

Personal preference, intuition, or experience may motivate investigation, but they never constitute proof.

Evidence always takes precedence over opinion.

---

## 2. Absence of Findings Is a Valid Result

A verification that finds no architectural issues is successful.

The purpose of verification is not to produce findings.

The purpose is to determine whether documented engineering contracts remain true.

No findings should ever be manufactured to justify the verification effort.

---

## 3. Observations Are Not Violations

Not every observation represents a problem.

Verification must distinguish between:

- observations
- recommendations
- architectural concerns
- documented violations

These concepts are intentionally independent.

---

## 4. Recommendations Never Change Reality

Recommendations describe possible future improvements.

They do not redefine the correctness of the current implementation.

A recommendation should never be presented as evidence that the current architecture is incorrect.

---

## 5. Verify the System That Exists

Verification evaluates the implemented system.

It does not evaluate the system the reviewer wishes existed.

Architectural preferences must never replace documented contracts.

If implementation satisfies its documented architecture, verification should report success even when alternative designs may exist.

---

## 6. Respect Documented Decisions

Architecture Decision Records represent historical engineering decisions.

Verification may determine whether implementation still follows those decisions.

Verification must never silently replace, reinterpret, or invalidate documented architectural intent.

When implementation and documentation diverge, the divergence should be reported—not resolved by assumption.

---

## 7. Report Uncertainty Honestly

When available evidence is incomplete, verification should explicitly report uncertainty.

Confidence should decrease as evidence becomes weaker.

Unknown information must never be replaced with assumptions.

It is preferable to report uncertainty than to report false certainty.

---

## 8. Every Claim Must Be Traceable

Every engineering claim should identify its source.

Acceptable sources include:

- implementation
- engineering documentation
- architecture documentation
- Architecture Decision Records
- verification output
- runtime behavior

Readers should always be able to reproduce the conclusion independently.

---

## 9. Consistency Over Novelty

Verification values consistency more than originality.

Producing new findings is never an objective.

Producing repeatable conclusions is.

Independent reviewers applying the same verification process to the same revision should reach substantially the same conclusions.

---

## 10. Protect Long-Term Understanding

Every verification should improve the project's long-term understanding.

Reports should reduce ambiguity.

They should clarify engineering intent.

They should preserve architectural knowledge for future contributors.

The value of verification is measured not by the number of findings, but by the confidence it provides in the engineering of the system.

---

## Closing Statement

Verification is an act of stewardship.

Its purpose is not to prove that software is imperfect.

Its purpose is to preserve understanding, maintain architectural integrity, and ensure that future engineering decisions remain grounded in evidence rather than assumption.

Engineering excellence is achieved not by finding more problems, but by describing reality with precision, honesty, and repeatable evidence.

---

# Verification Levels

Every verification belongs to one or more of the following domains.

## Authority Verification

Purpose

Verify that every major engineering concept has one authoritative owner.

Examples

- Version
- Catalog
- Selection
- Planning
- Storage
- Transactions

Questions

Who owns this concept?

Who may mutate it?

Who consumes it?

Is authority shared?

Evidence required

Implementation references.

Architecture documentation.

ADRs.

---

## Dependency Verification

Purpose

Verify module relationships.

Questions

Who depends on whom?

Are dependency directions respected?

Are dependency cycles present?

Evidence required

Import graph.

Source references.

Architecture diagrams.

---

## Boundary Verification

Purpose

Verify architectural boundaries.

Questions

Can modules bypass documented APIs?

Are responsibilities crossing documented boundaries?

Evidence required

Call graph.

Public interfaces.

Internal interfaces.

---

## Encapsulation Verification

Purpose

Verify that internal representations remain internal.

Questions

Can another module manipulate implementation details directly?

Does a consumer know more than it should?

Evidence required

State access.

Shared structures.

Internal contracts.

---

## State Verification

Purpose

Verify ownership and lifecycle of authoritative state.

Examples

- STATE_FILE

- PLAN\_\*

- TXN\_\*

- SELECTED_APPS

Questions

Who creates it?

Who mutates it?

Who consumes it?

Who owns persistence?

---

## Duplication Verification

Purpose

Verify that engineering concepts have one implementation.

Questions

Is logic duplicated?

Are multiple implementations intentionally different?

Evidence required

Code comparison.

Behavior comparison.

---

## Complexity Verification

Purpose

Measure maintainability.

Examples

Large functions.

Nested control flow.

Responsibility concentration.

High fan-out.

High fan-in.

Complexity should always be measured.

Never guessed.

---

## Platform Verification

Purpose

Verify platform compatibility.

Examples

Supported Bash version.

Supported macOS version.

Homebrew behavior.

Filesystem assumptions.

Platform verification ensures that engineering contracts remain valid across supported environments.

---

# Verification Evidence

Every conclusion must identify its evidence.

Evidence may include:

- implementation
- documentation
- ADRs
- runtime behavior
- validation output

Evidence should always identify its source.

---

# Result States

Every verification produces one result.

## VERIFIED

The documented contract is satisfied.

---

## VERIFIED WITH OBSERVATIONS

The contract is satisfied.

Additional observations are recorded.

No architectural contradiction exists.

---

## SHARED AUTHORITY

More than one module owns decision-making for the same concept.

Intentional sharing must be documented.

Otherwise it becomes an architectural concern.

---

## BOUNDARY VIOLATION

Implementation bypasses documented architectural boundaries.

---

## ARCHITECTURAL VIOLATION

Implementation directly contradicts documented architecture.

---

## NOT APPLICABLE

The verification does not apply to the inspected component.

---

# Observation Severity

Severity is independent from correctness.

Possible levels

Low

Medium

High

Critical

Severity measures engineering impact.

It does not determine verification status.

---

# Confidence Levels

Confidence measures the quality of the available evidence.

High

Direct implementation evidence.

Medium

Indirect but consistent evidence.

Low

Incomplete evidence.

Confidence reflects evidence quality.

Not reviewer confidence.

---

# Required Report Structure

Every verification report must contain:

Purpose

Scope

Method

Evidence

Observations

Result

Confidence

Recommendations

No section should be omitted.

---

# Recommendations

Recommendations are optional.

They must never change verification results.

Recommendations should explain:

Why the improvement may be valuable.

Expected impact.

Implementation priority.

Recommendations are not engineering requirements.

---

# Relationship with Architecture Decision Records

Verification respects documented architectural decisions.

If implementation differs from an ADR:

Architectural Violation.

If an ADR no longer reflects implementation:

Documentation Observation.

Verification never rewrites history.

---

# Verification Lifecycle

Engineering Principles

↓

Architecture Decision Records

↓

Implementation

↓

Verification

↓

Release

↓

Maintenance

Verification always happens after implementation.

Never before.

---

# Non-Goals

The Engineering Verification Standard does not define:

Coding style.

Programming language.

Formatting rules.

Naming conventions.

Directory structure.

Testing methodology.

Release process.

Implementation techniques.

Those concerns belong in their respective engineering documents.

---

# Closing Statement

Verification exists to protect understanding.

Engineering quality is achieved through evidence, consistency, and repeatable reasoning.

A successful verification does not prove that software is perfect.

It proves that the implementation remains faithful to its documented engineering principles.
