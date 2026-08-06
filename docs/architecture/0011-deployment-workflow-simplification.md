# ADR-0011: Deployment Workflow Simplification (v2.4.0)

> **Amended by v2.4.1** — the `l` in-catalog preset-loading command this ADR
> introduces below was removed one release later, after real-world use
> showed technicians reached for it rarely enough that it wasn't worth the
> extra concept. See
> [0012-terminal-ui-refinement.md](0012-terminal-ui-refinement.md) for the
> reversal and its reasoning. Everything else here — the catalog-first
> entry point, advisory-only hardware recommendations, `app_already_installed`,
> the confirmation screen's four counts — is unaffected and still current.

## Context

By v2.3.2 the catalog itself — 181 applications, search, filters, rich
metadata, a detail view — was mature. This iteration's mandate was
explicitly not more catalog features but real-world *workflow* friction:
the standalone Deployment module forced a "what kind of Mac are we
preparing?" preset-picker screen before the technician ever saw an
application, hardware recommendations silently pre-selected apps into the
plan, and "already installed" was only discoverable after confirming the
plan, deep inside `install.sh`'s pre-flight. The brief asked for fewer
forced screens/decisions and earlier visibility into machine state, while
explicitly freezing the Plan/Transaction contract, Storage, Validation, and
the Catalog's own data shape, and asking that every proposed change be
challenged rather than implemented by default.

This ADR records what shipped and, per the Constitution's own preamble
practice from ADR-0010, what was deliberately rejected and why.

## Decisions

### Presets: removed as a mandatory screen, kept as an optional in-catalog command

Full removal was considered and rejected. Presets are wired into more than
the entry screen: `PLAN_PRESET_ID`/`PLAN_PRESET_NAME` drive `render_plan`
and `render_plan_tree` (the entire `--tree` "diff against the template"
view), and four CLI flags (`--resolve`/`--explain`/`--tree`/`--plan`) that
support staff and scripting depend on `require_plan` loading a named preset.
Deleting presets would have orphaned all of that for a UX win a smaller
change already achieves — and a fast, pre-curated starting set (one
keystroke instead of toggling ~12 apps one by one for a known machine
profile) is real value search alone doesn't replace.

What actually created friction was the *mandatory* screen before the
catalog, not the concept. So: `run_deployment_menu` — the standalone
Deployment module's entry — is now a one-line forward to
`start_deployment_flow ""` (empty selection, straight into the Application
Catalog), and the ~40-line preset-picker loop it used to run is deleted.
A new single-letter command inside the catalog screen, **`l`**, opens the
same flat preset list (`list_presets_ordered`/`render_preset`, unchanged)
and loads the choice via the existing, unchanged `load_preset_into_selection`
(still replace-semantics) — guarded by one `ask_yes_no` only when the
current selection is already non-empty, so the common case (load a
template as the very first action) needs no extra confirmation.

**`start_deployment_flow` keeps its `PRESET_ID` parameter.** This was a
deliberate correction mid-implementation: `core/bootstrap/wizard.sh` — a
*different* module (Bootstrap's first-run onboarding) — calls the same
function with its own preset chosen from its own "¿Cómo se usará este Mac?"
screen, which asks a legitimately different question (first-run setup
framing, not general Deployment-module friction) and was out of this
iteration's stated scope ("Deployment," not "Bootstrap"). Changing
`start_deployment_flow`'s signature or always-empty behavior would have
silently broken the wizard's own preset choice. Instead, whichever preset
was most recently loaded — via the initial parameter (wizard.sh) or via `l`
inside the catalog (standalone Deployment) — becomes the plan's identity,
tracked in one variable (`CATALOG_MENU_LOADED_PRESET`) read by
`start_deployment_flow` after the catalog screen returns. Both callers get
exactly the behavior they had before, plus the new `l` option.

`presets.conf`'s format, `catalog.sh`'s preset accessors, and all four CLI
flags are unchanged.

### Hardware recommendations: advisory only, never mutate selection

`apply_hardware_recommendations` (`selection.sh`) — which called
`selection_add(id, "hardware")` for every matching, not-yet-installed app —
is deleted outright, along with its call site. The Application Catalog
already computed `CATALOG_MENU_HW_IDS` every time it opened (added in
v2.3.2 for the `h` filter); that same set now drives a **★ badge on every
matching app, regardless of selection state**, fully decoupled from the
checkbox. The `h` filter (narrow the view to just recommendations) is
unaffected — filtering-to-look and auto-selecting are different concerns,
and only the latter was the actual complaint.

Consequence: the `hardware` provenance value can now never be produced,
since nothing sets it. Rather than leave it as dead code "just in case,"
every reference was removed: `plan_source_label`'s `hardware` case,
the selected-only "· recomendado para tu equipo ★" note in the catalog
line, and the doc mentions of a `hardware` provenance value. A technician
who manually toggles a recommended app gets ordinary `manual` provenance —
no special bookkeeping was added to remember "you followed the
recommendation," since nothing downstream would consume that fact and the
brief didn't ask for it.

### Installed vs. available: one new shared fact-check — with a hard boundary respected

New `app_already_installed ID` (`selection.sh`, next to the existing
`app_incompatibility_reason` — same "live fact-check for display" role):
dispatches on `INSTALL_METHOD` — `brew`/`cask` reuse the existing
`brew_formula_installed`/`brew_cask_installed`, which read `core/utils.sh`'s
session-level `brew list` cache (confirmed by reading it: one real `brew`
invocation total, not one per app, so calling this for all 181 apps on
every catalog redraw costs nothing extra); everything else falls back to
the same `/Applications/$NAME.app` bundle check `install.sh` already used
inline. Two call sites:

1. **Application Catalog** — a leading ✔ badge (green), decoupled from
   selection, same as the ★ badge.
2. **Plan confirmation / explain view** (`render.sh`) — a read-only preview
   computed fresh from `PLAN_APPS`+`PLAN_MANUAL` at render time, same
   "recompute, don't store" pattern `render_plan_tree` already established.
   No `PLAN_*` field was added.

**`install.sh` was deliberately left untouched — this was a mid-
implementation course correction.** The original plan called for
refactoring `_partition_plan_apps`'s inline installed-checks onto the new
shared helper too, to remove the (mild) duplication between it and the
catalog/render call sites. Re-reading `Deployment-Architecture.md` while
implementing surfaced an explicit, load-bearing invariant this would have
violated: *"the installer executes the plan verbatim and never opens the
catalog. If a future field is needed downstream, it is added to the plan —
never fetched around it."* `app_already_installed` calls `app_field`,
which is a catalog read; `_partition_plan_apps` today derives everything
it needs (`method`, `pkg`, `name`) positionally from the plan record itself
and touches the catalog **never**. Routing it through the new helper would
have made the installer catalog-aware for the first time — a real
architecture change disguised as a cleanup. The duplication between
`_partition_plan_apps` and `app_already_installed` is judged intentional,
not wasteful: it's the cost of keeping a real trust boundary (the installer
only ever trusts what the plan recorded, never what the catalog says
*now*, which could have changed since the plan was built) rather than a
sign the two should be merged.

**Rejected: a "□ Available" badge on every non-installed app.** ~150 of
181 apps are "available" at any given moment; badging the default case is
noise for zero new information.

### Catalog layout: column-grid rejected, priority sort + compact badges shipped instead

A 2/3-column grid was evaluated and rejected. Every badge in this UI is an
emoji/symbol (⭐ ★ ✔), and `printf "%-Ns"` column-padding in Bash 3.2 sizes
fields by character count, not rendered terminal width — wide/emoji glyphs
commonly render two columns wide in real terminals, so a grid built from
lines containing them risks visibly misaligned output on some terminal/font
combinations. This codebase's entire existing UI already avoids
width-dependent alignment for exactly this reason; introducing it here
would trade a real, controllable readability property for one that isn't
fully controllable, in the exact area ("clarity") the brief cared about
most. Terminal-width detection (`tput cols`) would also be new complexity
on top of that risk, for a benefit search+filter (already shipped in
v2.3.2) already covers for the "I know what I want" case.

What shipped instead — stable, low-complexity, and answers both "Catalog
Layout" and "Visual Hierarchy" with one mechanism: within each category,
apps are sorted **JB Picks, then hardware-recommended, then everything
else, alphabetical within each tier** (`_catalog_sorted_category_apps`,
`menu.sh`, using the same `"tier|name" | sort | cut` idiom
`list_presets_ordered` already established — `catalog.sh`'s
`apps_in_category` itself stays alphabetical/unchanged, since it has no
other caller). Badge text was shortened from verbose trailing phrases
(`"  · JB Pick ⭐"`) to bare leading glyphs. **Selection state is
deliberately excluded from the sort key** — re-sorting a list that changes
on every keypress would shift item numbers out from under a technician
mid-multi-select, a worse interaction than the scrolling being solved for.
For the same reason, "already installed" was also kept out of the sort key
even though it's stable per screen-open (unlike selection) — mixing two
independent sort dimensions (relevance tier and installed-state) was judged
to add more reasoning burden than the marginal scan-speed gain justified;
the ✔ badge alone satisfies the brief's stated goal for this concept
("immediate visual recognition," not necessarily repositioning).

### Search: no mechanical change

Search was already secondary by construction in v2.3.2 — category browsing
was always the default view, `/query` an opt-in command. What actually
makes plain browsing comfortable enough that search isn't *required* is the
sort/badge work above, not a change to search's own mechanics. Recorded as
a considered non-change, not a silent skip.

### Detail view: one promoted fact, nothing removed

`render_application_detail` gains a status line — installed / recommended /
incompatible / plain "available" — immediately after the category line,
before description or any static metadata. This is the single most
decision-relevant fact the screen can show ("do I even need to install
this?") and wasn't shown at all before. Every other field stays exactly as
it was: already conditional on being populated, already concise. There was
nothing to trim.

### Installation Plan: four counts instead of two

`render_confirmation` gained "se instalarán" (automatic-track apps not yet
present) and "ya instaladas" (both tracks combined), alongside the existing
manual/pick counts and a new "recomendadas sin seleccionar" line — the last
one only became meaningful once recommendations stopped auto-selecting,
since a technician can now genuinely skip a recommended app and should see
that before installing, not discover it was never offered a chance to be
seen. `render_plan` (the `[E]`/`--explain` view) gained the same
recommended-but-unselected list, named. Every number is computed fresh at
render time from `PLAN_APPS`/`PLAN_MANUAL`/`SELECTED_APPS` — no new
`PLAN_*` field, same principle `render_plan_tree`'s diff already
established (derive, don't store).

### Visual hierarchy: badges + sort + one reused color

Already-installed reuses `GREEN` from `core/utils.sh` — the same color
`success()` already uses elsewhere in this codebase, so it carries a
meaning technicians already associate with it, and it degrades to plain
text on non-TTY output via the exact same `[[ -t 1 ]]` guard every other
color already relies on. JB Pick and Recommended stay glyph-only,
uncolored, consistent with how they were already distinguished before this
release. **Rejected: a broader palette** (per-category color, dimmed rows)
— one semantic color for one concept matches the codebase's existing
minimal, meaningful use of color; several new color meanings at once is
exactly the kind of complexity growth the brief asked to reject when it
doesn't clearly pay for itself.

## Alternatives considered

- **Deleting presets outright**, including the CLI flags. Rejected — see
  "Presets" above; would have orphaned real, still-used functionality for a
  UX win a smaller change already achieves.
- **Merge semantics for `l`** (add a preset's apps to the current selection
  instead of replacing it). Considered, to avoid ever needing a
  confirmation prompt. Rejected as unnecessary complexity for a rare case:
  the common path (load a template as the first action) has nothing to
  lose either way, and reusing the existing, already-correct
  `load_preset_into_selection` with a guard is simpler than adding new
  merge-specific selection logic for the uncommon path.
- **A collapsed category-index screen** (list 13 categories with counts,
  drill into one to see its apps) as a lower-risk alternative to a
  column-grid for reducing scroll. Rejected — it would re-add exactly the
  kind of extra mandatory screen this release removed elsewhere, trading
  catalog-scroll friction for entry-screen friction.
- **Refactoring `install.sh` onto `app_already_installed`.** Rejected
  after re-reading `Deployment-Architecture.md` mid-implementation — see
  "Installed vs. available" above.

## Consequences

- `menu.sh`, `selection.sh`, `render.sh` gained new functions and lost
  `apply_hardware_recommendations` and the old preset-picker loop; net
  smaller. `install.sh`, `planner.sh`, `transaction.sh`, `catalog.sh`'s
  preset accessors, and `presets.conf` are byte-for-byte untouched.
- The Plan/Transaction contract gained zero new fields; every new
  confirmation/explain-view number is a render-time computation.
- Docs describing the flow (`Deployment-Architecture.md`,
  `Execution-Flow.md`, `Module-Overview.md`, `Architecture.md`,
  `Catalog-Format.md`) were updated to match — these are normative
  contracts in this codebase, not just prose, so letting them drift was not
  an option.

## Future implications

If a future feature wants "already installed" or "recommended" facts
inside the installer's own decision path (not just its pre-flight
partition, which already checks installed-state independently), that is
itself a Deployment-architecture decision — add the fact to the plan record
at build time, per the existing invariant, rather than having the installer
reach into the catalog. Don't let `app_already_installed`'s convenience
quietly erode the boundary this ADR just confirmed is still load-bearing.
