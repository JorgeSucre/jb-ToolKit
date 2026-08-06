# ADR-0009: Catalog Evolution (v2.3.0)

## Context

By v2.2.2 the architecture — Platform, Storage, Deployment, the Catalog's
two-layer model, the one selection model, Transactions — was declared
stable and frozen. v2.3.0 was explicitly **not** another architecture
iteration: the mandate was to grow the catalog itself into a curated,
metadata-rich product, without touching Deployment, Presets, or
Transactions, and without introducing YAML, JSON, SQLite, or any new
dependency.

This ADR records the schema and taxonomy decisions from that work — the new
`docs/CATALOG_CONSTITUTION.md` and `docs/CATALOG_STANDARD.md` are the
philosophy and the reference; this is the *why* behind the specific calls
made while applying them to 121 real applications.

## Decisions

### `ID`/`PACKAGE` renamed to `APP_ID`/`PACKAGE_NAME`

The requested standard's example schema used `APP_ID` and `PACKAGE_NAME`.
Both are pure renames of existing, functionally-consumed fields — not new
concepts — so keeping the old names *and* adding the new ones as duplicate
aliases would have meant every `app.conf` carrying two fields with the
identical value, forever. That's data duplication with no purpose, and it
directly contradicts the Constitution's own §7 (one source of truth).

The rename touches a small, fixed set of Deployment call sites —
`catalog.sh`'s validator and `validate_package_uniqueness`, `planner.sh`'s
`_plan_add_app`, and `selection.sh`'s `apply_hardware_recommendations`, six
lines total — and nothing else. `install.sh` needed no change at all: it
consumes `PLAN_APPS`/`PLAN_MANUAL` records positionally, never rereads the
catalog (Deployment-Architecture.md's own invariant), so a catalog field
rename is invisible to it by construction. This is judged **not** a
Deployment redesign: the pipeline, the plan contract's shape, the selection
model, and the installer are byte-for-byte what they were in v2.2.2. Only
the string used to look up one piece of data changed — the same category of
change v2.2.1's `CATEGORIES`→`CATEGORY` rename already established as
acceptable, non-architectural catalog work.

The old names are now **hard validation errors** (V3), not silent no-ops —
the same treatment the v2.0.0 `BREW`/`CASK` keys already got, so a leftover
unmigrated line can never quietly do nothing.

### `PACKAGE_TYPE` and `ARCHITECTURE` are new, additive, and deliberately non-authoritative

Both fields were requested as metadata. Both could have been read as asking
to change what `INSTALL_METHOD`/`ARCHS` *mean* — the request's own example
showed `INSTALL_METHOD=brew` alongside a separate `PACKAGE_TYPE=cask`, which
doesn't match today's model where `INSTALL_METHOD` itself already
distinguishes `brew` from `cask`. Redefining `INSTALL_METHOD`'s values
would touch `install.sh`'s actual engine dispatch — a real Deployment
change, explicitly out of scope.

The resolution: `INSTALL_METHOD` and `ARCHS` keep their exact v2.2.2
meaning and every consumer untouched. `PACKAGE_TYPE` and `ARCHITECTURE` are
new fields that describe the same facts in a more explicit,
future-feature-friendly way, validated for internal consistency
(`PACKAGE_TYPE` must agree with `INSTALL_METHOD` — V10) but never read by
any installation-decision code. This is the Constitution's §8 "metadata
first" applied literally: the data exists for a consumer that doesn't exist
yet, without touching the consumer that does.

### Category taxonomy: 8 values → 12

`hardware` and `utilities` (v2.2.1's taxonomy) merged into a single
`system` — real-world curation of ~90 new applications made it clear both
were describing the same kind of thing (small, local, single-machine
tools), and splitting them had stopped adding navigational clarity the
moment a genuinely distinct new category (`device-management`, for
device-flashing and mobile-management tools) needed to exist alongside
them. `ai`, `media`, `security`, and `printers-scanners` are new categories
for kinds of software the v2.2.1 catalog simply didn't have examples of yet.

Three existing applications were **recategorized**, not just re-tagged:
`chatgpt`, `codex`, and `antigravity` move from `productivity`/`development`
into the new `ai` category. This directly supersedes the specific placement
ADR-0007 made for these three apps — a deliberate, explicit correction, not
an oversight. ADR-0007's own reasoning was sound at the time (an 8-category
world with no `ai` category to put them in); with `ai` now a real,
purpose-coherent category, `ai` is the correct home for all three under the
Constitution's own §2 (categories describe purpose).

### `Swifty` reclassified from Development to Security

The request's curated list placed "Swifty" under Development. Verified
against the actual Homebrew cask (`brew info --cask swifty`): it resolves
to "Swifty — Offline password manager tool," not a Swift-language
development tool. Catalogued under `security` instead, with a `NOTES` field
explaining the correction, rather than silently following the source list
into a category the application's own description contradicts. This is the
Constitution's §2 applied under pressure: category is decided by what a
tool verifiably does, not by which list it arrived in.

### No fabricated `JB_PICK`s

`JB_PICK=true` is a specific, load-bearing claim — real field experience
JB Repair is willing to stand behind (CATALOG_STANDARD.md, "What `JB_PICK`
means here"). None of the 91 newly-catalogued applications were marked as
picks. Writing a `JB_PICK_NOTE` claiming operational history the catalog
author doesn't have would violate the same truthfulness principle that
governs every success message in this codebase
(Design-Principles.md principle 1) — a fabricated recommendation is exactly
the kind of dishonest claim that principle exists to prevent, just moved
into catalog data instead of a log line. The six pre-existing picks
(`appcleaner`, `keka`, `openlogi`, `pdfgear`, `rectangle`, `stats`) are
unchanged.

### Confidence is uneven across 121 applications, and that's recorded, not hidden

Metadata for the 30 pre-existing applications and the majority of the 91
new ones was verified against the real, local Homebrew installation
(`brew info --json=v2`) — authoritative for exactly what JB Toolkit would
actually install. A minority of applications have no Homebrew cask/formula
at all (FileZilla, DaVinci Resolve, DeepSeek, NotebookLM, Authy, the
printer-vendor utilities, several others) and are catalogued as `manual`
with a homepage from general knowledge rather than a verified source; a
few of those carry an explicit `NOTES` field flagging lower confidence
(`leftovers` most notably — no confident independent source was found for
this specific application beyond the request's own list). This unevenness
is deliberately visible in the data (`NOTES`) rather than smoothed over,
consistent with "never claim more than was verified."

## Alternatives considered

- **Keeping `ID`/`PACKAGE` and adding `APP_ID`/`PACKAGE_NAME` as aliases.**
  Rejected — see "Decisions" above; pure duplication with no purpose,
  violates Constitution §7.
- **Redefining `INSTALL_METHOD` to match the request's literal example
  shape** (`brew` as a generic bucket, `PACKAGE_TYPE` doing the cask/formula
  split). Rejected — this is the one interpretation that would have
  actually touched `install.sh`'s dispatch logic, squarely inside the
  explicit "do not redesign Deployment" non-goal.
- **Enum-validating `LICENSE`.** Considered, for consistency with
  `CATEGORY`/`ARCHITECTURE`/`PACKAGE_TYPE`. Rejected: real license diversity
  (dozens of real SPDX identifiers across 121 applications) is too wide to
  force into a small fixed set without losing real information — required
  and non-empty is the right validation bar here, not enum membership.
- **Silently following the request's category placements verbatim**
  (Swifty under Development). Rejected in the one case where the verified
  facts directly contradicted the source list — see "Swifty" above.

## Consequences

- Every real Deployment call site (`deployment.sh` ×3 real invocations
  tested, `wizard.sh`, all 8 presets) was verified working, unchanged,
  against the new schema — see the release engineering report for the
  specific test evidence.
- The catalog's field count roughly doubled (11 required fields vs. 6
  before), all still flat `KEY=value`, still parsed by the same six-line
  `awk` pattern — no new parser, no new dependency.
- Catalog Doctor's D1 advisory (unreferenced-by-any-preset) now reports 91
  new entries — expected and correct: none of the new applications were
  added to any preset, per the explicit "do not redesign Presets" non-goal,
  and every one remains fully reachable through the Application Catalog
  browser regardless.

## Future implications

If a future feature actually consumes `HOMEPAGE`/`LICENSE`/`ARCHITECTURE`/
`PACKAGE_TYPE` (a catalog browser, a compliance report, an
architecture-aware filter), this data is already there — that was the
point. If `PACKAGE_TYPE` or `ARCHITECTURE` are ever promoted to actually
drive behavior, that promotion is itself a Deployment-architecture decision
and deserves its own ADR and its own scrutiny against the compatibility
guarantees `ARCHS`/`INSTALL_METHOD` currently provide — don't let a
metadata field quietly grow teeth.
