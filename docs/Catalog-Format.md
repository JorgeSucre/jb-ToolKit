# Catalog Format — Data Contracts

This is the **normative specification** for everything under `catalog/`. The Phase 3
loaders implement exactly these rules; the Phase 3 validator rejects exactly these
violations. If this document and a loader ever disagree, this document wins and the
loader is the bug.

Design context lives in [Deployment-Design.md](Deployment-Design.md). This file is
the contract.

## Common file conventions

Every catalog file is a plain-text, shell-friendly flat file in the `state.env`
tradition:

- `KEY=value`, one pair per line. The **first** `=` splits key from value; values
  may contain `=`.
- Values are raw text — no quoting, no escaping, no line continuations. One line per
  value.
- Lines starting with `#` are comments. Blank lines are ignored.
- Keys are `UPPER_SNAKE_CASE`. Unknown keys are ignored by tools (forward
  compatibility) but discouraged.
- Encoding is UTF-8. User-visible values (`NAME`, `DESCRIPTION`, `JB_PICK_NOTE`) are
  **Spanish**, like all UI text.
- **No YAML, no JSON, no SQLite — ever.** A technician with any text editor is a
  first-class catalog author. Parsing must stay implementable with the same awk
  pattern as `state_value`.

IDs (application, bundle, profile) are kebab-case: lowercase letters, digits, and
hyphens (`^[a-z0-9][a-z0-9-]*$`).

## Layer 1 — Applications

**Location:** `catalog/applications/<id>/app.conf`

**The directory is the application.** Each application owns a directory named by its
ID; `app.conf` is the only required file. The directory may later gain assets
(README.md, icons, screenshots, localized descriptions, release notes, compatibility
notes) without any format change. Tools must resolve applications by **directory
name** and read `<dir>/app.conf` — never glob for conf files across the tree.

### Fields

| Field | Required | Contract |
|---|---|---|
| `ID` | yes | Must equal the directory name exactly |
| `NAME` | yes | Display name, shown verbatim in the UI |
| `INSTALL_METHOD` | yes | `brew` \| `cask` \| `mas` \| `pkg` \| `dmg` \| `manual`. See "Installation methods" below |
| `PACKAGE` | iff method is `brew`/`cask`/`mas` | The package identifier: Homebrew formula name, cask token, or Mac App Store numeric ID |
| `DOWNLOAD_URL` | iff method is `manual`/`pkg`/`dmg` | Where the technician obtains the app. Optional for other methods |
| `DESCRIPTION` | yes | One line, Spanish |
| `CATEGORIES` | no | Space-separated lowercase tags (informational; used for grouping in future flows) |
| `JB_PICK` | no | `true` or absent. Any other value is invalid |
| `JB_PICK_NOTE` | required iff `JB_PICK=true` | The reasoning behind the recommendation, Spanish. **A pick without a non-empty note is invalid** |
| `ARCHS` | no | Space-separated `uname -m` values (`arm64`, `x86_64`). Absent = all architectures |
| `MIN_MACOS` | no | Minimum macOS **major** version (integer, e.g. `12`). Absent = any supported macOS |
| `RECOMMENDED` | no | `true` or absent. Ordering hint in future Custom flows |
| `HW_RECOMMEND` | no | Space-separated machine families this app is recommended for: `macbook_air`, `macbook_pro`, `mac_mini`, `mac_studio`, `imac`, plus the pseudo-family `external_display`. Apps carrying this field are offered by the hardware-recommendation flow and are exempt from the doctor's "unreferenced" advisory |

The `PACKAGE` line is the **single place in the repository** where a package
identifier may appear for deployment purposes (unique per method — the brew, cask,
and mas namespaces are independent). Bundles and profiles must never contain
package names. The legacy v2.0.0 keys `BREW=` and `CASK=` are **invalid**; the
validator rejects them so a leftover line can never become a silent no-op.

### Installation methods

| Method | Automated? | Carrier field | Behavior |
|---|---|---|---|
| `brew` | yes | `PACKAGE` (formula) | Installed by the engine (`brew install`) and verified per app |
| `cask` | yes | `PACKAGE` (cask token) | Installed by the engine (`brew install --cask`) and verified per app |
| `mas` | not yet | `PACKAGE` (App Store ID) | Manual track: reported as "instalar desde App Store" |
| `pkg` | not yet | `DOWNLOAD_URL` | Manual track: reported as a manual step, download page offered |
| `dmg` | not yet | `DOWNLOAD_URL` | Manual track: reported as a manual step, download page offered |
| `manual` | no | `DOWNLOAD_URL` | Manual track: reported as a manual step, download page offered |

Applications on the **manual track** are first-class catalog members: they appear
in bundles, profiles, JB Picks, plans, and reports. They are **never** deployment
failures — the plan carries them separately (`PLAN_MANUAL`) and the result screen
lists them as pending manual steps. If a manual-track app's bundle
(`/Applications/<NAME>.app`) is already present, it is reported as already
installed (verified by existence).

### Example

```bash
# catalog/applications/keka/app.conf
ID=keka
NAME=Keka
INSTALL_METHOD=cask
PACKAGE=keka
DESCRIPTION=Compresor y descompresor moderno y sin publicidad
CATEGORIES=utilities
JB_PICK=true
JB_PICK_NOTE=Reemplazo moderno de The Unarchiver. Años de uso sin incidencias en equipos de clientes.
RECOMMENDED=true
```

```bash
# catalog/applications/pdfgear/app.conf — not available through Homebrew
ID=pdfgear
NAME=PDFgear
INSTALL_METHOD=manual
DOWNLOAD_URL=https://www.pdfgear.com/
DESCRIPTION=Editor PDF gratuito y completo
CATEGORIES=productivity
JB_PICK=true
JB_PICK_NOTE=Cubre la mayoría de casos de edición PDF sin licencia de Acrobat. Ahorro real para clientes.
RECOMMENDED=true
```

## Layer 2 — Bundles

**Location:** `catalog/bundles/<id>.bundle`

A bundle is an ordered list of **application IDs**, one per line. `#` comments and
blank lines are ignored. The **first comment line is the bundle's display name**
(contract, not convention — the loader reads it).

Bundles carry no other metadata. They never contain package names, versions, or
application fields — those live on the application record.

```bash
# JB Essentials
appcleaner
keka
rectangle
stats
pdfgear
openlogi
```

Rules:

- Every line must be an existing application directory ID. A dangling reference is a
  validation failure that names the bundle file and the missing ID.
- Duplicate IDs within one bundle are invalid.
- The same application may appear in **multiple bundles** — deduplication happens at
  resolution time.

## Layer 3 — Profiles

**Location:** `catalog/profiles/<id>.profile`

A profile composes bundles and places itself in the Deployment menu tree.

### Fields

| Field | Required | Contract |
|---|---|---|
| `NAME` | yes | Display name (confirmation and result screens) |
| `DESCRIPTION` | yes | One line, Spanish |
| `CATEGORY` | yes | Top-level menu placement (display text, e.g. `Professional`) |
| `SUBCATEGORY` | no | Second-level menu label. Absent = the profile is its category's direct leaf |
| `ORDER` | no | Integer sort key within its menu level. Default `50`; ties break alphabetically |
| `BUNDLES` | yes | Space-separated bundle IDs, resolution order preserved |

Profiles reference **bundle IDs only** — never application IDs, never package names.

### Menu-generation contract

1. Level 1 lists distinct `CATEGORY` values ordered by the minimum `ORDER` among
   their profiles, plus the fixed `Custom` and `JB Picks` entries.
2. A category containing exactly one profile with no `SUBCATEGORY` collapses: it is
   selected directly from level 1.
3. A category with multiple profiles opens a submenu listing them by `SUBCATEGORY`
   (fallback `NAME`), ordered by `ORDER`.
4. Maximum depth is two levels. Growth is absorbed by adding categories, keeping
   every menu at ~7 visible entries.

### Example

```bash
# catalog/profiles/engineering.profile
NAME=Engineering
DESCRIPTION=Perfil profesional para ingeniería y desarrollo técnico
CATEGORY=Professional
SUBCATEGORY=Engineering
ORDER=30
BUNDLES=jb-essentials productivity developer
```

## Layer 4 — Vendors (RESERVED)

**Location:** `catalog/vendors/`

Reserved for future deployment presets: named compositions of **profiles** for
specific organizations (JB Repair defaults, Business, Education, LCS, individual
clients). One level above profiles, same referential philosophy — vendors will
compose profiles without modifying them.

**Nothing parses this directory today.** It contains only a README documenting the
intent. Do not place parseable data here and do not build against it until the layer
is designed for real.

## Resolution semantics

```mermaid
flowchart LR
    P[profile] -->|BUNDLES order| B1[bundle 1]
    P --> B2[bundle 2]
    B1 -->|line order| IDS[app ID list]
    B2 --> IDS
    IDS --> DEDUP[deduplicate<br/>first occurrence wins]
    DEDUP --> FILTER[compatibility filter<br/>ARCHS / MIN_MACOS<br/>skips recorded with reasons]
    FILTER --> SET[final install set<br/>+ named skip list]
```

- Resolution order: bundles in `BUNDLES` order, applications in bundle line order,
  first occurrence wins on duplicates.
- Compatibility filtering compares `ARCHS` against `uname -m` and `MIN_MACOS`
  against `sw_vers -productVersion` (major). Every filtered application is recorded
  as a named skip with its reason — **silent skips are a contract violation.**
- The planner then splits the surviving set by `INSTALL_METHOD`: `brew`/`cask`
  records go to the automatic install list, everything else to the manual-step
  list. Technician deselections from bundle review are recorded as named skips
  ("deseleccionada por el técnico"), and hardware-recommendation extras enter with
  provenance `hardware`.

## Validation rules (Phase 3 validator)

An invalid catalog entry is a fatal load error that names the offending file. The
complete rule set:

| # | Rule |
|---|---|
| V1 | `ID` equals its directory name (applications) / filename stem (bundles, profiles) |
| V2 | All required fields present and non-empty |
| V3 | `INSTALL_METHOD` present and ∈ {`brew`, `cask`, `mas`, `pkg`, `dmg`, `manual`}; `PACKAGE` present for `brew`/`cask`/`mas`; `DOWNLOAD_URL` present for `manual`/`pkg`/`dmg`; legacy `BREW`/`CASK` keys rejected |
| V4 | `JB_PICK`, `RECOMMENDED` are `true` when present |
| V5 | `JB_PICK=true` requires a non-empty `JB_PICK_NOTE` |
| V6 | `ARCHS` values ∈ {`arm64`, `x86_64`}; `MIN_MACOS` and `ORDER` are integers; `HW_RECOMMEND` values ∈ the known machine families |
| V7 | Every bundle line resolves to an existing application directory |
| V8 | No duplicate IDs within a bundle; no duplicate application/bundle/profile IDs globally; no `method:PACKAGE` pair defined by more than one application |
| V9 | Every `BUNDLES` entry resolves to an existing bundle file |
| V10 | Bundle files begin with a display-name comment line |

## Catalog Doctor (advisory diagnostics)

`deployment.sh --doctor` runs the validator and then adds **maintainability
suggestions** on a valid catalog. Advisories never fail validation:

| # | Advisory |
|---|---|
| A1 | Application exists but no bundle references it (apps with `HW_RECOMMEND` are exempt — they are reachable through the hardware-recommendation flow) |
| A2 | Bundle contains a single application |
| A3 | Application appears in multiple bundles (legitimate; dedup applies at resolution) |
| A4 | Profile references a single bundle |
| A5 | Category contains a single profile (renders as a direct menu entry) |

Note: a JB Pick missing its note is **not** an advisory — it is validation failure
V5. A recommendation without reasoning is invalid, not merely improvable.

## Adding catalog entries — technician quick reference

**New application:** create `catalog/applications/<id>/`, write `app.conf` with the
required fields and its `INSTALL_METHOD` (`PACKAGE` for brew/cask/mas,
`DOWNLOAD_URL` for manual/pkg/dmg). Verify the package identifier against the real
installation method — `brew info --formula <name>` or `brew info --cask <name>` —
before committing it. If the app isn't available through Homebrew, that is not a
problem: declare it `manual` with its download page. If it's a JB Pick, write the
reason — the note is what makes it a recommendation.

**New bundle:** create `catalog/bundles/<id>.bundle`, first line `# Display Name`,
then one existing application ID per line.

**New profile / menu entry:** create `catalog/profiles/<id>.profile` with
`CATEGORY` (and `SUBCATEGORY` to nest), `ORDER` to position it, `BUNDLES` to compose
it. **Menus regenerate from the data — no code changes, ever.**
