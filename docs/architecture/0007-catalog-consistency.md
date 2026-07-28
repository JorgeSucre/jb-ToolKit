# ADR-0007: Catalog Consistency — One Category per Application, One Presets File

## Context

v2.2 (ADR-0006) flattened Deployment to `Catalog → Applications → Selected
Applications → Installation Plan → Execution` and moved `CATEGORIES` from
presets onto applications to drive the Application Catalog browser's
grouping. That field was carried over as-is from the old model: multi-valued,
space-separated, unreviewed as a taxonomy. Real-world use of the shipped v2.2
Application Catalog screen surfaced the consequence directly — an application
with two tags (e.g. `rectangle: utilities productivity`) rendered under both
section headers, with a **different selection number in each**, so the same
app occupied two slots in a screen whose whole design assumes one slot per
application. Separately, `catalog/presets/*.preset` (one file per preset,
8 files) meant seeing "what presets exist" required opening 8 files, and nearly
identical presets (`business`/`education`/`office`) lived as three files a
reader had to diff by hand to notice were byte-identical.

This iteration is explicitly **not** a redesign. The
`Catalog → Applications → Selected Applications → Installation Plan →
Execution` flow, the one-selection-model, and the flat-preset-with-real-
duplication trade-off from ADR-0006 are all treated as correct and are
unchanged here. The scope is narrower: fix the two concrete inconsistencies
above without reintroducing any of the grouping concepts ADR-0006 removed.

## Problem

1. **Duplicate entries.** `CATEGORIES` being multi-valued directly caused the
   Application Catalog to render some applications twice, under different
   numbers — a real usability defect, not a cosmetic one, since
   `parse_selection`'s numbering is exactly what a technician types to
   toggle an app.
2. **Uncurated taxonomy.** 16 category tags had accumulated across 30
   applications with real overlap never resolved: `hardware`/`monitoring`
   were split even though `macs-fan-control` needed both; `productivity`/
   `office` were split even though both `microsoft-word` and
   `microsoft-excel` needed both; `media`/`creative` were two words for the
   same two applications (`gimp`, `kdenlive`).
3. **Preset storage doesn't scale as a set to review.** One file per preset
   makes the individual preset easy to edit but the *set of presets* hard to
   see at once — no single diff shows "a preset was added," no single view
   shows all `ORDER` values or catches near-duplicate `APPS` lists without
   manually opening every file.

## Decision

### One application, one category

`CATEGORIES` (multi-valued) becomes `CATEGORY` (exactly one value, required).
The validator enforces both presence (V2) and membership in a fixed set
(V6) — `CATALOG_CATEGORIES` in `catalog.sh` — so a typo or an unreviewed new
tag fails loudly instead of silently growing the taxonomy back to 16.
`apps_in_category()` changed from a membership scan (`for tag in
$CATEGORIES; do ... done`) to a single equality check, which is not just
simpler code — it is *structurally impossible* for an application to appear
under two section headers anymore, because there is only one field value to
match against.

**The 16 existing tags were consolidated to 8** by merging tags that split a
coherent group for no behavioral reason, and were not merged just to hit a
smaller number:

| New `CATEGORY` | Merged from | Apps |
|---|---|---|
| `development` | development, ai (for codex/antigravity — developer-facing AI coding tools) | 7 |
| `productivity` | productivity, office, ai (for chatgpt — general-purpose, not developer-specific) | 5 |
| `utilities` | utilities, android, drivers, maintenance | 6 |
| `hardware` | hardware, monitoring | 4 |
| `networking` | networking | 4 |
| `creative` | media, creative | 2 |
| `communication` | communication | 1 |
| `browsers` | browsers | 1 |

Reasoning for the two contested calls:
- **`codex`/`antigravity` → `development`, not `ai`.** Both are AI *coding*
  tools whose users are specifically developers setting up a dev machine —
  a technician outfitting a developer would look under Development, not a
  separate AI section, for their coding assistant.
- **`chatgpt` → `productivity`, not `ai`.** General-purpose, not
  developer-specific; folding it into a category any persona would check
  fits it better than a lonely one-app `ai` category next to
  `development`'s coding assistants.

**`communication` (1 app) and `browsers` (1 app) were deliberately kept
distinct rather than folded into a larger bucket.** The instruction is to
optimize for discoverability, not to hit a round category count — Discord and
Floorp are each a clear, unambiguous, single-word answer to "where would I
look for this," and merging either into an unrelated bucket (e.g.
"productivity") would make it *harder* to find, not easier, for a one-app
saving. A thin category that is still a genuinely distinct, useful
navigational bucket is not the same failure mode as the old scheme's
overlapping ones.

### One presets file

`catalog/presets/<id>.preset` (8 files) becomes `catalog/presets.conf` (1
file), one `[id]` section per preset. Inside a section, fields are the exact
same flat `KEY=value` pairs as before (`NAME`/`DESCRIPTION`/`ORDER`/`APPS`) —
no new field, no new semantics, purely a storage-location change. Section
boundaries are detected by `/^\[/` in `catalog.sh`'s `_preset_block()`; blank
lines between sections are cosmetic only.

**Rejected: YAML or JSON**, despite being the request's own suggested
examples. `docs/Catalog-Format.md`'s "Common file conventions" section is
explicit and pre-existing: *"No YAML, no JSON, no SQLite — ever. A technician
with any text editor is a first-class catalog author. Parsing must stay
implementable with the same awk pattern as `state_value`."* This is not
incidental — it is why every catalog file in this project, including
`app.conf`, is readable and *editable* by a technician with no tooling beyond
a text editor, and why the parser is 6 lines of `awk` with zero dependencies
(no `yq`, no `jq`, no `python3` in the deployment critical path — the one
place `python3` is used elsewhere, `report.sh`'s optional PDF export, is
isolated and non-essential). Introducing YAML/JSON for presets alone would
also mean **two parsing paradigms inside one catalog** — `app.conf` read one
way, `presets.conf` read another — which is its own kind of inconsistency,
directly contrary to what this iteration exists to reduce. The `[id]`-section
convention chosen instead stays inside the existing awk-parseable contract
(new section-boundary detection, same key=value line parsing) while fully
satisfying the actual goals named — one file to open, one file to diff, every
preset visible in one scroll, no per-file boilerplate.

## Alternatives considered

- **Consolidating `business`/`education`/`office`** (byte-identical `APPS`
  lists, flagged as a known tension in ADR-0006) while touching presets
  anyway. Declined again, for the same reason ADR-0006 declined it: which
  presets should exist and what they contain is a content/curation decision
  about the catalog's own domain, not an architecture decision this
  consistency pass is chartered to make. All 8 presets were migrated as-is,
  data unchanged, into the new file.
- **A category enum stored as data (a `catalog/categories.conf` list)**
  instead of a hardcoded set in `catalog.sh`. Rejected as premature
  abstraction for 8 fixed values with no runtime consumer that would ever
  need to enumerate them outside the validator itself — the same
  "duplication vs. abstraction" call Design-Principles.md principle 7 already
  makes elsewhere in this codebase. If categories become genuinely
  data-driven (technicians expected to add their own), revisit with that
  concrete need in hand.
- **Splitting `presets.conf` back into small groups of files** (e.g. one file
  per "family" of presets) as a middle ground between one-file and
  one-file-per-preset. Rejected: 8 presets in one ~50-line file is not a
  scale problem, and a second grouping concept would be exactly the kind of
  indirection layer ADR-0006 already removed once.

## Consequences

- The Application Catalog browser can no longer render a duplicate entry —
  this is now a structural guarantee (one field, one value, one equality
  check), not a discipline the catalog author has to maintain by hand.
- Adding a category is a deliberate, validated act: an unrecognized
  `CATEGORY` value fails `deployment.sh --validate` (V6) by name and file,
  the same way an unrecognized `HW_RECOMMEND` family already did.
- `catalog/presets.conf` is now the one place to review "what presets exist
  and what do they contain" — a new preset, or a change to an existing one,
  is a single, reviewable diff hunk against one file.
- `validate_preset_uniqueness` is new: one-file-per-preset made duplicate
  preset IDs structurally impossible (the filesystem enforced it); a single
  file with repeated `[id]` sections does not get that for free, so the
  validator now checks for it explicitly (V8).
- No historical concept reappeared: no Bundle, no Group, no Collection, no
  nested preset composition. Presets still reference application IDs only,
  applications still don't know their own presets, and `SELECTED_APPS`
  remains the one selection model regardless of provenance.

## Future implications

If the catalog ever grows enough applications that 8 categories stop being
discoverable (not before), revisit the taxonomy with real usage data, not
speculatively. If `presets.conf` ever grows past what fits in one comfortable
scroll (dozens of presets, not the 8 today), reconsider file splitting then,
against that concrete size — not now.
