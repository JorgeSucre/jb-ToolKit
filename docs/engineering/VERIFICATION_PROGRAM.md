# Verification Program

Referenced by: [README.md](README.md). References: [ENGINEERING_VERIFICATION_STANDARD.md](ENGINEERING_VERIFICATION_STANDARD.md) (defines what evidence each entry below must produce, and the eight Verification Levels each entry is drawn from), [ENGINEERING_PRINCIPLES.md](ENGINEERING_PRINCIPLES.md) (the principles each entry protects, cited below by number), [ENGINEERING_ROLES.md](ENGINEERING_ROLES.md) (the Verification Engineer executes this program).

This document is the complete, ordered list of verifications JB Toolkit's
engineering process commits to performing over the project's lifetime. It
defines **what gets checked, in what order, and why** — not the checks
themselves. Executing an entry produces a Verification Report
(`docs/engineering/verification/NNNN-<slug>.md`, using
[templates/verification-template.md](templates/verification-template.md)),
which does not exist until a Verification Engineer actually performs the
work. **No verification report exists yet.** Defining this program is not
performing it.

## How to read this program

Each entry defines:

- **Purpose** — the specific claim this verification exists to prove or
  disprove.
- **Verification Level(s)** — which of the Standard's eight domains
  (Authority, Dependency, Boundary, Encapsulation, State, Duplication,
  Complexity, Platform — [ENGINEERING_VERIFICATION_STANDARD.md](ENGINEERING_VERIFICATION_STANDARD.md),
  "Verification Levels") this entry draws from. Most entries below map
  onto exactly one level; entries covering a whole subsystem (0007–0009)
  draw on several at once.
- **Referenced Engineering Principles** — cited by number, from
  [ENGINEERING_PRINCIPLES.md](ENGINEERING_PRINCIPLES.md). Named, not
  redefined.
- **Expected scope** — what parts of the repository this verification
  touches.
- **Priority** — P0 (structural; everything else assumes it holds), P1
  (protects a specific, already-demonstrated failure mode on this
  project), P2 (subsystem-specific correctness).
- **Dependencies** — which other entries should already have a `VERIFIED`
  or `VERIFIED WITH OBSERVATIONS` report before this one is meaningful.
- **Expected deliverable** — the Verification Report this entry produces
  when executed, using one of the Standard's Result States.

Numbering is permanent once assigned — an entry is never renumbered or
deleted, only re-verified under the same number (see
[ENGINEERING_VERIFICATION_STANDARD.md](ENGINEERING_VERIFICATION_STANDARD.md),
"Verification Ethics" #6: verification never rewrites history).

## The program

### 0001 — Authority Verification

**Purpose.** Prove that every fact the system depends on has exactly one
authoritative source, structurally — not merely documented as
single-sourced. Example claims in scope: the version identifier
(`JB_VERSION`) is defined in exactly one place and every consumer reads
that one place; a package identifier exists in exactly one `app.conf`; a
category is single-valued per application.

**Verification Level(s).** Authority.

**Referenced Engineering Principles.** Principle 2 (Single Authority);
Principle 3 (Evidence over Opinion).

**Expected scope.** Repository-wide grep/structural audit for values that
should be single-sourced but are found defined, duplicated, or hardcoded
in more than one place.

**Priority.** P0.

**Dependencies.** None — this is a foundational check other verifications
can assume passed.

**Expected deliverable.** A Verification Report listing every audited
"should be single-sourced" fact, its actual source(s), and a Result State
per fact.

### 0002 — Dependency Verification

**Purpose.** Prove that the module boundaries this project documents as
one-directional actually are. Example claims in scope: Bootstrap sources
the Deployment library but Deployment never sources Bootstrap; no
top-level module (`core/bootstrap.sh`, `core/diagnostics.sh`,
`core/maintenance.sh`, `core/deployment.sh`, `core/report.sh`) reads
another module's internals directly.

**Verification Level(s).** Dependency.

**Referenced Engineering Principles.** Principle 2 (Single Authority);
Principle 9 (Tool Independence — a dependency graph should hold regardless
of shell, editor, or platform specifics).

**Expected scope.** Static analysis of `source` statements and
cross-module function calls across `core/`.

**Priority.** P0.

**Dependencies.** None.

**Expected deliverable.** A directed dependency graph of actual `source`
relationships, compared against the documented one
([Architecture.md](../Architecture.md)), with every discrepancy named.

### 0003 — Boundary Verification

**Purpose.** Prove that each layer only does what it is documented to do —
distinct from Dependency Verification (0002), which checks *what a layer
can see*; this checks *what a layer is allowed to do*. Example claim in
scope: `core/deployment/render.sh` performs presentation only and mutates
nothing; `core/deployment/install.sh` never reads the catalog and executes
plan records verbatim (an invariant `docs/Deployment-Architecture.md`
states explicitly).

**Verification Level(s).** Boundary.

**Referenced Engineering Principles.** Principle 2 (Single Authority);
Principle 4 (Stable Contracts).

**Expected scope.** Per-layer audit against each layer's documented
"Explicitly NOT its job" contract (`docs/Deployment-Architecture.md`'s
Layer Responsibilities table and equivalents for other modules).

**Priority.** P0.

**Dependencies.** 0002 (a boundary violation is often a dependency
violation in disguise; verify the graph first).

**Expected deliverable.** A Verification Report, one row per documented
layer contract, each with a Result State and the evidence checked.

### 0004 — State Ownership Verification

**Purpose.** Prove that every piece of shared mutable state has exactly
one writer. Example claims in scope: `SELECTED_APPS` is written only
through `selection.sh`'s accessors, never assigned directly elsewhere;
`state.env` keys are each written by exactly one module; `PLAN_*` globals
are written only by `planner.sh`; `TXN_*` globals are written only by
`transaction.sh`.

**Verification Level(s).** State.

**Referenced Engineering Principles.** Principle 2 (Single Authority).

**Expected scope.** Repository-wide search for direct writes to each
documented shared-state variable/file, outside its owning module.

**Priority.** P0.

**Dependencies.** 0001 (state ownership is a special case of authority).

**Expected deliverable.** A Verification Report enumerating every shared
state surface, its documented owner, and every write site found, with any
write site outside the documented owner flagged as a Result State other
than `VERIFIED`.

### 0005 — Duplication Verification

**Purpose.** Distinguish **justified** duplication (recorded in an ADR,
with a stated reason it must not be merged — e.g. `install.sh`'s
installed-state check duplicates `selection.sh`'s `app_already_installed`
specifically *because* the installer must never read the catalog, per
[architecture/0012-terminal-ui-refinement.md](../architecture/0012-terminal-ui-refinement.md))
from **unjustified** duplication (the same logic reimplemented without a
recorded reason, free to drift).

**Verification Level(s).** Duplication.

**Referenced Engineering Principles.** Principle 2 (Single Authority).

**Expected scope.** Cross-file search for near-identical logic blocks;
cross-reference each finding against `docs/architecture/*.md` for a
recorded justification.

**Priority.** P1.

**Dependencies.** 0001.

**Expected deliverable.** A Verification Report listing every duplication
found, each marked justified (with its ADR citation, Result:
`VERIFIED WITH OBSERVATIONS`) or unjustified (a defect to resolve).

### 0006 — Complexity Verification

**Purpose.** Prove that implementation complexity is load-bearing, not
speculative — no unrequested abstraction, no configuration for a value
that never changes, no flexibility built for a future consumer that
doesn't exist yet. Complements Duplication Verification (0005): that
entry asks "is this repeated," this one asks "does this need to exist at
all, in this shape." Per the Standard: complexity is always measured, never
guessed.

**Verification Level(s).** Complexity.

**Referenced Engineering Principles.** Principle 0 (long-term clarity);
Principle 1 (Simplicity over Cleverness); the Decision Hierarchy's
Maintainability priority.

**Expected scope.** Whole-repository review for unused generality, dead
configuration surface, and abstractions with a single call site.

**Priority.** P1.

**Dependencies.** None.

**Expected deliverable.** A Verification Report measuring complexity
(large functions, nested control flow, responsibility concentration, high
fan-in/fan-out — see the Standard's "Complexity Verification" examples),
each finding with what it costs to keep and what would replace it if
removed, filed as a recommendation, never a redefinition of correctness.

### 0007 — Catalog Verification

**Purpose.** Prove the catalog's own internal contract holds in the real
data, not just that the validator (`validate_catalog`, rules V1–V12)
exists and is documented. Example claims in scope: every application
passes every validation rule; every `RELATED` reference resolves; every
`JB_PICK=true` carries a non-fabricated `JB_PICK_NOTE`
([architecture/0009-catalog-evolution.md](../architecture/0009-catalog-evolution.md)'s
truthfulness standard); `CATEGORY` is genuinely single-valued per
application on disk, not just by schema.

**Verification Level(s).** Authority; Boundary (subsystem verification —
draws on more than one level).

**Referenced Engineering Principles.** Principle 2 (Single Authority);
Principle 3 (Evidence over Opinion).

**Expected scope.** `catalog/` in full: every `app.conf`, `presets.conf`,
and the validator/doctor output run against them.

**Priority.** P2.

**Dependencies.** 0001, 0004, 0011.

**Expected deliverable.** A Verification Report recording a live
`--validate`/`--doctor` run's output alongside manual spot-checks of the
claims validation *doesn't* structurally enforce (e.g. `JB_PICK_NOTE`
truthfulness, which no validator can automate).

### 0008 — Bootstrap Verification

**Purpose.** Prove Bootstrap's specific documented claims hold: the
per-application engine pattern (`retry` + `run_cmd --visible` + fresh-query
verification) is actually used for every automated install step; the
documented hard-abort points are the *only* hard-abort points; the
onboarding wizard genuinely shares the Deployment library rather than
reimplementing catalog, selection, or planning logic of its own.

**Verification Level(s).** Dependency; Duplication (subsystem
verification).

**Referenced Engineering Principles.** Principle 2 (Single Authority).

**Expected scope.** `core/bootstrap.sh`, `core/bootstrap/*.sh`.

**Priority.** P2.

**Dependencies.** 0002, 0003.

**Expected deliverable.** A Verification Report tracing each documented
Bootstrap claim to the code that implements it, with a real execution
trace for at least one full run.

### 0009 — Deployment Verification

**Purpose.** Prove Deployment's documented invariants hold in a real
execution, end to end: one selection model with no parallel path; the
planner is the only decision-making layer; the installer executes plan
records verbatim; hardware recommendations are genuinely advisory-only,
never auto-selecting; the responsive terminal grid renders at the
documented breakpoints in a real terminal (the exact claim that was found
false, then proven fixed, by direct execution trace rather than
description, in
[architecture/0012-terminal-ui-refinement.md](../architecture/0012-terminal-ui-refinement.md) —
this entry exists to make that kind of check routine instead of
incident-driven).

**Verification Level(s).** Authority; Boundary; State; Platform (subsystem
verification — draws on the most levels of any single entry, matching how
central Deployment is to the toolkit).

**Referenced Engineering Principles.** Principle 2 (Single Authority);
Principle 3 (Evidence over Opinion).

**Expected scope.** `core/deployment.sh`, `core/deployment/*.sh`, executed
against a real terminal session, not just a piped/non-interactive one.

**Priority.** P2.

**Dependencies.** 0002, 0003, 0004, 0007, 0011, 0012.

**Expected deliverable.** A Verification Report built from real execution
traces (interactive and CLI), each documented invariant checked against
actual output, not against the code that is supposed to produce it.

### 0010 — Documentation Consistency Verification

**Purpose.** Prove that every normative document — one whose own text
claims authority over a contract, e.g.
[Catalog-Format.md](../Catalog-Format.md), [Deployment-Architecture.md](../Deployment-Architecture.md) —
still matches the code it describes: function names that exist, rule
counts that match (a validator described as "V1–V11" when a twelfth rule
already shipped is a failure this entry exists to catch), diagrams whose
flow matches actual control flow.

**Verification Level(s).** Not one of the Standard's eight code-focused
levels directly — this entry applies Principle 6 (Documentation follows
Implementation) to `docs/` itself, the same way 0007–0009 apply the eight
levels to a specific subsystem.

**Referenced Engineering Principles.** Principle 6 (Documentation follows
Implementation); Principle 2 (Single Authority); Principle 3 (Evidence
over Opinion).

**Expected scope.** Every document in `docs/` (excluding
`docs/engineering/` and `docs/architecture/`, which 0001–0009 already
exercise indirectly) cross-checked line by line against the code and data
it references.

**Priority.** P1 — documentation drift is a demonstrated, repeated failure
mode on this project (see "Why a governance layer exists" in
[README.md](README.md)), not a theoretical risk.

**Dependencies.** 0007, 0008, 0009 (you cannot verify a document matches
reality until another entry has established what reality is).

**Expected deliverable.** A Verification Report: one row per normative
document, each claim it makes about the code cross-checked, with every
mismatch named and filed as a Documentation Engineer defect
(`ARCHITECTURAL VIOLATION` if the document contradicts an ADR still in
force; a plain documentation defect, not a violation, if it merely
lagged behind an uncontested implementation change).

### 0011 — Encapsulation Verification

**Purpose.** Prove that internal representations stay internal — distinct
from State Ownership (0004), which asks *who writes* a piece of state;
this asks whether any consumer reaches around the owning module's
accessors to read or depend on its *raw internal format* at all. Example
claim in scope: nothing outside `selection.sh` parses `SELECTED_APPS`'s
`"id|provenance"` encoding directly instead of calling
`selection_list`/`selection_contains`/`selection_provenance`; nothing
outside `catalog.sh` parses an `app.conf` file directly with `awk`/`grep`
instead of calling `app_field`.

**Verification Level(s).** Encapsulation.

**Referenced Engineering Principles.** Principle 2 (Single Authority);
Principle 4 (Stable Contracts — an internal format a consumer depends on
directly becomes a contract no one agreed to keep stable).

**Expected scope.** Repository-wide search for direct manipulation of
another module's documented-internal data shape, bypassing its accessors.

**Priority.** P0.

**Dependencies.** 0004 (you need to know who owns a piece of state before
you can check whether anyone else is reaching into it).

**Expected deliverable.** A Verification Report listing every internal
representation this project documents as owned by one module, and every
site (if any) where another module depends on that representation
directly rather than through an accessor.

### 0012 — Platform Verification

**Purpose.** Prove that engineering contracts hold across every
environment this project claims to support — not just the environment a
change happened to be written and tested in. This entry exists because of
a real, already-proven failure on this project: code that iterated
`"${array[@]}"` over a zero-element array threw "unbound variable" under
real Bash 3.2 (macOS's shipped version, and this project's documented
floor) while behaving fine on newer Bash — invisible until the exact
target platform was used, see
[architecture/0012-terminal-ui-refinement.md](../architecture/0012-terminal-ui-refinement.md).

**Verification Level(s).** Platform.

**Referenced Engineering Principles.** Principle 3 (Evidence over
Opinion); Principle 9 (Tool Independence).

**Expected scope.** Supported Bash version (3.2 floor) behavior for
array/variable-expansion edge cases used in the codebase; supported macOS
version assumptions; Homebrew behavior assumptions; filesystem
assumptions (paths, permissions, case sensitivity).

**Priority.** P0 — a platform assumption that's wrong invalidates
confidence in every other verification performed on a different platform.

**Dependencies.** None.

**Expected deliverable.** A Verification Report executed against the real
minimum-supported platform (not a newer, more permissive one), covering
at minimum every documented platform-sensitive construct.

## Program-level notes

- This list is the current, complete commitment — not a ceiling. A new
  entry is added (numbered 0013 onward, never renumbering existing
  entries) when a new subsystem or a new class of recurring defect
  justifies one, following this same template.
- An entry with no passing Verification Report is **unverified**, not
  passing by default. The absence of a report is not evidence of
  correctness (Verification Ethics #2 is about absence of *findings*
  within a performed verification — it does not excuse never performing
  one).
- Priority governs the order verifications *should* be performed in when
  resources are constrained; it does not exempt a lower-priority entry
  from ever being required before a release that touches its scope (see
  [ENGINEERING_ROLES.md](ENGINEERING_ROLES.md), Release Engineer).
