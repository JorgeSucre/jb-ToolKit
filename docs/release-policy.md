# Release Policy

This document standardizes how JB Toolkit versions its releases, what a
release requires before it can ship, and what happens after architecture is
declared frozen. It exists so every future release follows the same bar
v2.2.2 was held to, instead of each release inventing its own process.

## Versioning strategy

JB Toolkit uses `MAJOR.MINOR.PATCH`, adapted from
[Semantic Versioning](https://semver.org/) for a Bash toolkit with no public
API contract in the library-versioning sense — "breaking change" here means
*breaking for the technician or contributor*, not an API signature.

| Segment | Bumped when | Example |
|---|---|---|
| **MAJOR** | The toolkit's shape changes for its user: a module is added, removed, or fundamentally re-scoped; a data format changes in a way existing catalog/state files don't migrate cleanly from | Not yet used past `2` — reserved for that scale of change |
| **MINOR** | An architectural change ships: a subsystem is redesigned, a data model changes shape (even if old data is migrated automatically), a concept is introduced or removed | v2.1 (Storage Platform), v2.2 (Deployment flattening), v2.3.0 (Catalog evolution), v2.4.0 (Deployment workflow simplification), v2.5.0 (Module Contract model) |
| **PATCH** | Consistency, integration, or correctness work within an already-decided architecture: fixing implementation to match documented intent, closing gaps found by real-world use, validation hardening | v2.0.1, v2.2.1 (Catalog consistency), v2.2.2 (Integration hardening) |

The single source of truth for the current version is `JB_VERSION` in
`core/utils.sh`. Every consumer — the banner, the system snapshot, `state.env`,
this document's own examples — reads that one constant. **A version bump
touches exactly one line.** If a change requires touching a version number
anywhere else, that is itself a bug (see the v2.2.2 fix to `diagnostics.sh`,
which had hardcoded a stale version string independently of `JB_VERSION`).

## Patch releases

A patch release fixes defects, closes documentation/implementation drift, or
strengthens validation — without changing what the architecture *is*. Patch
releases should be low-risk and frequent relative to minor releases. No
Architecture Freeze re-review is required for a patch release; the standing
freeze from the last minor release still applies.

## Minor releases

A minor release changes the architecture: a new subsystem, a redesigned
data model, a removed concept. Minor releases require:

- A rationale written down *before* implementation — either an explicit
  request or a measured, demonstrated need (see Design-Principles.md
  principle 7's bar for introducing an abstraction).
- At least one ADR (`docs/architecture/NNNN-*.md`) recording the decision,
  the alternatives considered, and the consequences accepted.
- A full documentation pass: every doc describing the changed subsystem
  updated in the same change, not deferred.

## Major releases

Reserved for changes that break the shape of the toolkit for its user —
none have shipped yet. A major release requires everything a minor release
requires, plus an explicit migration note for any existing installation
(catalog data, `state.env` schema, adopted Storage volumes) and a
compatibility statement in the release notes.

## Release Candidate process

Before a version is tagged, it goes through an integration/QA pass against
the already-decided architecture — not a redesign. That pass:

1. Searches the repository for historical concepts that should have been
   removed by the architecture change the release follows, and *proves*
   they're gone rather than assuming it.
2. Verifies every integration point (Selection ↔ Catalog, Hardware
   recommendations ↔ Selection, Storage discovery ↔ real hardware,
   Maintenance ↔ documented behavior) actually behaves the way its own
   documentation claims.
3. Root-causes any real-world-reported issue rather than patching its
   symptom — verified against the real condition that produced it, not
   just read and reasoned about.
4. Produces a release engineering report: issues found, root cause,
   resolution, what was deliberately left unchanged, and an explicit
   ship/no-ship recommendation.

v2.2.2 is the first release to have gone through this process in full; see
its own release engineering conversation history and
[ADR-0008](architecture/0008-integration-hardening.md) for what that looked
like in practice.

## Architecture Freeze

Once a minor release ships, its architecture is **frozen** until the next
minor release: no redesign, no new abstractions, no speculative extension.
Patch releases within a frozen architecture may only:

- Fix defects.
- Close gaps between documentation and implementation.
- Strengthen validation.
- Remove dead code or genuinely obsolete compatibility layers.
- Update documentation to stay accurate.

A patch release that finds itself needing to redesign something has found a
minor release in disguise — stop, write the rationale and the ADR, and
re-scope it as one.

## Definition of Release

A version may be tagged only when **all** of the following are true:

- Every subsystem's documentation matches its actual implementation.
- The Catalog remains the single source of truth; validation (`--validate`)
  passes with zero errors.
- One selection model exists; one application belongs to exactly one
  category; presets remain pure data (name/description/order/application
  IDs only — no execution logic, no conditions).
- No historical concept (removed in a prior minor release) has reappeared,
  confirmed by searching the repository, not by assumption.
- `bash -n` passes on every shell file; `shellcheck` reports zero errors
  (warnings are triaged, not necessarily zero).
- Every version reference in the repository matches the version being
  released.
- `CHANGELOG.md` and a `RELEASE_vX.Y.Z.md` document exist for the release.
- The git working tree is clean and ready for an annotated tag.

## Required validation

Run before every release, patch or minor:

```bash
# Syntax
for f in $(find core jb -name "*.sh" -o -name "jb"); do bash -n "$f"; done

# Static analysis
npx -y shellcheck $(find core jb -name "*.sh" -o -name "jb")

# Catalog + preset validation
bash core/deployment.sh --validate
```

Plus a functional smoke test of the Deployment pipeline (catalog validation
→ preset load → plan build → render) and, if Storage or Maintenance
behavior changed, verification against a real device where feasible — not
just a scripted fixture. The value of the v2.2.2 Storage fix came directly
from testing against an actually-attached external drive, not from code
review alone.

## Required documentation

- `CHANGELOG.md` updated with the release's entry.
- `RELEASE_vX.Y.Z.md` created for a minor or major release (patch releases
  may fold into the prior minor release's notes if the story is small,
  at the release manager's judgment).
- Any new architectural decision recorded as an ADR.
- Every document describing a changed subsystem updated in the same change
  — never left to "catch up later."

## Required testing

- Full syntax + ShellCheck + catalog validation sweep (zero errors).
- A functional walkthrough of every changed interactive flow, via manual
  sourcing with `STATE_FILE`/`JB_SESSION_LOG`/`JB_CATALOG_DIR` overridden
  (see CONTRIBUTING.md's testing discipline) — never against the real
  installation's `logs/state.env`.
- Negative-path testing for any new validation rule: a deliberately broken
  fixture must actually fail, not just a valid catalog passing.
- Confirm no test artifact leaked into the real `logs/` directory or
  `state.env` before declaring the release ready.

## Release checklist

- [ ] Repository audit: syntax, ShellCheck, catalog/preset validation, dead
      code, orphan files, TODO/FIXME markers, broken doc links.
- [ ] Version consistency: every reference matches the version being
      released; historical "as of vX" references left untouched.
- [ ] Documentation consistency: every subsystem doc matches implementation;
      historical docs remain marked historical, not silently rewritten.
- [ ] `CHANGELOG.md` updated.
- [ ] `RELEASE_vX.Y.Z.md` written (minor/major releases).
- [ ] This policy document exists and is current (create/update on the
      first release that needs it).
- [ ] Cleanup: no scratch files, temporary artifacts, or experimental code
      shipping; historical architectural documentation never removed.
- [ ] Final QA: full validation suite passes.
- [ ] Git working tree clean; release commit prepared; annotated tag
      `vX.Y.Z` prepared. Push is a separate, explicit, human-approved step —
      never automatic.
- [ ] Final architecture review: does the repository read as a finished
      product or a project mid-refactor? Any answer other than "finished"
      is itself a release blocker.
