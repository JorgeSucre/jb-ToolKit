# ADR-0008: v2.2.2 Integration Hardening

## Context

By v2.2.1 the architecture was declared stable: Platform, Storage, Catalog,
Deployment, the one selection model, and Transactions were all considered
correct. v2.2.2 was explicitly **not** another redesign — it was a
release-candidate integration pass driven by real-world usage, chartered to
make the implementation match the already-decided architecture: prove no
historical concept survived, verify every integration point actually behaves
the way the docs already claim it does, and fix root causes reported from
real hardware rather than symptoms.

This ADR records the handful of decisions from that pass that represent
lasting project philosophy, not just bug fixes — those are covered in the
release engineering report, not repeated here.

## Decisions

### 1. JB Picks is not a separate screen

The Application Catalog browser's whole design (ADR-0007) assumes one flat,
continuously numbered list. A read-only "JB Picks" menu branch — reachable
from the same menu level as real presets, but leading nowhere (no selection,
no plan, just a loop back to the menu) — was exactly the kind of "UI implies
a different execution path when none exists" pattern this iteration was
chartered to eliminate. `JB_PICK=true` is or was always **catalog data on
the application record**, not a grouping concept; the fix was to surface it
where selection already happens (inline `⭐` annotation in the Application
Catalog, regardless of selection state) instead of in a screen with its own
navigation. `list_jb_picks()` and `render_jb_pick()` are deleted — nothing
else called them once `show_jb_picks()` was gone. `JB_PICK_NOTE` reasoning
still reaches the technician the same way it always did for a selected pick:
through the plan's explain view (`PLAN_PICKS`), unchanged.

**Rejected alternative**: renaming JB Picks into an actual synthetic preset
(a 9th "preset" computed from `JB_PICK=true` apps instead of a `[id]`
section). Considered, because it would have made "choosing JB Picks" behave
literally identically to choosing any other preset. Rejected because a pick
is a **per-application** curation flag that cuts across every category and
most presets already — turning it into a preset would imply "these apps as a
*set*" when the actual value is "this app, specifically, is recommended,"
which is exactly what inline annotation communicates and a synthetic preset
would blur.

### 2. Storage volume writability is a status, not a discovery filter

`is_writable_volume()` probes by writing a file at the volume's root.
Real-world testing against an actually-attached external drive
(root:wheel-owned, ownership enforcement on — an unremarkable, common state
for a disk formatted or previously used elsewhere) reproduced the reported
"Storage Management does not detect an attached external drive" symptom
exactly: the write probe fails for a non-root technician, and
`discover_storage_volumes` silently `continue`d past it. The drive never
appeared anywhere — indistinguishable from "nothing is plugged in."

The fix generalizes the existing pattern the rest of the toolkit already
uses for exclusions (Deployment's incompatible-app handling, ADR-0006's
compatibility-exclusion philosophy): an application that can't be selected
still gets a numbered ⛔ line with a reason, never a silent gap. Now an
unwritable volume still appears in the list, tagged "⛔ Sin permisos de
escritura," with an actionable fix (Disk Utility → Ignore Ownership, or
correct the volume's permissions) if selected. `STORAGE_VOLUME_CACHE` grew a
5th field (`writable`) to carry this; every reader of the cache format was
updated in the same change (`select_storage_volume`,
`storage::get_default_volume`).

This is a two-line root cause with a real, reproducible external-drive test
behind it — not a hypothetical. See the release engineering report for the
full reproduction.

### 3. Aggressive performance optimization: confirmed intentional, made legible

`apply_aggressive_optimization` genuinely calls `apply_light_optimization`
internally — real code reuse, avoiding duplicating ~10 `defaults write`
calls between the two profiles, exactly the kind of consolidation
Design-Principles.md principle 3 already asks for. The reported "duplicate
execution" was real but narrower: the `silent` parameter that Light accepts
suppressed only its closing success line, not its opening one, so choosing
Aggressive produced two independent-looking "Applying X..." announcements
with nothing connecting them. The fix keeps the inheritance (no behavior
change to what `defaults` keys get written) and makes it legible: Light's
opening log line is now silenced too when called internally, Aggressive's
own messaging states the inheritance explicitly ("incluye la ligera + ajustes
adicionales"), and the menu label states it up front. `docs/Logging.md`
already documented this exact intent ("the aggressive profile reports the
light optimizations it includes because it genuinely applies them") before
this fix — the implementation had drifted from documentation that was
already correct, not the other way around.

### 4. Catalog validation: V9 (no duplicate keys) and closing the malformed-preset-header gap

Two silent-recovery gaps were found and closed, both structural consequences
of catalog.sh's design rather than anything new introduced by this pass:

- **Duplicate keys.** `catalog_field`/`preset_field` take the first `KEY=`
  match and never mention the rest — by design, for simplicity. But nothing
  validated that a second occurrence doesn't exist, so a duplicate `CATEGORY=`
  or `NAME=` line was a genuinely invisible inconsistency: the file looks
  wrong to a human reading it top to bottom, but the toolkit silently used
  only the first value and reported nothing. V9 checks every `app.conf` and
  every preset `[id]` section for repeated keys.
- **Malformed preset section headers.** `list_presets()` only ever matched
  well-formed kebab-case `[id]` headers — by design, so functional code
  (menus, doctor) never has to handle a malformed ID. But `validate_catalog`'s
  preset loop used the same filtered list, which meant a typo'd header
  (`[Business]`, `[my preset]`) was invisible to *everything*, including the
  validator: not listed, not validated, not reported, catalog still declared
  "válido." A new `_preset_section_headers_raw()` (every `[...]` line,
  malformed included) is what `validate_catalog` and the duplicate-section
  check (V8) now iterate over instead, so V1's "invalid preset ID" rule
  actually becomes reachable — previously it could never fire, because the
  regex that extracted candidate IDs and the regex that validated them were
  the same regex.

Both were verified against deliberately broken fixtures before and after the
fix (see the release engineering report).

### 5. `_flag_line` / `_preset_flag_line` hardened to the same "tolerant, exit 0" contract as every other accessor

Investigating whether V9's new validation code could destabilize
`validate_catalog` under `set -Eeuo pipefail` (the real `deployment.sh`'s
actual shell mode) surfaced a pre-existing, latent inconsistency unrelated to
this iteration's own changes: `_flag_line`/`_preset_flag_line` return exit 1
whenever the looked-up key is simply absent — a normal, common outcome, not
a failure — unlike `catalog_field`/`preset_field`, which are documented and
implemented as unconditionally tolerant ("missing file/key → empty, exit 0 —
safe under `set -e`"). Confirmed via isolated reproduction that this is a
real bash 3.2 `errexit` trigger in principle. **Confirmed via testing the
real entry point directly** (`bash core/deployment.sh --validate` and all
three other real call sites) that it is **not a live bug**: every real call
wraps `validate_catalog` in `if`/`if !`, and bash does not propagate errexit
through an `if` condition, so the failure mode never reaches production.
Fixed anyway, because a helper whose normal case returns a failure exit code
is a landmine for the next caller who doesn't happen to wrap it — hardening
it to always `return 0` costs two lines and removes the landmine rather than
relying on every future call site remembering to guard against it.

## What stayed unchanged, deliberately

No Bundle, Group, Collection, or nested-preset concept reappeared anywhere in
this pass — confirmed by direct repository search, not assumed (see the
report). Platform, Storage's core pipeline, the Catalog's two-layer model,
the one selection model, and Transactions were not redesigned; every change
in this iteration is a fix to an integration point or a piece of dead
weight, not a new abstraction. `catalog/vendors/` remains reserved and
untouched. The "plantilla" (template) wording for presets in the Spanish UI
was reviewed against the concern that it might imply the old rigid,
non-editable concept — kept as-is: every screen that uses it also states the
selection is reviewable and editable before installing, so the word doesn't
carry a false claim, and renaming it everywhere would be pure churn for a
stylistic preference, not a fix to an actual inconsistency.

## Future implications

`_flag_line`'s fix pattern (always return 0, let callers test the *value*,
never the accessor's own exit code) is now the contract every catalog
accessor should follow — a future accessor that returns non-zero on "value
absent" should be treated as a regression against this ADR, not a stylistic
choice. If Storage's writable-as-status pattern proves useful, the same
"never silently exclude, always show + reason" idiom should be the default
answer whenever a future eligibility check is tempted to just `continue`
past something without recording why.
