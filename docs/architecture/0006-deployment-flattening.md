# ADR-0006: Deployment Flattening

## Context

Deployment (v2.0.1–v2.1) modeled software selection as
`Profiles → Bundles → Applications`: a profile placed itself in a two-level
category/subcategory menu and composed bundles; a bundle was a reusable,
named group of application IDs; a technician picked a profile, then reviewed
each of its bundles one at a time (install all / customize / skip), then
was offered hardware recommendations as a separate screen, before a plan was
built. Storage's v2.1 Platform work established a pattern — a Platform
service with a public API, a generic pipeline, and pluggable extension
points — and this iteration ("v2.2") asked Deployment to adopt the same
philosophy: one workflow, one selection model, everything else a modifier of
that one selection.

## Problem

Three-and-a-half interaction steps (profile pick → per-bundle review loop →
hardware offer → confirmation) for what is, at the end, a single decision —
"which applications should this Mac get" — felt like navigating separate
systems rather than one workflow. Structurally: a bundle's only architectural
justification was reuse (the same group of apps referenced by several
profiles); nothing in the design ever argued bundles/profiles existed for
correctness or safety. That made them a legitimate target for removal, per
the standing instruction to eliminate concepts that survive only as
historical implementation detail rather than preserving them for
compatibility's sake.

## Decision

Collapse to `Catalog → Applications → Selected Applications → Installation
Plan → Execution`. Concretely:

- **Bundles are gone entirely** — not renamed, not kept as an internal-only
  composition primitive. A preset (`catalog/presets/<id>.preset`) is
  `NAME`/`DESCRIPTION`/`ORDER`/`APPS` — a flat list of application IDs and
  nothing else. Loading a preset, adding a hardware recommendation, and
  manually toggling an app in the Application Catalog all produce the exact
  same kind of member in one set, `SELECTED_APPS` (`core/deployment/selection.sh`),
  tagged only with *display* provenance (`preset:<id>` / `hardware` /
  `manual`) that no code branches on. There is exactly one path from
  selection to plan, `build_plan_from_selection()`.
- **Categories moved from presets to applications.** The old model used
  `CATEGORY`/`SUBCATEGORY` on profiles to build a two-level menu.
  `CATEGORIES` already existed on every application (populated on all 30 —
  a curation investment already made, never wired to anything) and now
  drives the Application Catalog browser's grouping. This is a genuinely
  different taxonomy serving a genuinely different purpose (browsing
  applications, not placing presets in a menu), not a renamed reuse of the
  same field.
- **`RECOMMENDED` deleted.** A dead field (validated, zero consumers)
  redundant with `JB_PICK`, which already means "recommended" and requires a
  justification note. Removed as part of the same "stop preserving what
  doesn't earn its keep" pass, even though it wasn't a bundle/profile
  concept.
- **The Quick Presets screen is one flat list**, not a two-level
  category/subcategory menu. Presets carry an `ORDER` for display sequence;
  there is no menu-nesting concept left to collapse.
- **Compatibility exclusion moved from deferred reporting to live filtering.**
  An application incompatible with this Mac (`ARCHS`/`MIN_MACOS`) is shown
  in the Application Catalog with its reason instead of a checkbox — never
  assigned a selection number — rather than silently entering a resolved set
  and only surfacing as a skip after the fact.

## Alternatives considered

- **A renamed, UX-invisible "Group" primitive** that presets could
  reference for DRY reuse, functionally a bundle stripped of its review/
  customize/skip UI. Seriously considered: `jb-essentials` (6 applications)
  was referenced by all 8 profiles and `productivity` (3 applications) by
  5 — real, measured reuse, not hypothetical. Rejected anyway, because the
  instruction that "a preset should contain nothing more than a list of
  application IDs" was explicit and repeated, and a disguised-bundle
  concept would violate that instruction's spirit while technically
  complying with its letter. **The cost of this decision is real and
  accepted, not hidden**: flattening put the same 6 essentials into all 8
  preset files (48 references where 14 existed before). Mitigation:
  `deployment.sh --doctor`'s new D2 advisory reports applications referenced
  by 4+ presets by name, specifically so an editor knows before changing
  `rectangle` or `keka` that the edit doesn't propagate on its own — the
  duplication is visible, not silently risky.
- **Consolidating `business`/`creative`/`education`/`engineering`/`office`
  into fewer presets** once flattening revealed that `business`, `education`,
  and `office` resolve to byte-identical `APPS` lists (all = `jb-essentials`
  + `productivity`). Declined to do unilaterally — this is a content/curation
  decision about the catalog's own domain, not an architecture decision, and
  it isn't this refactor's call to make. Left as three separate presets;
  the D2 advisory keeps the duplication visible for whoever owns that call.
- **A separate "Review Selection" screen** distinct from the confirmation
  screen. Rejected: the existing confirmation screen (`render_confirmation`
  / `run_plan_confirmation`) already is a review-then-confirm gate; adding a
  second screen before it would reintroduce an interaction step in the name
  of a requirement ("Review Screen") the existing step already satisfies.
- **A new app-to-app conflict-declaration system** for the requested
  "potential conflicts" review line. No such data exists anywhere in the
  catalog and inventing one is a new feature, explicitly out of scope this
  iteration. "Conflicts" maps to the existing compatibility-exclusion
  concept instead.

## Consequences

- Adding a preset never touches Deployment code — it's a two-field-plus-a-list
  catalog file, same "menus regenerate from data" property the old design
  already had, now without an intermediate layer to keep in sync.
- The Application Catalog browser is a single continuous, category-grouped,
  numbered list rather than a literal terminal grid — "mosaic" was treated
  as illustrative UX language; real column/grid rendering in bash 3.2 was
  judged not worth its complexity for a cosmetic gain the numbered-list
  idiom (already used everywhere else in this codebase, and already
  compatible with `parse_selection`'s range syntax) mostly delivers via
  category headers as section dividers.
- `PLAN_SKIPPED` narrows to compatibility-only skips. A technician simply
  not selecting an application is no longer a recorded "skip" — it's just
  absence from `SELECTED_APPS`. The accountability property this could seem
  to weaken ("what did the technician deliberately exclude") is restored
  differently: `render_plan_tree` (the `--tree` view) became a **preset-vs-
  final-selection diff**, computed at render time from `preset_apps(id)`
  against the frozen `PLAN_APPS`/`PLAN_MANUAL`, showing exactly what was
  kept, added, and removed relative to the loaded preset — real audit-trail
  value with no new stored plan fields.
- The vendors layer (reserved, unimplemented) now has an explicit, written
  tension: a future "vendor composing presets" is structurally a bundle
  again. Deferred, not solved — see `catalog/vendors/README.md`.

## Future implications

If a real second driver for cross-preset reuse emerges (not just the
`jb-essentials`/`productivity` case already known and accepted), revisit the
rejected "Group" primitive with that concrete need in hand — don't
resurrect it speculatively. If the vendors layer is ever designed for real,
design it consciously against the tension noted above.
