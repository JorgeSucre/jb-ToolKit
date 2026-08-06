# ADR-0010: Catalog Discoverability (v2.3.2)

## Context

By v2.3.1 the catalog had grown to 181 curated applications across 13
categories — the mandate for this iteration was explicitly *not* further
growth, but making the existing catalog easier, faster, and more enjoyable
to browse. The brief asked for search, filters, richer per-application
detail, relationship metadata (related applications, alternatives), an
optional "JB Notes" concept, and optional persona/skill-level metadata —
while explicitly freezing Deployment, Presets, Storage, and Validation's
existing shape, and explicitly asking that every proposed feature be
challenged and rejected if it adds complexity without meaningful value.

This ADR records what was built, and — more importantly, per the
Constitution's own preamble that tensions with its principles get resolved
"in the open" — what was deliberately rejected and why.

## Decisions

### Search and filters stay inside the one Application Catalog screen

`run_application_catalog` (`core/deployment/menu.sh`) already renders every
application as a flat, continuously-numbered, category-grouped toggle list.
Search (`/text`) and two filters (`p` for JB Picks, `h` for recommended-for-
this-Mac) narrow that same list in place — they do not open a new screen,
and `parse_selection`'s existing "1,3-5" numbering scheme is untouched,
just now scoped to whatever is currently visible. This was the only design
considered: a second browsing surface would have duplicated the exact
"toggle by number" mechanics the existing screen already owns, for no
benefit.

Filters are mutually exclusive (picking one clears the other) rather than
combinable. Two filters plus free-text search is already three independent
narrowing mechanisms; a combinable filter set adds state-explosion
complexity (which combination is active, how to display it) that 181 items
browsed through one flat list don't need. If the catalog someday grows
several times larger, revisit — not before.

### `RELATED` is a new, validated field; `ALTERNATIVES` stays exactly as it was

The brief asked for both "related applications" (companion tools used
together) and "alternatives" (substitutes) as browsable relationships, and
for broken references in both to be caught by validation.

`ALTERNATIVES` already existed (v2.3.0) as free text, and — checked against
its 12 real populated values — legitimately names software this catalog
does not carry at all (e.g. an App Store-only competitor). Forcing it to
validate as catalog IDs would have meant either dropping that legitimate
use or blocking it. It stays free text, unvalidated, unchanged.

`RELATED` is new: space-separated application IDs, same shape and same
validation pattern as a preset's `APPS` field (new rule **V12**, modeled
directly on the existing preset V7 check). This is deliberately
catalog-internal — "related" only makes sense pointing at something this
catalog can actually offer to install next to what the technician is
already looking at. This is the concrete reading of the brief's own
instruction to "only validate relationships that actually exist": the
catalog-internal relationship (`RELATED`) gets structural validation, the
inherently-external one (`ALTERNATIVES`) doesn't pretend to.

Most of the brief's other requested validations turned out to already
exist and needed no new code: duplicate `HOMEPAGE` is existing rule V11;
the JB Pick note requirement is existing rule V5.

`RELATED` was seeded on 10 applications (the Docker Desktop and Ollama
clusters named directly in the brief, plus their obvious neighbors:
`visual-studio-code`, `git`, `node`, `postman`, `anythingllm`, `lm-studio`,
`gpt4all`, `chatgpt`) rather than attempted across all 181. This follows
the exact precedent ADR-0009 already set for `ALTERNATIVES`/`NOTES`:
uneven, honestly-partial curation beats a forced pass that would have
meant guessing relationships for applications with no obvious pairing.

### No new "JB Notes" field

The brief's own examples for a proposed `JB_NOTES` field — Rectangle
("excellent free alternative to Magnet"), Raycast ("installed on almost
every Mac we prepare") — describe exactly what `JB_PICK` + `JB_PICK_NOTE`
already means: a specific, load-bearing claim that JB Repair stands behind
from real field experience (`CATALOG_STANDARD.md`, "What JB_PICK means
here"). A second, softer recommendation channel sitting next to it would
duplicate that meaning and invite the two to drift apart over time — the
same category of redundancy the v2.2 catalog consolidation
(`0007-catalog-consistency.md`) already removed once (`RECOMMENDED` next to
`JB_PICK`). The fix applied here is presentation, not schema: the new
detail view (`render_application_detail`, `core/deployment/render.sh`)
surfaces `JB_PICK_NOTE` prominently, labeled "Nota de JB." **No new
`JB_PICK` was added to backfill this** — Raycast, for example, is not
currently marked as a pick and was left exactly as-is, per the same
truthfulness principle ADR-0009 already applied ("writing a note claiming
operational history the author doesn't have would violate truthfulness").

### `RECOMMENDED_FOR` and `USER_LEVEL` rejected

Both were evaluated and rejected, not merely deferred.

`CATALOG_CONSTITUTION.md` §2 is pre-existing and explicit: *"Categories
describe purpose, not audience... A new user persona never requires a new
category, because personas were never what categories were tracking...
Presets, not categories, are where 'who is this for' lives."* A per-app
`RECOMMENDED_FOR` field (Students/Developers/IT Professionals/...) is
audience classification by another name — moving the exact thing §2 ruled
out for `CATEGORY` onto a new field doesn't change what it is. If "who is
this for" curation is genuinely wanted, the Constitution already names
where it belongs: a new preset, not a schema addition touched by every
future catalog entry.

`USER_LEVEL` (Beginner/Intermediate/Advanced) has the same purpose-vs-
audience problem one layer down, plus a fabrication risk this catalog has
already taken a firm position against: honestly rating 181 applications by
skill level requires judgment calls with no operational basis for most of
them, the same concern ADR-0009 raised about not fabricating `JB_PICK`
history. The discovery value didn't clear that bar.

### A dedicated JB Picks browser screen was not reintroduced

`Catalog-Format.md` already documents that a separate, read-only JB Picks
screen existed and was deliberately removed in v2.2.2: picks are
"annotated inline... wherever it appears in the Application Catalog," not a
second workflow. Re-adding it to satisfy "filter to JB Picks" would have
undone that decision. The `p` filter (above) answers the same need — "show
me only the picks" — without a second screen or a second code path.

### Fuzzy matching, license-based filtering, and install-method filtering rejected

- **Real fuzzy (edit-distance) search** — rejected. Case-insensitive
  substring match on `NAME`+`DESCRIPTION`, implemented in plain bash
  (`catalog_matches_query`, `core/deployment/catalog.sh`) already resolves
  partial names and most typos for a ~180-item list. A real fuzzy-match
  algorithm is meaningfully more code for marginal recall gain at this
  scale — revisit only if the catalog grows an order of magnitude.
- **License-based filter (Open Source/Paid/Freemium)** — rejected.
  `LICENSE` is deliberately free text (`CATALOG_STANDARD.md`: "real license
  diversity is too wide to force into a fixed list"). A clean filter would
  need either a second, parallel enum field (the exact kind of redundancy
  `PACKAGE_TYPE`/`INSTALL_METHOD` already requires a validator to keep from
  drifting) or fragile text-sniffing over free text. Not worth it for one
  filter; noted as a future opportunity only, not built.
- **Install-method filter (automatic vs. manual)** — rejected. This
  information is already visible per-app (the `⛔`/manual markers exist
  downstream at the plan stage); a dedicated filter re-slices data already
  visible rather than answering "what should I install."

### Implementation note: portability

`catalog_matches_query` is implemented with plain bash (`tr` + `[[ ==
*...* ]]`) rather than awk's `IGNORECASE`, because the system `awk` shipped
on macOS (the one true awk / BWK awk) does not support it — only gawk
does. Every other catalog accessor already uses the plain `awk -F=` pattern
that works on both; this one avoids the gawk-only feature entirely rather
than adding a dependency.

## Alternatives considered

- **A dedicated search/filter screen, separate from the Application
  Catalog.** Rejected — would duplicate `parse_selection`'s numbering
  mechanics for no benefit; see "Decisions" above.
- **Combinable filters (search + picks + hardware simultaneously).**
  Rejected for now — state-explosion complexity not justified at 181 items;
  see "Decisions" above.
- **Converting `ALTERNATIVES` to validated app IDs, matching `RELATED`.**
  Rejected — would break its legitimate existing use naming non-cataloged
  software; see "Decisions" above.

## Consequences

- `core/deployment/catalog.sh`, `menu.sh`, `render.sh` gained new functions
  (`catalog_matches_query`, V12 validation, `render_application_detail`)
  but no existing function's signature or behavior changed — every prior
  call site (Deployment CLI flags, presets, install) is untouched.
- The catalog's field count is unchanged for 171 of 181 applications; 10
  gained `RELATED`. No required field changed meaning.
- Catalog Doctor's advisories (D1/D2) are unaffected — `RELATED` isn't a
  preset reference and doesn't interact with either rule.

## Future implications

If `RELATED` population is expanded later, do it the same way `ALTERNATIVES`
already was — incrementally, only where the relationship is genuinely
obvious, never as a bulk pass that guesses pairings to hit a completeness
number. If the catalog's scale or user base ever makes a persona-shaped
feature clearly worth it, build it as a preset (or a set of presets) first,
per Constitution §2 — don't reopen `RECOMMENDED_FOR` as a per-app field
without first showing why a preset can't do the job.
