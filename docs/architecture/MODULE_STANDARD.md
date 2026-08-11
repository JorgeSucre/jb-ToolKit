# The JB Toolkit Module Standard

Status: **design proposal, not adopted.** This document defines a canonical
model for describing a module's architecture. It does not migrate any
existing module to it, does not modify `Architecture.md` or
`Deployment-Architecture.md`, and is not itself an ADR — see "Before this
becomes an ADR" at the end. Nothing in the repository changes as a result
of this document except its own existence.

## 1. Why JB Toolkit introduces the concept of a Module

Every part of this project — an orchestrator like `core/deployment.sh`, a
library file like `core/deployment/menu.sh`, a service like the Storage
Platform — already has a *responsibility* in the informal sense: a reason
it exists and a boundary around what it's allowed to touch. What has never
existed is a single, uniform, checkable **shape** for stating that
responsibility. Today, three different documents describe module
boundaries three different ways: a wide table with a free-text
"Explicitly NOT its job" column
([Deployment-Architecture.md](../Deployment-Architecture.md)), a one-line
summary per row ([Architecture.md](../Architecture.md)'s Subsystems
table), and prose rules keyed to when-to-do-X
([CONTRIBUTING.md](../CONTRIBUTING.md)'s "Where code belongs"). Each is
useful; none is a **contract** a verification can check mechanically
without a human re-deriving what "the architecture says" means for a
given file, from scratch, every time.

A **Module**, in this standard, is the unit that owns exactly one of these
contracts. It may be an orchestrator, a library file, or a service — the
model doesn't care about that distinction, only about the fact that
something in the codebase has a name, a reason to exist, and a boundary.
Every module in JB Toolkit — present and future — should eventually be
describable this way: `Bootstrap`, `Deployment`, `Deployment.Menu`,
`Deployment.Selection`, `Deployment.Planner`, `Deployment.Renderer`,
`Deployment.Transaction`, `Maintenance`, `Diagnostics`, `Reporting`,
`Platform`. The dot notation is deliberate: a module beneath an
orchestrator (`Deployment.Menu`) is named as a child of it, giving every
module a stable, referenceable identity that other modules' `Collaborates
With` fields can point to without ambiguity — the identity is the section
heading in this standard's format, not a new field of its own.

## 2. Why prose boundary definitions became insufficient

Three completed verifications produced the direct evidence:

- **Verification 0003 (Boundary)** found that `Deployment-Architecture.md`'s
  Menus row states, in prose, "filtering anything itself" as explicitly
  not `core/deployment/menu.sh`'s job — while the same file has
  implemented search and category/pick/hardware filtering, in production,
  since v2.3.2. The row itself was edited again for v2.4.0 and v2.4.1
  content without the contradiction being noticed, because nothing about
  a free-text table cell forces a re-check against the behavior it
  describes. A prose exclusion is unfalsifiable by construction — there is
  no atomic claim to test, only a paragraph to interpret.
- **Verification 0003** also found a claim — "Platform provides services
  only" — that turned out to correspond to **no documented text
  anywhere**. It was a reasonable-sounding architectural idea that had
  never actually been written down as a contract, so a verification
  couldn't confirm or deny it; it could only report the absence. A model
  with an explicit field for constraints makes "we have no stated
  constraint here" a visible, honest fact instead of an implicit gap
  discoverable only by grepping for a phrase and finding nothing.
- **Verification 0002 (Dependency)** found that `core/deployment.sh`
  sources `core/bootstrap/hardware.sh` — a real, active dependency — with
  no corresponding edge in `Architecture.md`'s diagram, and that
  `Deployment-Architecture.md`'s own library-file inventory for the
  Deployment library omits `doctor.sh`, which `core/deployment.sh`
  genuinely sources. Both are cases where the *set of files a module
  actually touches* had drifted from *the set of files prose says it
  touches*, undetected, because nothing enumerates the set in a form a
  diff or a grep can check against reality.

The common failure isn't that anyone wrote careless prose — every
document cited above is otherwise precise and well-maintained. It's that
**prose can't be diffed against evidence.** A checkable model has to
replace paragraphs with atomic, individually falsifiable statements before
a Verification Engineer's work stops being "interpret this paragraph and
judge" and starts being "check this specific claim against this specific
evidence."

## 3. Design Goals

Filling in the seven fields below for one real module produces that
module's **Contract** — the model is the empty shape, a Contract is what
a specific module's instance of it becomes. Everything about the model's
design serves one of five goals:

- **Replace descriptions of behavior with claims that can be checked
  against it.** Each line in a module's Contract is written to be
  provably true or false against real evidence, not judged by how
  convincingly it reads.
- **Give every module's architecture exactly one authoritative document.**
  Not a table row, a one-line summary, and a paragraph of prose in three
  separate files, each free to drift from the other two without anything
  noticing.
- **Let every Verification Level draw from the same seven fields.**
  Authority, Dependency, Boundary, and any level added later read one
  document instead of each reconstructing its own evidence from scratch,
  the way 0002 had to rebuild a dependency graph by hand.
- **Make a missing rule visible as an absence, not indistinguishable from
  a rule nobody thought to write down.** An untagged or empty field is
  itself a checkable fact, the way "Platform provides services only"
  turning out to be nowhere in the documentation should have been
  checkable, not just discoverable by accident.
- **Describe the module, not the language it happens to be implemented
  in.** The same Contract shape holds whether a module is a shell script
  today or something else tomorrow — adopting it should never require
  renegotiating the model itself.

## 4. The proposed Module model

A module's definition has seven fields. Each is a heading in the module's
section (see §5 for format); none is a Bash concept, a function name, or
a file-path requirement — the model describes an architectural unit, and
a real project fills it in with whatever facts that unit's technology
happens to produce.

```
Purpose
Responsibilities
Consumes
Produces
Collaborates With
Constraints
Defined By
```

### The atomic claim

Every list item under **Responsibilities**, **Consumes**, **Produces**,
**Collaborates With**, and **Constraints** is an **atomic claim** — one
sentence, true or false entirely on its own, without needing the rest of
the list for context. That independence is what makes it falsifiable: a
Verification Engineer checks one sentence against one piece of evidence,
the same shape Verifications 0001–0003 already used when they checked one
`grep` result against one document sentence, rather than judging whether
an entire paragraph "still sounds right."

A claim carries **at most one** Verification Level tag:

```
- <claim>  [checked by: <Verification Level>]
```

Exactly one, never several — a claim that seems to need two tags
(`checked by: Boundary, Platform`) is a sign it is really two claims that
happened to get written as one sentence, and should be split before it's
recorded. A claim with no tag is not yet covered by any verification;
that absence is meant to be visible, not silently implied.

**Claim granularity.** A claim describes an architectural *capability*,
not an implementation detail — the question to ask before splitting one
claim into several is whether the split would let a Verification Engineer
check something meaningfully different, or would only restate the same
capability once per function that happens to implement it. `Platform`
(§9) exposes twelve functions in its public namespace, but its `Produces`
field states this as one claim — "its public API" — not twelve. Every one
of those functions serves the same architectural fact a verification
actually cares about: that `Platform`'s capabilities are reached through
this namespace and nothing else. Twelve near-identical claims would not
let Dependency or Encapsulation Verification check anything the one claim
doesn't already cover; they would only make the Contract longer without
making it more falsifiable. A capability earns its own claim when
checking it needs different evidence, or a different Verification Level,
than its neighbors — not because a different function happens to
implement it.

The payoff is what a verification actually reads. Executing Boundary
Verification today means reading a table cell's prose and judging whether
it still holds. Once a module's responsibilities and constraints are
atomic claims, the same verification reads a list and checks each line —
it **consumes claims, not paragraphs.** This is the structural fix for
the Menus contradiction: "must not filter" as an atomic, tagged claim
(`- Does not narrow or filter the application list [checked by:
Boundary]`) is something a Verification Engineer greps against real code
directly; the same idea buried in a paragraph is something they have to
remember to re-read.

## 5. Every field, and why it exists

### Purpose

**Answers:** why does this module exist at all?

One or two sentences, not a list. Every other field describes a boundary;
Purpose is the only field that has to justify the module's existence in
the first place, which is exactly what stops a future contributor from
proposing a module that duplicates one that already exists — Purpose is
what gets compared first.

### Responsibilities

**Answers:** what does this module do?

A flat list of atomic, positive claims — what this module is the one
place in the system that decides or does. Nothing else. An earlier
version of this model split this field into a positive `Owns` list and a
negative `Excludes` list, on the theory that a prohibition needed its own
place next to what it was prohibiting. In practice that created two
separate mechanisms for stating what a module must *not* do — `Excludes`
here, and `Constraints` below, which was already expressing prohibitions
of its own kind. Two mechanisms for the same idea is exactly the
duplicated-semantics problem this whole model exists to remove from
architecture documentation. `Excludes` is eliminated: **Responsibilities
states only what a module does; every limit on how, or how much, it does
it belongs in Constraints, with nowhere else it's allowed to hide.**

### Consumes

**Answers:** what information may this module read?

Atomic claims naming **passive inputs** — the specific fact or data this
module needs, independent of which module, if any, supplies it: a file,
a piece of shared state, an environmental property, or a plug-in
artifact's own declared configuration. The test is not whether another
module happens to be involved, but *what question the claim answers*:
`Consumes` answers *what* is read. If the same input also crosses a
module boundary, the *which module* and *how* of that crossing is
`Collaborates With`'s job, stated as its own claim there — not folded
into this one. `Platform`'s "reads a migration profile's declared
configuration and callbacks" (§9) has no `Collaborates With` counterpart
at all, because a profile is a plug-in artifact, not an architectural
module with its own boundary; `Deployment.Menu`'s "the current Selected
Applications set" (§7) does, because Selection is a real module on the
other end of that read.

Every item here is something Authority Verification can check has exactly
one real source, and something Dependency Verification can check the
module doesn't reach past to get at that source's internals.

### Produces

**Answers:** what does this module output, and is it the sole owner of
producing it?

The mirror of Consumes. Every `Produces` claim across every module in the
system should be **unique** — the same output claimed by two modules'
`Produces` fields is, by definition, a Single Authority violation, and
checking for that becomes a matter of collecting every `Produces` list in
the repository and looking for a duplicate, not re-deriving ownership from
scratch per concept the way Verification 0001 currently has to.

A `Produces` claim is defined by architectural dependency, not by design
intent. The test is whether another module actually relies on the fact for
its own correctness — regardless of whether the module stating the claim
ever meant to expose it, and regardless of how cleanly the fact was
exposed. This covers three cases identically: an output the module was
built to provide, a dependency that emerged only because another module
started relying on something it observed, and an outright leak the
producing module never intended at all. All three are the same kind of
fact from `Produces`' point of view — something real that another module's
correctness now depends on — and the model records them the same way.

Recording such a claim states that the dependency exists; it does not
state that the dependency is sound. `Deployment.Selection`'s Selected
Applications output (§10, draft) is the concrete case: `Deployment.Planner`'s
own correctness depends on details of that output nothing ever designed as
a public contract. Leaving that dependency out of `Produces` because it was
never intended would hide precisely the kind of fact this model exists to
make visible — the same failure mode `Deployment.Menu`'s first Boundary
Verification already found once, when three real collaborators were
missing from its `Collaborates With` list for the identical reason: a real
relationship that existed in the system but nowhere in the Contract
describing it. Whether a recorded dependency represents a sound
architectural relationship or a violation is a question for the
appropriate Engineering Verification to answer, tagged accordingly — never
a judgment the Contract makes on its own by choosing what to include.

### Collaborates With

**Answers:** which other modules does this module have a structural
relationship with, and what is the nature of that relationship?

Atomic claims naming **active architectural relationships** — this module
calls into another module's functions or accessors, is called by one, or
hands off control flow to one, always with a real, checkable
`source`/call-graph edge on at least one side. Where `Consumes` names
*what* crosses a boundary, `Collaborates With` names *which module* and
*what kind* of relationship — the two are complementary readings of the
same reality where one exists, not alternatives to choose between.
`Deployment.Menu` reading the Selected Applications set is one real fact
told twice on purpose: once as data (`Consumes`, tagged for Encapsulation
— does Menu reach past the accessor into Selection's raw representation?)
and once as a relationship (`Collaborates With`, tagged for Dependency —
does a real edge to Selection exist, and only there?). Each telling
answers a different verification's question; neither can be derived from
the other's wording alone, which is why recording both is not duplication.

Named `Collaborates With` rather than `Depends On` deliberately: two
modules can have a real, legitimate architectural relationship
(Bootstrap hands off to Deployment; Bootstrap doesn't "depend on"
Deployment in the tight-coupling sense the word usually implies) and the
model needs a name broad enough to state that relationship honestly, then
qualify it. Each claim states the collaborator and the direction:

```
- <Module>: <this module sources it | is sourced by it | hands off to it |
  receives a handoff from it | reads its output | supplies its input>
  [checked by: Dependency]
```

This is the field Dependency Verification consumes directly to build the
graph it currently has to reconstruct by grepping every `source`
statement in the repository by hand.

### Constraints

**Answers:** what architectural rules limit this module?

The single home for every prohibition and every standing invariant — the
one place, per the goal stated in §3, where a module's negative space is
expressed, now that `Responsibilities` (above) is positive-only. A
Constraint is not about *scope* (what facts or decisions this module
owns — that's what a missing `Responsibilities` claim already implies)
but about *behavior*: a rule that must hold no matter what the module is
doing at a given moment. "Never reads the catalog" (the Installer,
`Deployment-Architecture.md`) is a Constraint because it isn't the
negative space of one specific thing the Installer does — it's a standing
rule about *how* the Installer is allowed to get information, full stop.
This is deliberately the field every Verification Level other than
Boundary (Dependency, State, Encapsulation, Platform, Duplication,
Complexity) has a home to report into:

```
- <constraint>  [checked by: <Boundary | Dependency | State |
  Encapsulation | Platform | Duplication | Complexity>]
```

A module with zero tagged Platform constraints doesn't mean nothing
applies — Platform Verification (entry 0012) can query every module for
constraints tagged `Platform` and treat an empty result honestly, as
"no platform-sensitive behavior claimed here," a testable statement,
rather than a silent gap the way it is today.

### Defined By

**Answers:** where is this module's definition canonical?

The file and section — or, when a module's architecture genuinely has
more than one distinct aspect, the small set of files and sections — that
are the source of truth for it. Each entry names exactly one aspect and
one document:

```
- <aspect>: <file, section>
```

Two entries must never name the same aspect — that constraint, not the
count of entries, is what keeps `Defined By` compatible with the Single
Authority principle. Single Authority means one authoritative source *per
fact*, not one document *per module*; Verification 0001 already confirmed
this pattern is legitimate, not a violation, for the catalog's own
philosophy/schema/parsing split across three separate documents.
`Defined By` simply lets a module say the same thing about itself,
instead of a single forced pointer hiding which document actually owns
which fact. Entries here carry no `[checked by: ...]` tag — every entry
is, by definition, an Authority-Verification-relevant fact, so tagging
each one identically would add no information, unlike `Constraints`,
where the tag is what varies and therefore what's worth stating.

A module whose real authority genuinely fits one document still writes
one entry — the format doesn't require more than one, it only stops
disallowing more than one.

Considered, and rejected, against two other names before settling here:

- **`Authority`** — the name used in an earlier draft of this model, and
  rejected specifically because "Authority" already names a distinct
  concept in the Engineering Verification System (Verification 0001, and
  Engineering Principle 2, Single Authority). Reusing the word as a field
  name inside a module's Contract risked a reader conflating "the
  document that defines this module" with "the full single-ownership
  property Authority Verification checks across every field" — related
  ideas, not the same one. The field only answers the narrower,
  documentary question.
- **`Canonical Definition`** — accurate, but a noun phrase, breaking the
  short verb/preposition style every other field name already uses
  (`Consumes`, `Produces`, `Collaborates With`). Correct content, weaker
  fit.
- **`Defined By`** — chosen. It states the same fact as `Canonical
  Definition` in the same terse register as the rest of the model, and
  it doesn't collide with a term the Verification System already owns.

During the transition period described in §8, `Defined By` still points
to whichever existing prose document(s) currently define a module — one
(`Deployment-Architecture.md`'s Menus row) or several
(`Deployment-Architecture.md`'s Catalog row alongside
`CATALOG_STANDARD.md`, `CATALOG_CONSTITUTION.md`, and `Catalog-Format.md`,
per §9) — until a module is actually migrated to this standard, at which
point its own section, in this file or a successor to it, becomes that
source. This field exists so a module's
own definition is itself subject to the Single Authority principle it's
trying to enforce for everything else — a `MODULE_STANDARD.md` that
didn't say where *it* is canonical would be exempting itself from its own
rule.

## 6. How Authority, Dependency, and Boundary Verification consume the model

| Verification | Primary field(s) consumed | What changes vs. today |
|---|---|---|
| Authority (0001) | `Produces`, `Defined By` | Collect every module's `Produces` list; a duplicate output claim across two modules is a mechanical find, not a manual cross-reference of prose documents. `Defined By` answers, for the module's own definition, the same single-owner-per-fact question `Produces` answers for each of its outputs — one authoritative document per named aspect, checked the same way a duplicate `Produces` claim would be. |
| Dependency (0002) | `Consumes`, `Collaborates With` | Build the dependency graph by reading every module's `Collaborates With` list and diffing it against the real `source`/call graph, instead of reconstructing the documented graph from a mermaid diagram plus a prose paragraph that (as 0002 found) can silently omit a real edge. |
| Boundary (0003) | `Responsibilities`, `Constraints` | Check each `Responsibilities` claim as a positive statement and each `Constraints` claim as a limiting one, both equally atomic and equally taggable — removing the earlier asymmetry, when `Excludes` existed, between a checkable positive claim and a softer, prose-shaped negative one. |

Every other current and future Verification Level (State, Encapsulation,
Duplication, Complexity, Platform) reads the `Constraints` field, filtered
by its own tag — the model is written once per module and every level
draws only the slice tagged for it, rather than each verification needing
its own bespoke source of truth.

## 7. Worked example: `Deployment.Menu`

This is illustrative only — it does not replace or amend
`Deployment-Architecture.md`'s real Menus row, and is deliberately built
from the exact facts Verification 0003 already gathered, to show
concretely what would have been different had this model existed then.

---

### Deployment.Menu

**Purpose.** The Application Catalog's interactive screen — the one place
a technician selects which applications to install, and the entry point
into the Deployment workflow itself.

**Responsibilities.**
- Rendering the Application Catalog as a responsive, column-adaptive list.
  `[checked by: Boundary]`
- Collecting technician toggle/selection input and applying it to the
  Selected Applications set via Selection's own accessors. `[checked by:
  Boundary]`
- Narrowing which applications are displayed, by name/description text
  match and by JB-Pick/hardware-recommendation filter modes. `[checked by:
  Boundary]`

**Consumes.**
- The current Selected Applications set, via Selection's accessors only,
  never a raw internal representation. `[checked by: Encapsulation]`
- Catalog application and category data, via Catalog's accessors only.
  `[checked by: Encapsulation]`
- The real terminal width, at render time. `[checked by: Platform]`

**Produces.**
- Updates to the Selected Applications set (via Selection, not a
  representation Menu owns itself).
- The rendered Application Catalog screen.

**Collaborates With.**
- `Deployment.Selection`: reads and mutates the selection exclusively
  through its accessors. `[checked by: Dependency]`
- `Deployment.Catalog`: reads application/category data exclusively
  through its accessors. `[checked by: Dependency]`
- `Bootstrap`: its entry point is sourced and called from Bootstrap's
  onboarding wizard, Bootstrap-initiated; Menu also calls directly into
  Bootstrap-namespaced files itself — `detect_machine_family`
  (`core/bootstrap/hardware.sh`), for hardware-family detection, and
  `print_section` (`core/bootstrap/ui.sh`), for screen headers. The
  relationship is real in both directions. `[checked by: Dependency]`
- `Deployment.Planner`: calls `build_plan_from_selection` directly to
  build a plan from the current selection. `[checked by: Dependency]`
- `Deployment.Confirm`: calls `run_plan_confirmation` directly to hand off
  to the confirmation screen. `[checked by: Dependency]`
- `Deployment.Renderer`: calls `render_application_detail` directly to
  show the Application View for a chosen item. `[checked by: Dependency]`

**Constraints.**
- Must not filter or narrow the *Selected Applications set itself* — only
  the *displayed* list; a technician's actual selection is never silently
  affected by an active search or filter. `[checked by: Boundary]`
- Must not independently determine application compatibility — reads the
  determination from Selection only, and never recomputes it. `[checked
  by: Boundary]`
- Must not classify Selected Applications into automatic/manual install
  tracks — that determination belongs to the Planner alone. (Distinct from
  Selection's own `manual` *provenance* tag, recorded when an application
  is toggled here — provenance states how an application entered the
  Selected Applications set, never which install track it belongs to; the
  two concepts share a word, not a meaning.) `[checked by: Boundary]`
- Must not hardcode a catalog-derived name (preset, category, or
  application) anywhere in its rendering logic — every label is read from
  catalog data. `[checked by: Boundary]`
- Numbering shown to the technician must remain stable within a single
  render — filter/search state may change what's numbered, but never
  while a number is on screen awaiting input. `[checked by: Boundary]`
- Column layout must degrade to a single column without relying on any
  non-POSIX terminal capability. `[checked by: Platform]`

**Defined By.** `docs/Deployment-Architecture.md`, "Layer responsibilities"
table, Menus row (current, prose form) — pending migration to this
standard.

---

This resolves Verification 0003's finding directly, and shows why the
`Responsibilities`/`Constraints` split in §5 is the mechanism that does
it, not just a naming preference. The old prose said, flatly, that
filtering was not Menu's job — contradicted by real code since v2.3.2,
because a single sentence had to carry both "this module filters" and
"this module must not overstep while filtering" and could only state one
without looking self-contradictory. The Contract instead states filtering
as a genuine, current **Responsibility**, because it is one, and states
the actual boundary — never touching the underlying *selection*, only
what's *displayed* — as a **Constraint**. Both are true at once, and both
now have separate, dedicated places to be written down honestly.

## 8. Before this becomes an ADR

This document is a design proposal. Before the Engineering Architect role
could reasonably propose adopting it (which would itself require an ADR,
per [architecture/README.md](README.md)'s own "when to create one"
criteria — this changes a documentation contract every module is measured
against, squarely in scope):

- ~~At least one more module with a meaningfully different shape than
  `Deployment.Menu` (a pure-data module like `Deployment.Catalog`, and a
  service-shaped one like `Platform`) should be worked through by hand~~ —
  **done, see §9.** Both fit; both also surfaced a real tension in the
  `Defined By` field's original "one line" framing — recorded in §9 at
  the time, and since resolved in §5's field definition (both §9 entries
  now use the corrected format).
- A Verification Engineer should attempt to actually execute Authority,
  Dependency, or Boundary Verification against a hand-written module
  entry, to test whether "checked by" tags are sufficient in practice or
  whether the claim format needs revision before real adoption.
- A decision is needed on whether adoption is repository-wide-at-once or
  incremental per module (this document takes no position on that
  question — it is explicitly out of scope here).

The second and third bullets above are not performed by this document.

## 9. Validation: `Deployment.Catalog` and `Platform`

**Status: validation examples, not canonical.** Unlike §7's
`Deployment.Menu`, which is offered as *the* illustrative example this
standard teaches from, the two Contracts below exist only to pressure-test
whether the model generalizes to shapes meaningfully different from a
menu screen — a pure-data module and a service module. They do not
replace, amend, or migrate `Deployment-Architecture.md` or
`Storage-Architecture.md`. Findings from writing them are recorded after
each, and summarized in the accompanying Engineering Report rather than
folded silently into §§3–6.

---

### Deployment.Catalog

**Purpose.** The single authoritative source of application and preset
data — the only place a package identifier exists, and the only code
allowed to read `catalog/` directly.

**Responsibilities.**
- Parses and serves application and preset facts from `catalog/` through
  a fixed set of accessor functions. `[checked by: Boundary]`
- Provides category-based browsing queries, one application in exactly
  one category. `[checked by: Boundary]`
- Provides hardware-recommendation and text-search matching over the
  application set. `[checked by: Boundary]`
- Validates the catalog against its complete rule set on demand, naming
  every violation found. `[checked by: Boundary]`

**Consumes.**
- `catalog/applications/*/app.conf`, resolved by directory name only —
  never by globbing for `.conf` files across the tree.
- `catalog/presets.conf`.

**Produces.**
- Parsed application/preset data, through its accessors — no other
  module in the system reads these files directly.
- Validation results: pass, or every violation named with its rule
  number and file.

**Collaborates With.**
- `Deployment.Selection`: supplies the application/preset/compatibility
  data Selection's accessors are built on. `[checked by: Dependency]`
- `Deployment.Planner`: supplies the install-method and package data the
  Planner classifies by. `[checked by: Dependency]`
- `Deployment.Menu`, `Deployment.Renderer`: supply the display facts
  (name, category, description, badges) they render. `[checked by:
  Dependency]`
- `Bootstrap`: is sourced by `core/bootstrap.sh` directly, so the
  onboarding wizard shares the same catalog. `[checked by: Dependency]`

**Constraints.**
- A package identifier may exist in exactly one application, per install
  method. `[checked by: Authority]`
- Every application owns exactly one category. `[checked by: Authority]`
- Must never decide what should be installed — that determination belongs
  to Selection and the Planner. `[checked by: Boundary]`
- Must remain parseable by one consistent flat-file pattern — no
  structured-data-format dependency. `[checked by: Platform]`

**Defined By.**
- Philosophy — *why* the schema looks like this: `docs/CATALOG_CONSTITUTION.md`.
- Schema — *what* fields mean: `docs/CATALOG_STANDARD.md`.
- Parsing and validation — *how* it's read and checked: `docs/Catalog-Format.md`.
- Role within the Deployment pipeline specifically:
  `docs/Deployment-Architecture.md`, Catalog row.

Four documents, one per aspect, none overlapping — already confirmed
legitimate, not a violation, by Verification 0001. This is the exact case
that prompted `Defined By`'s own definition (§5) to explicitly allow more
than one entry rather than force an artificial single pointer here.

---

### Platform

**Purpose.** Genuinely reusable infrastructure for bringing an external
volume under managed storage and moving data onto it safely, through one
generic pipeline any future consumer can reuse without re-deriving
migration safety from scratch.

**Responsibilities.**
- Discovers, adopts, and tracks external volumes as managed storage,
  owning the metadata directory recorded on each one. `[checked by:
  Boundary]`
- Runs one generic scan → plan → execute → verify → rollback → commit
  pipeline for any registered migration profile. `[checked by: Boundary]`
- Exposes every capability above through exactly one namespaced public
  interface. `[checked by: Encapsulation]`
- Loads pluggable migration profiles — a declarative description plus two
  required callbacks — and drives each through the same generic pipeline
  without pipeline code needing to know a specific profile exists.
  `[checked by: Boundary]`

**Consumes.**
- Each profile's declarative description and its two required callbacks
  (where a profile's data lives; how to scan it).
- The real filesystem state of candidate and already-adopted external
  volumes.
- Explicit confirmation at every point its own pipeline defines as
  irreversible.

**Produces.**
- Its public API — the only way any other module may use it.
- The metadata directory it writes to every volume it adopts (identity,
  plans, transaction records).
- Storage Transaction records: verified outcomes of a pipeline execution,
  not estimates.

**Collaborates With.**
- `Maintenance`: is sourced by, and its public API called exclusively
  from, `core/maintenance.sh` — Maintenance initiates every real
  interaction; Platform does not know Maintenance exists. `[checked by:
  Dependency]`
- *(reserved, not yet real)* any future orchestrator that sources the
  same library and calls its public API the same way — named in
  `Architecture.md` as an intended, not-yet-exercised relationship.

**Constraints.**
- No consumer may call anything outside the public namespace directly —
  every capability is reached through it or not at all. `[checked by:
  Encapsulation]`
- A profile may prompt interactively for input its own callbacks need;
  the generic pipeline stages themselves must remain profile-agnostic and
  never require a code change to add a new profile. `[checked by:
  Boundary]`
- No irreversible action may proceed without an explicit confirmation
  gate — none may be silently skipped. `[checked by: Boundary]`

**Defined By.**
- The service contract itself: `docs/Storage-Architecture.md`.
- Why `core/platform/` exists as a layer at all:
  `docs/architecture/0001-platform-philosophy.md`.
- The decision that established this specific service:
  `docs/architecture/0002-storage-platform.md`.

Same shape as `Deployment.Catalog`'s entry, arrived at independently —
two of the two modules validated in §9 needed more than one line, which
is exactly the evidence that made §5's `Defined By` definition wrong as
originally written.

---

**A finding validated by omission, not inclusion.** Verification 0003
found that "Platform provides services only" corresponded to no
documented text anywhere, and could therefore only be reported as an
absence, not confirmed or denied. Writing `Platform`'s Contract above
required deciding whether to include that claim as a Constraint. It is
not included, because no real document states it — and Platform's own
`Constraints` list still reads as complete without it, not as though
something were missing. That is the model working as designed: an
unstated rule stays honestly absent instead of being smuggled back in
just because this exercise had a natural place to put it.

## 10. Migration draft: `Deployment.Selection`

**Status: first draft, not verified, not adopted.** ADR-0013 adopted the
Module Contract model and `Deployment.Menu`'s Contract as its first
migrated module; `Deployment.Selection` is the next migration candidate.
This Contract describes `core/deployment/selection.sh` as it exists today.
It has not yet been through the correct-then-verify cycle
`Deployment.Menu`'s Contract went through before adoption (see ADR-0013,
Context) — no Boundary Verification has been executed against it, and it
is not canonical until one has been.

---

### Deployment.Selection

**Purpose.** The single owner of the Selected Applications set — one
record per chosen application regardless of whether it entered via a
preset or a manual toggle — and of the two per-application questions
("can this be installed here," "is this already installed") every other
module needs answered identically.

**Responsibilities.**
- Owns the Selected Applications set: adds, removes, and toggles
  membership by request, with no separate representation for
  preset-sourced versus manually-toggled entries. `[checked by: Boundary]`
- Determines, for a given application, whether it is compatible with this
  machine (`ARCHS`, `MIN_MACOS`). `[checked by: Boundary]`
- Determines, for a given application, whether it is already installed.
  `Deployment.Menu` and `Deployment.Renderer` call this determination
  directly; `Deployment.Installer` computes the identical check through
  its own independent implementation, not through this module. `[checked
  by: Boundary]`
- Loads a preset's application list, replacing the current selection
  wholesale, and records every requested application that is incompatible
  with this machine instead of dropping it silently. `[checked by:
  Boundary]`

**Consumes.**
- Catalog application data (`ARCHS`, `MIN_MACOS`, `INSTALL_METHOD`,
  `PACKAGE_NAME`, `NAME`), via Catalog's accessors only. `[checked by:
  Encapsulation]`
- A preset's application list, via Catalog's preset accessors only.
  `[checked by: Encapsulation]`
- The real macOS version and processor architecture, at the time
  compatibility is determined. `[checked by: Platform]`
- The session-level Homebrew formula/cask list cache, at the time
  installed status is determined. `[checked by: Platform]`

**Produces.**
- Updates to the Selected Applications set, through its own add/remove/
  toggle functions.
- The raw Selected Applications representation and the raw preset-skip
  representation, both read directly by `Deployment.Planner` when
  freezing a plan — not through an accessor. `[checked by: Encapsulation]`
- A compatibility determination for a given application (yes/no, plus a
  Spanish-language reason when incompatible).
- An installed-status determination for a given application.

**Collaborates With.**
- `Deployment.Menu`: calls this module's toggle, count, reset,
  compatibility, installed-status, and preset-loading functions —
  membership is mutated only through toggle, which performs add/remove
  internally; Menu never calls add or remove directly, and never touches a
  raw representation. `[checked by: Dependency]`
- `Deployment.Renderer`: calls the membership, installed-status, and
  compatibility functions directly, for the same reasons Menu does.
  `[checked by: Dependency]`
- `Deployment.Planner`: reads the raw Selected Applications and preset-skip
  representations directly, not through an accessor, when freezing a
  plan. `[checked by: Dependency]`
- `Deployment`: calls the preset-loading function directly, outside any
  interactive screen, when resolving a preset from the command line.
  `[checked by: Dependency]`

**Constraints.**
- An application already in the selection is never re-added on a
  duplicate add — first-occurrence provenance wins. `[checked by:
  Boundary]`
- Provenance is opaque to installation decisions — no module uses it to
  classify, filter, or select applications; `Deployment.Planner`'s
  automatic/manual classification switches on `INSTALL_METHOD` only. It is
  not opaque to every reader: `Deployment.Renderer` branches on the
  provenance value directly, to choose which human-readable label to
  display (a preset's name, or plain "manual selection"). `[checked by:
  Boundary]`
- Does not classify applications into automatic/manual install tracks or
  determine install method — membership and compatibility only; track
  classification belongs to the Planner. `[checked by: Boundary]`

**Defined By.** `docs/Deployment-Architecture.md`, "Layer responsibilities"
table, Selection row (current, prose form) — pending migration to this
standard.

---

## 11. Migration draft: `Deployment.Planner`

**Status: first draft, not verified, not adopted.** `Deployment.Menu` is
adopted (ADR-0013); `Deployment.Selection` has a first draft (§10).
`Deployment.Planner` is the next migration candidate. This Contract
describes `core/deployment/planner.sh` as it exists today, built the same
way §10 was: every field checked against real call sites, not against what
the module's own header comments say it should do. No Boundary
Verification has been executed against it; it is not canonical until one
has.

---

### Deployment.Planner

**Purpose.** The single decision-making layer between what a technician
selected and what gets installed — classifies the Selected Applications
set into automatic and manual install tracks, and freezes that
classification into an Installation Plan every downstream layer consumes
without re-deciding anything.

**Responsibilities.**
- Classifies each selected application into the automatic (`brew`/`cask`)
  or manual (`mas`/`pkg`/`dmg`/`manual`) install track, by `INSTALL_METHOD`.
  `[checked by: Boundary]`
- Counts JB Picks within the plan. `[checked by: Boundary]`
- Freezes the current Selected Applications set, and the applications a
  loaded preset wanted but that were incompatible with this machine, into
  one Installation Plan — a snapshot, not a live view of the selection.
  `[checked by: Boundary]`
- Exports the current plan to a persisted, human-readable file. `[checked
  by: Boundary]`

**Consumes.**
- The raw Selected Applications representation and the raw preset-skip
  representation, read directly, not through an accessor. `[checked by:
  Encapsulation]`
- Catalog application data (`NAME`, `INSTALL_METHOD`, `PACKAGE_NAME`,
  `DOWNLOAD_URL`, `JB_PICK`), via Catalog's accessors only. `[checked by:
  Encapsulation]`
- A preset's identity and display name, via Catalog's preset accessors
  only — used solely to label the plan, never to determine its membership.
  `[checked by: Encapsulation]`
- The real macOS version and processor architecture, at the time a plan is
  built. `[checked by: Platform]`

**Produces.**
- The Installation Plan itself: exposed as directly-read global state, not
  through accessor functions — documented in this module's own header
  comment as the contract every downstream layer consumes, and read
  directly by `Deployment.Renderer`, `Deployment.Confirm`,
  `Deployment.Installer`, `Deployment.Transaction`, and `Bootstrap` alike.
  `[checked by: Encapsulation]`
- A persisted plan file, through its own export function.
- A record of the most recent exported plan, written into the shared
  session state store. `[checked by: State]`

**Collaborates With.**
- `Deployment.Selection`: reads the raw Selected Applications and
  preset-skip representations directly, not through an accessor. `[checked
  by: Dependency]`
- `Deployment.Catalog`: reads application and preset data exclusively
  through its accessors. `[checked by: Dependency]`
- `Deployment.Menu`: is called by it to freeze the current selection into
  a plan. `[checked by: Dependency]`
- `Deployment`: is called by it directly — both to build a plan and to
  export one — when resolving a preset from the command line, outside any
  interactive screen. `[checked by: Dependency]`
- `Deployment.Renderer`: reads the plan's raw global state directly, not
  through an accessor, to render every plan-related screen. `[checked by:
  Dependency]`
- `Deployment.Confirm`: reads whether a plan is ready directly, not
  through an accessor, before showing the confirmation screen. `[checked
  by: Dependency]`
- `Deployment.Installer`: calls this module's export function directly,
  and separately reads the plan's raw global state directly, to execute
  it. `[checked by: Dependency]`
- `Deployment.Transaction`: reads the plan's raw global state directly,
  not through an accessor, when beginning a transaction. `[checked by:
  Dependency]`
- `Bootstrap`: reads one plan field directly, not through an accessor, to
  report the outcome of the deployment step after the onboarding wizard
  completes. `[checked by: Dependency]`

**Constraints.**
- Does not modify the system — builds and freezes a plan only; execution,
  transactions, and reporting happen downstream. `[checked by: Boundary]`
- Does not resolve preset membership, application bundles, or catalog
  categories — by the time the Selected Applications set is read,
  membership is already final. `[checked by: Boundary]`
- Never uses the preset identifier to re-derive plan membership — the
  Selected Applications set alone determines which applications are in the
  plan; the preset identifier is recorded only as display metadata.
  `[checked by: Boundary]`
- Provenance recorded in the plan's application records is opaque display
  text — the classification logic never branches on it. `[checked by:
  Boundary]`

**Defined By.**
- Layer boundary — what this module does and does not decide:
  `docs/Deployment-Architecture.md`, "Layer responsibilities" table,
  Planner row.
- The Installation Plan's own data contract — what each plan field means:
  `docs/Deployment-Architecture.md`, "The two contracts" §
  "Installation Plan."

Two aspects, one document, each a different section — pending migration to
this standard, the same transitional form §7's `Deployment.Menu` entry
uses.

---

**No interaction with hardware detection found.** The task that produced
this draft specifically named Hardware detection as an area warranting
attention. None was found: `core/deployment/planner.sh` never calls
`detect_machine_family` or any hardware-recommendation function, and
hardware recommendations never enter the Selected Applications set this
module reads (a design invariant stated in `selection.sh`'s own header,
carried forward here rather than re-verified). This Contract records that
absence rather than inventing a relationship to satisfy the brief.

## 12. Migration draft: `Deployment.Confirm`

**Status: first draft, not verified, not adopted.** `Deployment.Menu` is
adopted; `Deployment.Selection` and `Deployment.Planner` have completed the
correct-then-verify cycle. `Deployment.Confirm` is the next migration
candidate. This Contract describes `core/deployment/confirm.sh` (55 lines,
one function) as it exists today. No Boundary Verification has been
executed against it; it is not canonical until one has been.

---

### Deployment.Confirm

**Purpose.** The interactive review loop between a frozen Installation
Plan and actually installing it — lets a technician inspect the plan
before committing, and navigate toward an installation attempt or away
from one, without making the installation-commit decision itself.

**Responsibilities.**
- Runs the interactive review loop: renders the confirmation summary each
  iteration, and dispatches to a full plan explanation, a preset-diff
  tree, or an installation attempt, by technician choice. `[checked by:
  Boundary]`
- Keeps the review loop open after an installation attempt that was
  blocked or cancelled at the Installer's own gate, and ends it only when
  a technician backs out or an installation attempt actually ran to
  completion. `[checked by: Boundary]`

**Consumes.**
- Whether a plan is ready, read directly, not through an accessor.
  `[checked by: Encapsulation]`
- The outcome of the most recent installation attempt, read directly, not
  through an accessor. `[checked by: Encapsulation]`

**Produces.**
- No durable artifact: this module owns no state of its own, writes no
  file, and its return value is discarded by its only caller. Its only
  effect on the rest of the system is the sequence of calls it makes into
  other modules, already recorded under Collaborates With.

**Collaborates With.**
- `Deployment.Menu`: is called by it to hand off to this screen once a
  plan exists; this module does not know how the plan was built. `[checked
  by: Dependency]`
- `Deployment.Planner`: reads whether a plan is ready directly, not
  through an accessor. `[checked by: Dependency]`
- `Deployment.Renderer`: calls three distinct rendering functions
  directly — the confirmation summary, the full plan explanation, and the
  preset-diff tree — depending on technician input. `[checked by:
  Dependency]`
- `Deployment.Installer`: calls its installation entry point directly when
  the technician chooses to install; the actual go/no-go gate before any
  system change happens inside that call, not here. `[checked by:
  Dependency]`
- `Deployment.Transaction`: reads the outcome of the most recent
  installation attempt directly, not through an accessor, to decide
  whether to keep the review loop open. `[checked by: Dependency]`

**Constraints.**
- Does not own the installation-commit decision — the y/n gate before any
  system change happens inside `Deployment.Installer`'s own entry point,
  not here. `[checked by: Boundary]`
- Owns no state of its own — every fact it reads belongs to another
  module, and it writes nothing. `[checked by: State]`
- Renders only its own static control menu and input prompt directly;
  every presentation of Plan data shown from this loop — the confirmation
  summary, the full plan explanation, the preset-diff tree — is produced
  by `Deployment.Renderer`, never recomputed or reformatted here. `[checked
  by: Boundary]`

**Defined By.** `docs/Deployment-Architecture.md`, "Layer responsibilities"
table, Menus row (current, prose form — `confirm.sh` is documented jointly
with `menu.sh` there, not as its own row) — pending migration to this
standard.

---

**A name that outruns what the module owns.** The task that produced this
draft asked whether `Deployment.Confirm` owns, validates, merely presents,
or coordinates decisions. The evidence points to the last: the module
named "Confirm" does not itself confirm anything — the actual y/n gate
before any system change happens inside `Deployment.Installer`
(`run_plan_installation`'s own `ask_yes_no` call), a fact `confirm.sh`'s
own header comment already states plainly ("a y/n gate inside
`run_plan_installation` is the last stop before the system changes").
This Contract records that as architectural reality rather than assuming
the name describes the ownership.

## 13. Migration draft: `Deployment.Renderer`

**Status: first draft, not verified, not adopted.** `Deployment.Menu` is
adopted; `Deployment.Selection`, `Deployment.Planner`, and
`Deployment.Confirm` have completed the correct-then-verify cycle.
`Deployment.Renderer` is the next migration candidate. This Contract
describes `core/deployment/render.sh` (471 lines, 14 functions) as it
exists today. No Boundary Verification has been executed against it; it is
not canonical until one has been.

---

### Deployment.Renderer

**Purpose.** The single presentation layer for the Deployment pipeline —
turns Catalog, Selection, Plan, and Transaction data into every screen and
one-line summary a technician or the CLI ever sees, without resolving,
validating, or mutating anything itself.

**Responsibilities.**
- Renders the Application Catalog's per-application detail view: a status
  line with a fixed precedence (incompatible, then already-installed,
  then hardware-recommended, then available), catalog metadata, and
  related applications. `[checked by: Boundary]`
- Renders the Installation Plan in three distinct forms: a full
  explanation with per-application provenance, a concise resolution
  summary, and a diff against the plan's source preset. `[checked by:
  Boundary]`
- Renders the pre-installation confirmation summary and the
  post-installation transaction result. `[checked by: Boundary]`
- Renders one-line category and preset summaries, used by Bootstrap's
  onboarding wizard and the CLI's preset-listing output. `[checked by:
  Boundary]`

**Consumes.**
- Catalog application and preset data, via Catalog's accessors only.
  `[checked by: Encapsulation]`
- Compatibility, installed-status, and current-selection-membership
  determinations, via Selection's accessors only. `[checked by:
  Encapsulation]`
- The raw Installation Plan and raw Transaction state, read directly, not
  through an accessor. `[checked by: Encapsulation]`
- The hardware-recommended application list `Deployment.Menu` itself
  caches, read directly from Menu's own module-level variable, not
  through an accessor Menu exposes. `[checked by: Encapsulation]`
- The real machine family and external-display status, at render time.
  `[checked by: Platform]`

**Produces.**
- Every rendered screen and one-line summary named in Responsibilities —
  text output no other module relies on for its own correctness. A caller
  that composes this output into its own display line (`Deployment`'s CLI
  dispatch, Bootstrap's onboarding wizard) treats it as opaque text to
  embed, never inspecting or branching on its content.
- Derived, view-only comparisons it computes for display — a plan's diff
  against its source preset, hardware-recommended applications not in the
  current selection — recomputed fresh on every render, never stored.
  `[checked by: Boundary]`

**Collaborates With.**
- `Deployment.Catalog`: reads application and preset data exclusively
  through its accessors. `[checked by: Dependency]`
- `Deployment.Selection`: reads compatibility, installed-status, and
  selection-membership determinations exclusively through its accessors.
  `[checked by: Dependency]`
- `Deployment.Menu`: calls this module's Application Detail renderer
  directly to show one item; this module also reads Menu's own
  hardware-recommendation cache directly within that same call, not
  through an accessor. `[checked by: Dependency]`
- `Deployment.Planner`: is the source of the raw Installation Plan state
  read directly throughout this module — the explain, tree, summary, and
  confirmation renderers all read `PLAN_*` state with no accessor.
  `[checked by: Dependency]`
- `Deployment.Confirm`: calls this module's confirmation, full-explanation,
  and diff-tree renderers directly, depending on technician input.
  `[checked by: Dependency]`
- `Deployment.Installer`: calls this module's transaction-result renderer
  directly after an installation attempt. `[checked by: Dependency]`
- `Deployment.Transaction`: is the source of the raw Transaction state read
  directly by the transaction-result renderer. `[checked by: Dependency]`
- `Deployment`: calls this module's preset-summary, plan-explanation,
  plan-tree, and plan-summary renderers directly from CLI dispatch,
  outside any interactive screen. `[checked by: Dependency]`
- `Bootstrap`: calls this module's category and preset-summary renderers
  directly, from the onboarding wizard's own preset-picker screen; this
  module also calls directly into Bootstrap's hardware-detection function
  when computing hardware-recommended-but-unselected applications.
  `[checked by: Dependency]`

**Constraints.**
- Never mutates shared state — no module-owned global anywhere in the
  system is assigned from this file. `[checked by: State]`
- Never independently determines compatibility, installed status, or
  selection membership — every such fact is read from the module that
  owns it, never recomputed here. `[checked by: Boundary]`
- Never persists a derived comparison it computes for display — recomputed
  fresh on every render, never cached in shared state. `[checked by:
  Boundary]`

**Defined By.** `docs/Deployment-Architecture.md`, "Layer responsibilities"
table, Renderer row (current, prose form) — pending migration to this
standard.

---

**No interaction with the Storage Platform found.** The task that produced
this draft specifically named `Platform` as an area warranting attention.
None was found: `core/deployment/render.sh` contains no reference to
`core/platform/` anywhere. This Contract records that absence rather than
inventing a relationship to satisfy the brief.

**A raw read this Contract can name, but not fix.** `render_application_detail`
reads `$CATALOG_MENU_HW_IDS` directly — a bare module-level variable
`core/deployment/menu.sh` defines and populates for its own use (`menu.sh`'s
own comment: "cached once per `run_application_catalog` call"), not an
accessor Menu exposes. This Contract records the read on `Deployment.Renderer`'s
side, in both `Consumes` and `Collaborates With`, because it is real and
evidenced. It also means `Deployment.Menu`'s own adopted Contract (§7) —
which lists no matching `Produces` claim and no `Deployment.Renderer` entry
under `Collaborates With` — is silent about this same fact from its own
side. This task's restrictions permit recording the asymmetry; they do not
permit correcting it, since doing so would mean modifying an adopted
Module Contract.

## 14. Migration draft: `Deployment.Installer`

**Status: first draft, not verified, not adopted.** `Deployment.Menu` is
adopted; `Deployment.Selection`, `Deployment.Planner`, `Deployment.Confirm`,
and `Deployment.Renderer` have completed the correct-then-verify cycle.
`Deployment.Installer` is the next migration candidate. This Contract
describes `core/deployment/install.sh` (276 lines, 5 functions) as it
exists today. No Boundary Verification has been executed against it; it is
not canonical until one has been.

---

### Deployment.Installer

**Purpose.** Executes an already-frozen Installation Plan verbatim —
installs automatic-track packages via Homebrew, verifies manual-track
applications' presence, and records exactly what happened as an
Installation Transaction — while owning the runtime decisions of whether
to proceed and what the outcome was, decisions the Plan itself cannot make
in advance because they depend on facts only available at execution time.

**Responsibilities.**
- Executes the Plan's automatic-track packages via Homebrew, one at a
  time, with retry, never letting one package's failure stop the rest.
  `[checked by: Boundary]`
- Determines the real starting state of every plan record at execution
  time — already installed, pending, or requiring manual action —
  independently re-verified against Homebrew and the filesystem, never
  trusted from the Plan's own records. `[checked by: Boundary]`
- Gates execution behind two runtime confirmations — whether to proceed
  with the plan at all, and whether to continue past any packages found
  unavailable — deciding, at each gate, whether to record a cancellation
  and stop, or continue. `[checked by: Boundary]`
- Classifies the deployment's final outcome (success, partial, or failed)
  from the count of confirmed failures after execution completes.
  `[checked by: Boundary]`

**Consumes.**
- The raw Installation Plan state — readiness, preset identity, and both
  track lists — read directly, not through an accessor. `[checked by:
  Encapsulation]`
- The real-time Homebrew formula/cask index and installed-package list, at
  multiple points during execution. `[checked by: Platform]`
- The real filesystem state of `/Applications`, to verify manual-track
  presence. `[checked by: Platform]`

**Produces.**
- Most of the Installation Transaction's outcome content — attempted,
  installed, already-present, manual, and failed counts, their per-app
  records, and the cancellation flag — written directly into
  `Deployment.Transaction`'s own global namespace, not through any
  function that module exposes for this content. `[checked by:
  Encapsulation]`
- Real, verified changes to installed software on the machine — the sole
  owner of executing Homebrew installations derived from the Installation
  Plan. (`core/bootstrap/brew.sh` also issues `brew install` directly, for
  the Toolkit's own infrastructure — a different responsibility, installing
  outside any Plan, not a second owner of this one.) `[checked by:
  Boundary]`
- Five keys written directly into the shared session state store (deployed
  preset, last deployment timestamp, installed/manual/failed counts).
  `[checked by: State]`

**Collaborates With.**
- `Deployment.Planner`: is the source of the raw Plan state read
  throughout — readiness, preset identity, and both track lists — with no
  accessor; separately, calls its plan-export function directly, exactly
  once per invocation, at whichever of two branch points is reached —
  proceeding past the first runtime gate, or cancelling at it — before
  beginning a transaction either way. `[checked by: Dependency]`
- `Deployment.Transaction`: calls its lifecycle functions (begin, finish,
  export) to bracket a transaction, separately writes most of that
  transaction's outcome content directly into its global namespace, not
  through any function `Deployment.Transaction` exposes for that content,
  and reads one field back the same way — the transaction's end
  timestamp, to build its own state-store entry. `[checked by:
  Dependency]`
- `Deployment.Renderer`: calls its transaction-result renderer directly to
  show the outcome, once the transaction is recorded. `[checked by:
  Dependency]`
- `Deployment.Confirm`: is called by it — the only external caller of this
  module's entry point. `[checked by: Dependency]`
- `Bootstrap`: calls directly into `core/bootstrap/ui.sh` for its entire
  interactive and status-reporting surface — confirmation prompts
  (`ask_yes_no`), section headers (`print_section`), and every outcome
  message (success, warning, error, and informational) it shows the
  technician — none through an accessor. `[checked by: Dependency]`

**Constraints.**
- Never reads the catalog — every field it needs (name, install method,
  package identifier) already exists in the Plan's own records. `[checked
  by: Boundary]`
- Never decides which applications belong in the plan, and never
  reclassifies an application's install track — both are frozen by the
  time this module runs; it only determines, at execution time, whether an
  already-classified record is already satisfied, executable, or requires
  a manual step. `[checked by: Boundary]`
- Never proceeds past either runtime gate silently — a cancellation at
  either one is always recorded as a transaction outcome, never a silent
  return. `[checked by: Boundary]`

**Defined By.** `docs/Deployment-Architecture.md`, "Layer responsibilities"
table, Installer row (current, prose form) — pending migration to this
standard.

---

**No rollback capability found.** The task that produced this draft
specifically named rollback as an area warranting attention. None was
found: a package that fails to verify after an install attempt is recorded
as a named failure; nothing already installed by an earlier step in the
same run is undone. This Contract records that absence rather than
inventing a capability to satisfy the brief.

**A "no decisions" claim this Contract cannot repeat.** Both
`core/deployment/install.sh`'s own header comment ("This layer makes NO
decisions") and `Deployment-Architecture.md`'s Installer row ("Explicitly
NOT its job: Decisions of any kind") state a broader claim than the
implementation supports. The evidence is direct: `run_plan_installation`
contains two real `ask_yes_no` gates governing whether execution proceeds
at all, and a real classification of the deployment's aggregate outcome
(success, partial, or failed) computed from a failure count after
execution. Neither gate nor the outcome classification could exist earlier
in the pipeline — both depend on facts (live Homebrew availability, actual
install-command results) that do not exist until this module runs. What
the evidence does support, precisely, is narrower than "no decisions":
this module never decides *what* belongs in the plan, and never
reclassifies an application's install track — both are frozen before it
runs. This is the same shape of finding that motivated this model in the
first place (§2's Menu example: "must not filter," contradicted by real
filtering code) — a broad prose exclusion standing in for a narrower rule
that was actually true, until nobody re-checked it against the code it
described.
