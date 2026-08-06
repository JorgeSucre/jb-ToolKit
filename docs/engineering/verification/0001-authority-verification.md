# Verification 0001: Authority Verification

**Program entry:** [VERIFICATION_PROGRAM.md #0001](../VERIFICATION_PROGRAM.md#0001--authority-verification)
**Verification Level(s):** Authority
**Date:** 2026-08-06
**Role performing this verification:** Verification Engineer (see
[ENGINEERING_ROLES.md](../ENGINEERING_ROLES.md) — role, not identity)

## Purpose

Verify that every important engineering concept in the repository has one
— and only one — authoritative definition. Answers exactly one question:
is each concept owned by exactly one authoritative source? Not duplication,
not implementation quality, not complexity — those are Verification Levels
0005 (Duplication), 0004/0011 (State/Encapsulation), and 0006 (Complexity)
respectively, and are explicitly out of scope here.

## Scope

**In scope:** authority for the concepts named in the task's Method section
(Engineering Principles, Verification, Architecture, Architecture
Decisions, Deployment, Bootstrap, Diagnostics, Maintenance, Reporting,
Catalog, State, Logging, Storage, Health Score, Hardware Detection,
Release Policy, Execution Flow, Module Responsibilities, Configuration)
plus one concrete data-level example already established as
authority-sensitive by the Program entry itself (`JB_VERSION`). Checked
across `docs/`, `docs/engineering/`, `docs/architecture/`, `core/`, and
`catalog/`.

**Explicitly not in scope, and not checked:** a full per-variable
state-ownership audit (write-site enumeration for `SELECTED_APPS`,
`PLAN_*`, `TXN_*`, `state.env` keys) — that is Program entry 0004. A full
encapsulation sweep for direct access to another module's internal data
shape — that is Program entry 0011. Code complexity or duplication —
0005/0006. This verification checked **document- and concept-level
authority**, not exhaustive code-level ownership of every internal
variable.

**Not checked at all** (no time/scope budget in this pass, not because
evidence was inconclusive): Diagnostics, Bootstrap, and Maintenance were
checked only for the existence and consistency of their authoritative
source, not for internal consistency of their full content the way
Catalog and Deployment were.

## Method

For each concept: (1) identify every file that could plausibly claim
authority over it, via `ls`/`grep` across `docs/`, `docs/engineering/`,
`docs/architecture/`, `core/`, `catalog/`; (2) where more than one
candidate file existed, read each candidate's own stated scope (its
opening paragraph, and any explicit "this document owns X, see Y for Z"
statement) to determine whether the arrangement is a documented division
of a concept into non-overlapping sub-concepts, or an undocumented
overlap; (3) grep for restatement of concept-defining facts (numeric
values, rule counts, field lists) outside the identified authoritative
file, to catch shadow/duplicate authority; (4) cross-check every
"authoritative source" claim found in `docs/README.md`'s own reading-order
table against the file it names, since that table is itself a claim about
authority. All commands and their raw output are reproduced in Evidence
below; any independent Verification Engineer can re-run the same commands
against the same revision and reach the same observations.

## Evidence

**E1.** `docs/README.md`, lines 3–4:
```
This directory is the official engineering reference for JB Toolkit. It describes the
architecture **as implemented today** (v2.3.0).
```

**E2.** `core/utils.sh`, line 9:
```
export JB_VERSION="${JB_VERSION:-2.4.1}"
```
(Single occurrence in the repository; confirmed in a prior verification
this session via `grep -rln JB_VERSION core/` returning only
`core/utils.sh` as a definition site, all other hits being consumers.)

**E3.** `docs/README.md`, line 29:
```
| [architecture/](architecture/) | Architecture Decision Records — the *why* behind the Platform layer, one topic per file, written for readers who won't read the implementation |
```

**E4.** `docs/architecture/` directory listing — 12 ADRs, topics include
`0006-deployment-flattening`, `0007-catalog-consistency`,
`0009-catalog-evolution`, `0010-catalog-discoverability`,
`0011-deployment-workflow-simplification`, `0012-terminal-ui-refinement` —
Deployment, Catalog, and Terminal UI topics, not exclusively "the Platform
layer."

**E5.** `docs/README.md` full text search: zero occurrences of
`docs/engineering` or `ENGINEERING_PRINCIPLES` or any link into
`docs/engineering/`.

**E6.** `docs/engineering/README.md`, lines 3–10, positions itself as the
entry point for "how JB Toolkit engineers itself," explicitly distinct
from and layered above `docs/*.md`.

**E7.** `docs/Catalog-Format.md`, lines 1–8:
```
This is the **normative specification** for everything under `catalog/`. [...]
If this document and a loader ever disagree, this document wins and the loader is the bug.
Design context lives in [Deployment-Design.md](Deployment-Design.md). This file is the contract.
```

**E8.** `docs/CATALOG_STANDARD.md`, lines 3–8:
```
The normative metadata schema for `catalog/applications/<id>/app.conf`, as
of v2.3.0. This document defines *what fields exist and what they mean*;
[Catalog-Format.md](Catalog-Format.md) is the complete parsing/validation
reference (file conventions, the preset format, the full V1–V11 rule table).
[CATALOG_CONSTITUTION.md](CATALOG_CONSTITUTION.md) is the philosophy behind
why the schema looks like this.
```

**E9.** `docs/CATALOG_CONSTITUTION.md`, lines 3–6: states its own scope as
philosophy, explicitly excluding file format ("not its file format, see
CATALOG_STANDARD.md").

**E10.** `grep -oE "^\| V[0-9]+ \|" docs/Catalog-Format.md | sort -u` →
`V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12` — 12 rules exist in the
actual authoritative document.

**E11.** `docs/CATALOG_STANDARD.md`, line 113 (same file as E8):
```
| `RELATED` (v2.3.2) | [...] every ID must resolve to a real catalog entry (V12) |
```
— this later line in the same file correctly cites V12; the earlier scope
statement (E8) does not.

**E12.** `grep -rn "V1–V11\|V1-V11\|V1–V12\|V1-V12" docs/` → six hits total:
`Architecture.md` (V1–V12), `Module-Overview.md` (V1–V12),
`Execution-Flow.md` (V1–V12), `Deployment-Architecture.md` (V1–V12),
`docs/engineering/VERIFICATION_PROGRAM.md` (two hits, both correctly
describing V1–V12 and, separately, using "a validator described as
'V1–V11'" as its own hypothetical example of what Documentation
Consistency Verification, entry 0010, should catch), and
`CATALOG_STANDARD.md` (the sole remaining "V1–V11", E8/line 6).

**E13.** `docs/Deployment-Design.md`, lines 1–5:
```
Status: **All five phases delivered; evolved in v2.0.1; the Profiles→Bundles
hierarchy this document describes was removed in v2.2.** This document is the
**design history** — it describes the phases as they were designed and
shipped at the time.
```
— self-flags its own historical, non-current status, and (line 29) links
to `architecture/0006-deployment-flattening.md` for what superseded it.

**E14.** `grep -rln "BASE_DIR" docs/*.md` → `CONTRIBUTING.md`,
`Future-Roadmap.md`, `Module-Overview.md`, `Reporting.md`,
`State-System.md` — five files. `grep -rln "JB_CATALOG_DIR" docs/ core/` →
`Module-Overview.md`, `release-policy.md`, `core/deployment/catalog.sh` —
three locations. `ls docs/ | grep -i config` → no matches; no file named
`Configuration.md` or equivalent exists.

**E15.** `docs/Architecture.md`, "Subsystems" table (lines 64–77): one row
per subsystem, each a short responsibility summary with an explicit
pointer to the detailed document where one exists (e.g. "see
Deployment-Architecture.md"), not a restatement of that document's
content. `docs/Module-Overview.md` operates at per-file/per-function
granularity. No numeric or contractual detail found duplicated between
the two — `Architecture.md`'s rows are summaries, not competing
definitions.

**E16.** `grep` for the actual health-score weighting values across
`docs/Architecture.md`, `Design-Principles.md`, `CONTRIBUTING.md`,
`Execution-Flow.md`, `Reporting.md`, `Module-Overview.md`,
`State-System.md`: no numeric weight or formula found outside
`docs/Health-Score.md`; `docs/README.md`'s own index entry for it is a
one-line pointer ("inputs, weights, caveats"), not a restatement.

**E17.** `docs/engineering/ENGINEERING_VERIFICATION_STANDARD.md`,
"Verification Levels" section headers, read directly:
`Authority Verification`, `Dependency Verification`, `Boundary
Verification`, `Encapsulation Verification`, `State Verification`,
`Duplication Verification`, `Complexity Verification`, `Platform
Verification` — eight, exact names. Cross-checked against every
`**Verification Level(s).**` line in `VERIFICATION_PROGRAM.md`: all citations
match these exact eight names with no invented level.

## Observations

| # | Observation | Evidence |
|---|---|---|
| 1 | `docs/README.md` describes itself as documenting the architecture "as implemented today (v2.3.0)"; the actual authoritative version is 2.4.1 | E1, E2 |
| 2 | `docs/README.md` describes `docs/architecture/` as covering "the Platform layer"; the ADR set now spans Catalog, Deployment, and Terminal UI topics as well | E3, E4 |
| 3 | `docs/README.md` contains no reference to `docs/engineering/` anywhere, despite `docs/engineering/README.md` explicitly positioning itself as sitting above `docs/*.md` | E5, E6 |
| 4 | `CATALOG_STANDARD.md`'s own scope statement cites Catalog-Format.md's rule table as "V1–V11"; the authoritative document has 12 rules, and the same file's own line 113 correctly says V12 — an internal inconsistency, not just an external one | E7–E12 |
| 5 | `Deployment-Design.md` and `Catalog-Format.md`/`CATALOG_STANDARD.md`/`CATALOG_CONSTITUTION.md` each explicitly state their own scope and defer to a named sibling document for what they don't own | E7, E8, E9, E13 |
| 6 | No document owns "Configuration" as a concept; environment-variable behavior (`BASE_DIR`, `JB_CATALOG_DIR`) is documented independently, per-consumer, in up to five separate files with no canonical cross-reference between them | E14 |
| 7 | `Architecture.md` and `Module-Overview.md` operate at genuinely different granularity (subsystem summary with pointers vs. per-file detail); no restated contractual detail found between them | E15 |
| 8 | Health Score's formula/weights are stated in exactly one file; every other mention found is a plain pointer | E16 |
| 9 | The eight Verification Levels cited throughout `VERIFICATION_PROGRAM.md` match `ENGINEERING_VERIFICATION_STANDARD.md`'s actual section headers exactly | E17 |

## Result

| Claim checked | Result |
|---|---|
| Engineering Principles has exactly one authoritative source | VERIFIED |
| Engineering Verification Standard has exactly one authoritative source | VERIFIED |
| The Verification Levels named in the Program match the Standard exactly | VERIFIED |
| `JB_VERSION` / release version has exactly one authoritative source | VERIFIED |
| `docs/README.md`'s self-description of the documented version is current | **ARCHITECTURAL VIOLATION** — the document makes an explicit factual claim about the authoritative version and that claim is false at the time of this verification (Observation 1) |
| `docs/README.md`'s description of `docs/architecture/`'s scope is current | **ARCHITECTURAL VIOLATION** — explicit scope claim no longer matches the directory's actual contents (Observation 2) |
| `docs/engineering/` is discoverable from the pre-existing root documentation index | **ARCHITECTURAL VIOLATION** — `docs/engineering/README.md` claims a structural relationship to `docs/*.md` that `docs/README.md` does not reciprocate anywhere (Observation 3) |
| Catalog authority (Constitution / Standard / Format) is a single, explicitly-partitioned, non-overlapping authority | VERIFIED WITH OBSERVATIONS |
| `CATALOG_STANDARD.md`'s reference to Catalog-Format.md's rule count is current | **ARCHITECTURAL VIOLATION** — obsolete reference to sibling authority, and internally self-contradictory (Observation 4) |
| Deployment authority (current architecture vs. design history) is a single, explicitly-partitioned authority | VERIFIED WITH OBSERVATIONS |
| Configuration (environment variables / `BASE_DIR` / `JB_CATALOG_DIR`) has a single authoritative source | **Missing authority** — no Result State in the Standard names this exactly; recorded as `ARCHITECTURAL VIOLATION` is too strong (no document contradicts another), so this is filed as an Observation-only finding (Observation 6) with no forced Result State — see Verification-System Observations below |
| Module Responsibilities (Architecture.md vs. Module-Overview.md) are non-conflicting, differently-scoped authorities | VERIFIED WITH OBSERVATIONS |
| Health Score has exactly one authoritative source | VERIFIED |
| Logging, Storage, Hardware Detection, Release Policy, Execution Flow, State each have exactly one dedicated authoritative document per `docs/README.md`'s own index, with no contradicting restatement found in the files sampled | VERIFIED WITH OBSERVATIONS (sampled, not exhaustively read line-by-line — see Scope) |
| Bootstrap, Diagnostics, Maintenance authority | NOT APPLICABLE for a dedicated-file check — these three deliberately have no dedicated file (per `docs/README.md`'s own reading-order table) and are owned jointly by `Module-Overview.md` + `Execution-Flow.md`; no competing third source found, but full content review is out of this pass's scope (see Scope) |

## Confidence

**High** for Observations 1, 2, 3, 4, 6, 9 — each is a direct textual
citation compared against another direct textual citation or a direct
`grep` count; no inference required.

**Medium** for Observations 5, 7, 8 — each concludes "no conflicting
restatement found," which is evidence of absence rather than a positive
proof; a broader grep across the full file (not just the specific
value/section checked) could not be exhaustively guaranteed within this
pass's time budget, so residual risk of an undiscovered restatement
elsewhere in a large file remains.

**Low** for the "Bootstrap, Diagnostics, Maintenance" line in Result —
this is based on directory/index-level evidence (E14-adjacent checks) and
the absence of a third competing file, not on a full read of both
documents' content for internal consistency, which was explicitly out of
scope for this pass (see Scope).

## Recommendations

Each traces directly to the Observation it follows from; none is
speculative.

1. **Update `docs/README.md`'s version claim** (Observation 1) and **its
   description of `docs/architecture/`'s scope** (Observation 2). Low
   effort, high value: both are one-line factual corrections.
2. **Add a cross-reference from `docs/README.md` to `docs/engineering/`**
   (Observation 3), so the governance layer is discoverable from both
   entry points, not only from itself.
3. **Correct `CATALOG_STANDARD.md` line 6's rule-count reference from
   "V1–V11" to "V1–V12"** (Observation 4) — the smallest possible fix,
   and the file's own line 113 already shows the correct value to copy.
4. **Consider whether Configuration warrants a dedicated authoritative
   document or an explicit "no single owner, see the following files"
   note** (Observation 6) — this is a design decision for the Engineering
   Architect role, not something this verification can resolve; it is
   presented as a candidate for a future ADR, not a mandate.

None of these four are implemented as part of this verification, per the
Restrictions in the task that produced it.

## History

| Date | Result | Note |
|---|---|---|
| 2026-08-06 | Mixed — see Result table | Initial verification |
