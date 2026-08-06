# Verification 0003 (Module Contract Validation): Boundary Verification executed against `Deployment.Selection`'s Module Contract

**Program entry:** [VERIFICATION_PROGRAM.md #0003](../VERIFICATION_PROGRAM.md#0003--boundary-verification)
**Verification Level(s):** Boundary (broadened to also check Consumes/
Produces/Collaborates With, per the pattern established for
`Deployment.Menu` and `Deployment.Planner`)
**Date:** 2026-08-06
**Role performing this verification:** Verification Engineer (see
[ENGINEERING_ROLES.md](../ENGINEERING_ROLES.md))

**Relationship to other reports.** This checks `Deployment.Selection`'s
Module Contract ([MODULE_STANDARD.md §10](../../architecture/MODULE_STANDARD.md))
against `core/deployment/selection.sh` and every real caller into it.
`Deployment-Architecture.md` and `Architecture.md` were not consulted as
architectural sources — only the Contract's own text is treated as the
standard of correctness. Every claim was checked fresh against
implementation evidence gathered in this pass; none was accepted on the
strength of having been authored carefully, or of a same-session module
(`Deployment.Planner`) having verified cleanly.

## Purpose

Determine whether every atomic claim in `Deployment.Selection`'s Module
Contract holds true against `core/deployment/selection.sh` and its real
callers — Responsibilities and Constraints as positive/limiting statements
of behavior, Consumes/Produces/Collaborates With as a check of the real
data and call-graph evidence.

## Scope

**Authoritative source:** `Deployment.Selection`'s Module Contract,
[MODULE_STANDARD.md §10](../../architecture/MODULE_STANDARD.md), verbatim,
as it reads today.

**Evidence source:** `core/deployment/selection.sh` in full (163 lines);
every external reference to its 12 functions and 2 globals
(`SELECTED_APPS`, `SELECTION_LOAD_SKIPPED`) across the repository; the full
body of every function found calling into it, read rather than assumed
from a call site alone (specifically `core/deployment/install.sh`'s
installed-status logic and `core/deployment/render.sh`'s
`plan_source_label`).

**Not checked:** `Architecture.md`, `Deployment-Architecture.md`, ADRs, or
prior Verification Reports, as architectural sources. Whether the
architecture described is good design is also out of scope — only whether
the Contract's claims are true.

## Method

1. Extracted all 19 atomic claims from `Deployment.Selection`'s Contract
   verbatim (4 Responsibilities, 4 Consumes, 4 Produces, 4 Collaborates
   With, 3 Constraints).
2. Read `core/deployment/selection.sh` in full.
3. For each of its 12 functions and 2 globals, ran `grep -rn` across
   `core/` excluding `selection.sh` itself, and read the full body of every
   file with a hit — not just the matching line — to determine whether
   each call is direct, indirect, or a duplicate reimplementation.
4. For the "checked the same way for every caller" Responsibility claim,
   specifically checked whether `core/deployment/install.sh` calls
   `app_already_installed` or implements equivalent logic independently —
   the two are not the same fact and the claim's wording depends on which
   is true.
5. For the "nothing that reads it branches control flow on its value"
   Constraint on provenance, searched the entire repository for the string
   `provenance`, not just for calls into `selection.sh`, since the claim
   is worded as a system-wide invariant, not one scoped to
   `selection.sh`'s own code.

An independent Verification Engineer re-running these steps against the
same revision would reach the same conclusions — every finding below cites
a specific file and line.

## Evidence

**Responsibilities vs. code:**
```
selection.sh:46-68   selection_add()/selection_remove()/selection_toggle()
                      — single SELECTED_APPS format regardless of provenance
selection.sh:92-115  app_incompatibility_reason() — checks ARCHS, MIN_MACOS
                      only
selection.sh:126-137 app_already_installed() — brew/cask via cache,
                      */Applications fallback
install.sh:35-36     brew_formula_installed "$pkg" / brew_cask_installed "$pkg"
                      — called directly, NOT via app_already_installed
install.sh:48        [[ -d "/Applications/$name.app" ]] — reimplemented
                      independently, NOT via app_already_installed
install.sh:242-243   the same brew/cask pattern repeated a second time,
                      also not via app_already_installed
selection.sh:146-161 load_preset_into_selection() — reset_selection() first
                      (wholesale replace), then per-app: selection_add on
                      compatible, SELECTION_LOAD_SKIPPED append on
                      incompatible — never a silent drop
```

**Consumes vs. code:**
```
selection.sh: app_field() calls found for exactly ARCHS (96), MIN_MACOS
              (105), INSTALL_METHOD (129), PACKAGE_NAME (130,131), NAME
              (133) — no other app_field key referenced in the file
selection.sh:161  preset_apps("$preset_id") — the only preset accessor
              called in this file
selection.sh:87,98,107  sw_vers -productVersion; uname -m — both inside
              app_incompatibility_reason's call chain
selection.sh:130-131,536-544(utils.sh)  brew_formula_installed/
              brew_cask_installed → _brew_ensure_list_formula/
              _brew_ensure_list_cask → grep against $_BREW_LIST_FORMULA/
              $_BREW_LIST_CASK (cached), not a fresh `brew` subprocess
```

**Produces / Collaborates With vs. real call sites:**
```
menu.sh:139   app_already_installed "$id"
menu.sh:170   selection_contains "$id"
menu.sh:207,338  selection_count
menu.sh:233   app_incompatibility_reason "$id"
menu.sh:306   selection_toggle "$id" manual   — the ONLY selection_add/
              selection_remove/selection_toggle call in menu.sh; grep for
              selection_add and selection_remove in menu.sh returns zero
              hits
menu.sh:328   load_preset_into_selection "$preset_id"
menu.sh:330   reset_selection
menu.sh: grep for SELECTED_APPS/SELECTION_LOAD_SKIPPED returns only
              comment lines (24, 26, 177) — zero executable references
render.sh:103  app_incompatibility_reason "$id"
render.sh:105,165  app_already_installed "$id"
render.sh:189  selection_contains "$id"
planner.sh:141  done <<< "$SELECTED_APPS"   — raw, no accessor
planner.sh:146  done <<< "$SELECTION_LOAD_SKIPPED"   — raw, no accessor
deployment.sh:53  load_preset_into_selection "$preset"  — inside a
              CLI-dispatch function (usage/error handling, no interactive
              read), immediately followed by build_plan_from_selection
```

**Constraint (provenance) vs. every hit for the string "provenance" repo-wide:**
```
planner.sh:84,120,138,140  provenance passed through and stored in
              PLAN_APPS/PLAN_MANUAL — never inspected in a conditional
              (only "$method" is switched on in _plan_add_app)
install.sh:32  while IFS='|' read -r id name _source method pkg — the
              provenance/source field is read into `_source` and never
              referenced again (leading underscore, unused)
render.sh:16-30  plan_source_label() — FULL BODY:
                  case "$provenance" in
                      preset:*)
                          preset_id="${provenance#preset:}"
                          if preset_exists "$preset_id"; then
                              preset_field "$preset_id" NAME
                          else
                              printf "plantilla\n"
                          fi
                          ;;
                      *) printf "selección manual\n" ;;
                  esac
              — a direct `case` branch keyed on the provenance value's
              content (whether it matches the `preset:*` pattern)
```

## Observations

| # | Observation | Evidence |
|---|---|---|
| 1 | `install.sh` never calls `app_already_installed` anywhere in the file. It independently reimplements the identical logic — the same two `brew_formula_installed`/`brew_cask_installed` calls, the same `/Applications/$name.app` fallback — as a separate, unshared code path, twice (lines 35-36 and 242-243). | `install.sh:35-36,48,242-243` |
| 2 | `render.sh`'s `plan_source_label` is a `case` statement whose entire body branches on the provenance string's content: a `preset:*` pattern match takes one path (resolving a preset name), anything else takes another (`"selección manual"`). This is a direct, unambiguous branch on the value the Constraint claims nothing branches on. | `render.sh:16-30`, full function body quoted above |
| 3 | `install.sh` itself does the opposite — it reads the provenance/source field into a variable named `_source` and never uses it, an explicit unused-variable convention. This is the one place the Constraint's claim holds exactly as written; it is `render.sh`, not `install.sh` or `planner.sh`, where it fails. | `install.sh:32` |
| 4 | `menu.sh` calls `selection_toggle` exactly once and never calls `selection_add` or `selection_remove` directly — both are reachable only as `selection_toggle`'s internal implementation. The underlying capability (an application can be added to or removed from the selection, only through this module's own functions) is real and observed; the specific claim that Menu "calls this module's add/remove/toggle... functions" reads naturally as naming three direct call sites, which is not what the evidence shows. | `menu.sh:306`; zero hits for `selection_add`/`selection_remove` in `menu.sh` |

## Result

| Claim checked | Result |
|---|---|
| Responsibility 1 — owns the set, no separate preset/manual representation | VERIFIED |
| Responsibility 2 — determines compatibility (ARCHS, MIN_MACOS) | VERIFIED |
| Responsibility 3 — determines installed status, checked the same way for every caller | **CONTRADICTED** — `install.sh` determines installed status through an independently duplicated implementation, never by calling this module's `app_already_installed` (Observation 1) |
| Responsibility 4 — loads a preset, replaces wholesale, records incompatible instead of dropping | VERIFIED |
| Consumes 1 — Catalog application data via accessors only | VERIFIED |
| Consumes 2 — preset application list via Catalog's preset accessors | VERIFIED |
| Consumes 3 — real macOS version and architecture at compatibility-check time | VERIFIED |
| Consumes 4 — session-level Homebrew list cache at installed-check time | VERIFIED |
| Produces 1 — updates to the set via own add/remove/toggle functions | VERIFIED |
| Produces 2 — raw representations read directly by `Deployment.Planner` | VERIFIED |
| Produces 3 — compatibility determination (yes/no + reason) | VERIFIED |
| Produces 4 — installed-status determination | VERIFIED |
| Collaborates With — `Deployment.Menu` | **AMBIGUOUS** — every named capability (count, reset, compatibility, installed-status, preset-loading, "never a raw representation") is confirmed exactly; the "add/remove" portion of "add/remove/toggle" is reachable only indirectly through `selection_toggle`, never called directly, and the claim's wording does not distinguish direct from indirect invocation (Observation 4) |
| Collaborates With — `Deployment.Renderer` | VERIFIED |
| Collaborates With — `Deployment.Planner` | VERIFIED |
| Collaborates With — `Deployment` | VERIFIED |
| Constraint 1 — first-occurrence-wins on duplicate add | VERIFIED |
| Constraint 2 — provenance is opaque; nothing that reads it branches on its value | **CONTRADICTED** — `render.sh`'s `plan_source_label` branches directly on the provenance value's content (Observation 2) |
| Constraint 3 — does not classify into install tracks or determine install method | VERIFIED |

**16 / 19 claims verified. 2 contradictions. 1 ambiguous claim. 0 claims
with missing evidence.**

## Confidence

**High** on every row, including both contradictions and the ambiguous
claim — each resolved to a specific, quoted piece of code, not an
inference. The ambiguous claim is high-confidence in the sense that the
underlying disagreement (direct vs. indirect invocation) is itself clearly
evidenced; the ambiguity is in the claim's wording, not in the evidence
available to judge it.

## Recommendations

None. Per this task's explicit restriction, no fix, rewrite, or
architectural judgment is offered for either contradiction or the
ambiguous claim — they are reported as findings only.

## History

| Date | Result | Note |
|---|---|---|
| 2026-08-06 | 16/19 VERIFIED, 2 CONTRADICTED, 1 AMBIGUOUS | Initial Boundary Verification of `Deployment.Selection`'s Module Contract |
