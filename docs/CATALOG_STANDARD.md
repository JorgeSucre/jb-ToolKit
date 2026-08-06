# Catalog Quality Standard

The normative metadata schema for `catalog/applications/<id>/app.conf`, as
of v2.3.0. This document defines *what fields exist and what they mean*;
[Catalog-Format.md](Catalog-Format.md) is the complete parsing/validation
reference (file conventions, the preset format, the full V1–V11 rule table).
[CATALOG_CONSTITUTION.md](CATALOG_CONSTITUTION.md) is the philosophy behind
why the schema looks like this.

Same rules as every other catalog file: flat `KEY=value`, one pair per
line, first `=` splits key from value, `#` comments, blank lines ignored.
**No YAML, no JSON, no SQLite.** A technician with a text editor remains a
first-class catalog author.

## Required fields

Every application must define all eleven of these. A missing one fails
validation (V2) and names the file.

| Field | Contract |
|---|---|
| `APP_ID` | Must equal the directory name exactly (kebab-case) |
| `NAME` | The application's **official** project/product name (Constitution §6) — never a nickname |
| `CATEGORY` | Exactly one value from the fixed enum below (Constitution §1) |
| `DESCRIPTION` | One line, Spanish, what the application does |
| `HOMEPAGE` | The application's official homepage URL |
| `LICENSE` | See the License vocabulary below |
| `INSTALL_METHOD` | `brew` \| `cask` \| `mas` \| `pkg` \| `dmg` \| `manual` — unchanged from prior versions |
| `PACKAGE_NAME` | Required iff `INSTALL_METHOD` ∈ {`brew`, `cask`, `mas`}: the Homebrew formula/cask token, or the Mac App Store numeric ID |
| `PACKAGE_TYPE` | `formula` \| `cask` \| `app-store` \| `installer` \| `manual` — must agree with `INSTALL_METHOD` (see below) |
| `ARCHITECTURE` | `universal` \| `arm64` \| `intel` — a human-facing descriptor, **not** the compatibility filter (see "Two different architecture fields" below) |
| `JB_PICK` | `true` or absent |

`JB_PICK_NOTE` becomes required the moment `JB_PICK=true` — unchanged rule
from prior versions. `DOWNLOAD_URL` becomes required for
`manual`/`pkg`/`dmg`, same as before.

### `PACKAGE_TYPE` ↔ `INSTALL_METHOD`

| `INSTALL_METHOD` | Required `PACKAGE_TYPE` |
|---|---|
| `brew` | `formula` |
| `cask` | `cask` |
| `mas` | `app-store` |
| `pkg` / `dmg` | `installer` |
| `manual` | `manual` |

This is deliberately redundant with `INSTALL_METHOD` today — `PACKAGE_TYPE`
exists for **metadata first** (Constitution §8): a future feature that
wants to say "this is a Homebrew cask" shouldn't have to know that
`INSTALL_METHOD=cask` is how that fact is currently encoded. The validator
checks the two agree, so the redundancy can never quietly drift apart.

### Two different architecture fields

`ARCHITECTURE` (this standard) and `ARCHS` (optional, below) answer
different questions and must not be confused:

- **`ARCHITECTURE`** is descriptive metadata: "universal," "arm64," or
  "intel," for humans and future features to read. It never gates
  anything.
- **`ARCHS`** is the existing compatibility filter Deployment's selection
  layer actually enforces (`app_incompatibility_reason`) — space-separated
  `arm64`/`x86_64`, absent means "compatible with everything." Only set
  `ARCHS` when an application genuinely cannot run on an architecture at
  all; setting it incorrectly silently excludes technicians from installing
  a compatible application.

## Category enum

Exactly one of:

`ai`, `browsers`, `cloud`, `communication`, `creative`, `development`,
`device-management`, `media`, `networking`, `printers-scanners`,
`productivity`, `security`, `system`

Consolidated and expanded from v2.2.1's 8-value enum: `hardware` and
`utilities` merged into `system` (they were always describing the same kind
of thing — small, local, single-machine tools — see the migration summary
for why keeping them apart stopped adding clarity once `device-management`
needed splitting out too). See CATALOG_CONSTITUTION.md §2 for why a category
is chosen by purpose, never by persona.

`cloud` was added in v2.3.1 once cloud-storage/sync clients (Dropbox,
Google Drive, MEGAsync, Nextcloud, Resilio Sync, Syncthing) reached enough
volume to justify their own purpose-coherent home rather than being split
across `productivity` and `system` — the same bar `device-management` and
`printers-scanners` were held to when they were carved out in v2.3.0.

## License vocabulary

`LICENSE` is free text (never enum-validated — real license diversity is
too wide to force into a fixed list without losing information), but should
draw from one of two forms:

- A real [SPDX](https://spdx.org/licenses/) identifier for open-source
  software with a specific license (`MIT`, `GPL-3.0-only`,
  `Apache-2.0`, `BSD-3-Clause`, …) — prefer this whenever the project
  states a specific license.
- One of a small set of non-SPDX descriptors for everything else:
  `Free`, `Freemium`, `Proprietary`, `Open Source` (when a project is
  clearly open-source but a single SPDX identifier doesn't cleanly apply —
  multi-licensed, or the specific license wasn't confidently identified).

## Optional fields

Supported wherever they add real information; omitted otherwise — an
absent optional field is not a validation concern.

| Field | Contract |
|---|---|
| `ALTERNATIVES` | Free text: names of comparable tools, for the Application Catalog's detail view. Deliberately **not** validated against the catalog — an alternative is often software this catalog doesn't carry at all (App Store-only, a different platform), and that's a legitimate thing to tell a technician, not a defect. See `RELATED` below for the validated, catalog-internal equivalent |
| `RELATED` (v2.3.2) | Optional, space-separated application IDs: companion tools typically used *alongside* this one, not substitutes for it (e.g. Docker Desktop → `visual-studio-code git postman node`). Same shape and validation as a preset's `APPS` field — every ID must resolve to a real catalog entry (V12) — because unlike `ALTERNATIVES`, a "related" reference only makes sense pointing at something this catalog can actually offer to install. Populated selectively, not exhaustively — most applications have none |
| `NOTES` | Free text, Spanish: caveats that don't fit elsewhere — e.g. "normalmente se despliega vía Docker, no es una app nativa de macOS" |
| `WEBSITE` | A secondary link, only when meaningfully different from `HOMEPAGE` (e.g. the vendor's corporate site vs. the product's own page). Omit when it would just repeat `HOMEPAGE` |
| `REQUIREMENTS` | Free text, Spanish: human-readable requirements `ARCHS`/`MIN_MACOS` can't express (e.g. "requiere GPU dedicada") |
| `ARCHS` | Unchanged from prior versions — see "Two different architecture fields" above |
| `MIN_MACOS` | Unchanged from prior versions: minimum macOS major version, integer |
| `HW_RECOMMEND` | Unchanged from prior versions: machine families this app is recommended for |

## What `JB_PICK` means here

Adding an application to the catalog is not a JB Pick. `JB_PICK=true` plus
a non-empty `JB_PICK_NOTE` is a specific, load-bearing claim: JB Repair
stands behind this recommendation from real field experience (see the
existing picks' notes for the tone — "años de uso sin incidencias en
equipos de clientes"). A newly-catalogued application without that
operational history is not marked `JB_PICK=true` just because it's now in
the catalog — see the migration summary for how this was applied
consistently across the v2.3.0 catalog expansion.

## Why this stays plain text

No YAML, no JSON, no SQLite, no external database — this was true before
v2.3.0 and remains true after it. Eleven required fields per application is
still eleven flat `KEY=value` lines, parseable by the exact same six-line
`awk` pattern every other catalog file already uses. A schema doesn't
justify a new parser; it justifies more lines in the same one.
