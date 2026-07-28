# JB Toolkit Catalog

Deployment data for JB Toolkit. **Pure data — no code lives here.** Every file is
flat `KEY=value` or a plain ID list, editable with any text editor.

The normative format specification is [docs/Catalog-Format.md](../docs/Catalog-Format.md).
The architecture behind it is [docs/Deployment-Design.md](../docs/Deployment-Design.md).

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

- **Add an application:** create `applications/<id>/app.conf` with `ID`, `NAME`,
  `DESCRIPTION`, `CATEGORY` (exactly one value — places it in the Application
  Catalog browser), and its `INSTALL_METHOD`:
  - `brew` / `cask` → add `PACKAGE=<homebrew name>` (verify it first with
    `brew info --formula <name>` or `brew info --cask <name>`)
  - `manual` / `pkg` / `dmg` → add `DOWNLOAD_URL=<where to get it>`
  - `mas` → add `PACKAGE=<App Store numeric ID>`

  A package identifier may exist in only one `app.conf` in the whole catalog.
  Apps not available through Homebrew are welcome — declare them `manual` and
  they participate in presets, plans, and reports as honest manual steps, never
  as failures.
- **Mark a JB Pick:** `JB_PICK=true` **and** `JB_PICK_NOTE=<why JB Repair recommends
  it>`. A pick without its reasoning is invalid.
- **Recommend by hardware:** `HW_RECOMMEND=<machine families>` (e.g.
  `macbook_air macbook_pro`, or `external_display`) — the app is pre-checked and
  annotated in the Application Catalog when the detected machine matches.
- **Add a preset:** a new `[id]` section in `presets.conf` with `NAME`,
  `DESCRIPTION`, optional `ORDER`, and `APPS=<space-separated application IDs>`.
  It appears in the flat Quick Presets list automatically. No code changes, ever.
