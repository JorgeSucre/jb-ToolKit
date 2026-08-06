# ADR-0012: Terminal UI & Deployment UX Refinement (v2.4.1)

## Context

By v2.4.0 the workflow was fixed: catalog-first entry, advisory-only
hardware recommendations, richer plan review. Using that workflow on
multiple real Macs surfaced that the remaining friction was purely
presentational — how the catalog looks and how much of it fits on screen —
not architectural. The mandate for this iteration was explicit: no new
features, think like a terminal UI designer, and revisit two specific prior
positions with fresh real-world evidence rather than treating them as
settled. Plan/Transaction contract, Storage, Validation, Catalog metadata,
and Presets' internal data model stayed frozen.

## Decisions

### Presets removed from the interactive UI — a deliberate reversal, not a walk-back

v2.4.0 (ADR-0011) replaced the mandatory preset-picker screen with an
optional `l` command inside the Application Catalog, reasoning that a fast
pre-curated starting set was real value worth keeping reachable. Real usage
showed the opposite in practice: "every workflow ultimately ends with
manually selecting applications from the catalog" — the loader was reached
for rarely enough that it was mostly just another concept a technician had
to learn ("what does `l` do?") for a benefit search and the priority-sorted
grid already made marginal. This is exactly the kind of thing a v2.4.0-era
ADR can't know in advance and only real use reveals — the correct response
is to say so plainly and reverse it, not to defend a decision past the
evidence that motivated it. ADR-0011 now carries a forward-pointer to this
one rather than being rewritten, same pattern already used for ADR-0006.

`_catalog_load_template` and the `l` dispatch are deleted from `menu.sh`.
`start_deployment_flow` keeps its `PRESET_ID` parameter — its only
remaining caller with a non-empty value is `core/bootstrap/wizard.sh`,
explicitly named in the brief as a legitimate preset consumer to leave
alone ("Bootstrap"). Removing the interactive loader made
`CATALOG_MENU_LOADED_PRESET` (the tracking variable `l` needed to know
which preset to label the plan with, since it could change mid-session)
unnecessary too — `start_deployment_flow` goes back to passing its own
parameter straight through, net simpler than the v2.4.0 shape, not just
smaller.

**`confirm.sh`'s `[G]` diff-view option was considered for removal as a
follow-on cut and rejected.** It's now a guaranteed no-op for every plan
built by the standalone Deployment module (no preset can be loaded
interactively there anymore, so there's never anything to diff against).
But `confirm.sh` is the same shared screen the wizard's flow reaches, and
there a preset genuinely can be loaded — a technician who picked "Developer"
in the wizard and then adjusted the selection would still want to see what
changed. Cutting `[G]` would have removed real functionality from the one
caller this brief explicitly preserves presets for. A correct, harmless
no-op for one caller and a real feature for the other is not dead code.

Consequence: the inline "· de la plantilla" provenance note in the catalog
list is also gone. Not merely because `l` disappeared, but because it was
the one variable-length element that would have complicated the fixed-width
grid (next section) — and its information is still one keystroke away in
the plan's `[E]` explain view (`plan_source_label`, unchanged), which is a
more appropriate home for provenance detail than a fast-scan grid.

### Terminal layout: a real column grid, with the alignment risk named and bounded

v2.4.0 rejected a column grid outright on the grounds that `printf`
column-padding in Bash 3.2 sizes fields by character count, not rendered
terminal width, and emoji/symbol glyphs (⭐ ★ ✔) can render one or two
terminal columns wide depending on font/terminal — a real risk of visibly
misaligned output. That risk hasn't changed; what changed is being asked to
solve it rather than avoid it. The mitigation:

- Every grid cell is built from **fixed nominal-width slots**
  (`_catalog_render_entry`, `menu.sh`): a 3-character ASCII checkbox, a
  5-character ASCII number field, a 2-character installed-slot (`✔ ` or two
  plain spaces — **never conditionally omitted**), a name field padded to a
  static 28-character cap, and two 2-character badge slots (pick,
  recommended), each space-padded when absent rather than only appended
  when present.
- This bounds the residual risk to *at most* the number of wide-rendering
  glyphs actually present on a given row (0–3 in practice, usually 0–1),
  each contributing at most one character of drift, absorbed by a 2-space
  gutter between columns. Worst realistic case (installed + pick +
  recommended all on one row — essentially never co-occurs in this catalog
  today) still only compresses the gutter; it never causes text collision.
  This is disclosed as a bounded, cosmetic, self-contained limitation, not
  hidden or claimed away.
- The 28-character name cap is a **static constant**, not a per-render scan
  of all 181 names: measured once, 173 of 181 current names fit; the one
  outlier ("IntelliJ IDEA Community Edition," 31 chars) overflows its own
  row by 3 characters and affects nothing else. Truncating names to force
  perfect alignment was rejected — hiding real information for a cosmetic
  guarantee is the wrong trade for a catalog browser.
- **Column count** comes from `tput cols` (falling back to `$COLUMNS`, then
  80), re-read on **every render**, not cached once per screen-open — a
  technician resizing their terminal mid-session sees it take effect
  immediately, which is what "responsive" should mean, not just
  "adaptive at open time." Breakpoints: `<100` → 1 column, `100–149` → 2,
  `150+` → 3 — close to the brief's own suggested 80/100–140/140+, nudged
  up because a real column (~45 characters: checkbox + number + three
  badge slots + a 28-character name + gutter) needs more room than a bare
  name to avoid looking cramped.
- **Row-major numbering** (left-to-right, top-to-bottom) rather than the
  column-major ("down then across") convention `ls -C` and most Unix
  multi-column tools use. Deliberate: technicians type ranges like `3-5`,
  and row-major keeps consecutive numbers visually adjacent, which matters
  more here than matching a convention nobody is invoking by habit in this
  screen.
- `COLS=1` is not a separate code path — it's `_catalog_print_grid` with
  one column, which naturally omits the trailing pad/gutter (the "last cell
  in a row" rule applies to every cell when there's only one per row), so
  it looks exactly like the pre-grid single-column screen.
- Incompatible (`⛔`) entries are **excluded from the grid** and printed
  full-width below it, per category. Their reason text is variable-length
  and rare; forcing it into a fixed-width cell would either truncate real
  information or reintroduce the alignment problem for the one content type
  most likely to be long. Same reasoning v2.4.0 already applied to keep
  `⛔` lines out of the priority sort tiers.

### Visual hierarchy: same glyph vocabulary, now grid-safe

No new glyph was introduced. ✔ (installed), ⭐ (JB Pick), ★ (recommended),
and the checkbox (selected) — the four signals the brief asks a technician
to recognize "without reading additional text" — were already established
in v2.4.0. The work this iteration is making them render correctly in
fixed-width slots, not inventing new visual language. Installed apps stay
fully visible and toggleable; only their badge communicates status.

### Detail view: one field cut, three collapsed into one line

`ARCHITECTURE` is removed entirely, not demoted. It's documented as purely
descriptive metadata that "never gates anything"
(`CATALOG_STANDARD.md`), reads "universal" for the overwhelming majority of
the catalog, and the one thing that *does* gate compatibility (`ARCHS`) is
already surfaced via the status line v2.4.0 added. Zero decision value for
a technician deciding whether to install something — cut, per the brief's
own "remove unnecessary information" instruction, not just reordered.

`Categoría:` / `Licencia:` / `Instalación:` — three short, single-fact
labeled lines — collapse into one compact line
(`development · MIT · Homebrew (cask)`). Same information, less vertical
space, still scannable at a glance. `Estado:` (added v2.4.0) stays first;
`REQUIREMENTS`/`NOTES` stay conditional exactly as before, since they're
genuinely rare and genuinely useful when present, not reference clutter.

### Installation Plan: glyph-led instead of label-led

`render_confirmation`'s six lines swapped their leading labels
(`"Se instalarán: %s"`) for the exact glyphs already established elsewhere
in this same session (✔ installed, ⭐ picks, ★ recommended-skipped, ✋
manual — `render_transaction` already uses ✋ for manual apps, reused here
rather than inventing a second symbol for the same concept). A technician
who has already learned the catalog's glyph vocabulary reads this screen
without learning a second one. All underlying counts
(`_plan_installed_count`, `_plan_recommended_unselected`, v2.4.0) are
reused unchanged — this is a rendering change only, no new computation.

## Alternatives considered

- **Per-category column widths** (adapt each category's column width to its
  own longest name, instead of one fixed 28-character cap catalog-wide).
  Rejected — would make categories with short names denser and categories
  with long names sparser, producing a visually inconsistent page-to-page
  look. The brief's own engineering principles state "prefer consistency
  over novelty"; one fixed width serves that better than maximal
  per-category density.
- **4+ columns for very wide terminals.** Rejected — beyond what the brief
  asked for, diminishing returns (name readability degrades well before
  most technicians' terminals reach that width), easy to add later if
  real usage ever calls for it.
- **Removing `confirm.sh`'s `[G]` option.** Rejected — see "Presets" above.
- **Truncating long names for guaranteed alignment.** Rejected — see
  "Terminal layout" above.

## Consequences

- `menu.sh` lost `_catalog_load_template`, its `l` dispatch, and
  `CATALOG_MENU_LOADED_PRESET`; gained `_catalog_terminal_columns`,
  `_catalog_render_entry`, `_catalog_print_grid`. Net smaller and simpler,
  not just different.
- `catalog.sh`, `selection.sh`, `planner.sh`, `install.sh`,
  `transaction.sh`, `presets.conf`, `wizard.sh`, and every `PLAN_*`/`TXN_*`
  field are byte-for-byte untouched.
- No new subprocess cost per application: `tput cols` is called once per
  screen render (not per app), and `app_already_installed` continues to
  reuse the existing session-level Homebrew list cache.
- Docs describing the flow were updated to match, including the mermaid
  diagrams — these are treated as normative contracts in this codebase, not
  prose, so letting them drift after an interactive-UI change was not an
  option.

## Future implications

If a future need for per-category or per-terminal-content-aware column
widths becomes real (not hypothetical), revisit the "one fixed width"
decision above with real evidence, the same way this ADR revisited
ADR-0011's `l` command — don't add that complexity speculatively. If a
4-column mode is ever wanted, `_catalog_terminal_columns`'s breakpoint table
is the only place that needs to change; the grid renderer itself is already
column-count-agnostic.
