# JB Toolkit Catalog

Deployment data for JB Toolkit. **Pure data — no code lives here.** Every file is
flat `KEY=value` or a plain ID list, editable with any text editor.

The normative format specification is [docs/Catalog-Format.md](../docs/Catalog-Format.md).
The architecture behind it is [docs/Deployment-Design.md](../docs/Deployment-Design.md).
The catalog's own philosophy and metadata standard live in
[docs/CATALOG_CONSTITUTION.md](../docs/CATALOG_CONSTITUTION.md) and
[docs/CATALOG_STANDARD.md](../docs/CATALOG_STANDARD.md).

## Layout

```
applications/<id>/app.conf   # One directory per application — the directory IS the app
presets.conf                 # One [id] section per preset — nothing more than an APPS list
vendors/                     # RESERVED for future per-organization presets — do not use
```

Two layers, not four. There is no bundle/profile intermediate grouping — see
[docs/architecture/0006-deployment-flattening.md](../docs/architecture/0006-deployment-flattening.md).
Every application owns exactly one category, and every preset lives in this
one file — see
[docs/architecture/0007-catalog-consistency.md](../docs/architecture/0007-catalog-consistency.md).

## Quick reference

- **Add an application:** create `applications/<id>/app.conf` with `APP_ID`, `NAME`,
  `CATEGORY` (exactly one value — places it in the Application Catalog browser),
  `DESCRIPTION`, `HOMEPAGE`, `LICENSE`, `ARCHITECTURE`, and its `INSTALL_METHOD`
  with a matching `PACKAGE_TYPE` (see
  [docs/CATALOG_STANDARD.md](../docs/CATALOG_STANDARD.md) for the complete
  required-field list):
  - `brew` / `cask` → add `PACKAGE_NAME=<homebrew name>` (verify it first with
    `brew info --formula <name>` or `brew info --cask <name>`), `PACKAGE_TYPE=formula`/`cask`
  - `manual` / `pkg` / `dmg` → add `DOWNLOAD_URL=<where to get it>`, `PACKAGE_TYPE=manual`/`installer`
  - `mas` → add `PACKAGE_NAME=<App Store numeric ID>`, `PACKAGE_TYPE=app-store`

  A package identifier may exist in only one `app.conf` in the whole catalog.
  Apps not available through Homebrew are welcome — declare them `manual` and
  they participate in presets, plans, and reports as honest manual steps, never
  as failures.
- **Mark a JB Pick:** `JB_PICK=true` **and** `JB_PICK_NOTE=<why JB Repair recommends
  it>`. A pick without its reasoning is invalid.
- **Recommend by hardware:** `HW_RECOMMEND=<machine families>` (e.g.
  `macbook_air macbook_pro`, or `external_display`) — the app is pre-checked and
  annotated in the Application Catalog when the detected machine matches.
- **Cross-reference other applications:** `RELATED=<space-separated application
  IDs>` for companion tools used alongside this one (validated against the
  catalog); `ALTERNATIVES=<free text>` for substitutes, including ones this
  catalog doesn't carry. Both are optional and shown in the Application
  Catalog's detail view (`d<number>`).
- **Add a preset:** a new `[id]` section in `presets.conf` with `NAME`,
  `DESCRIPTION`, optional `ORDER`, and `APPS=<space-separated application IDs>`.
  It appears in the flat Quick Presets list automatically. No code changes, ever.
