# JB Toolkit Catalog

Deployment data for JB Toolkit. **Pure data — no code lives here.** Every file is
flat `KEY=value` or a plain ID list, editable with any text editor.

The normative format specification is [docs/Catalog-Format.md](../docs/Catalog-Format.md).
The architecture behind it is [docs/Deployment-Design.md](../docs/Deployment-Design.md).

## Layout

```
applications/<id>/app.conf   # One directory per application — the directory IS the app
bundles/<id>.bundle          # One application ID per line; first comment = display name
profiles/<id>.profile        # Composes bundles; places itself in the menu (CATEGORY/SUBCATEGORY)
vendors/                     # RESERVED for future per-organization presets — do not use
```

## Quick reference

- **Add an application:** create `applications/<id>/app.conf` with `ID`, `NAME`,
  exactly one of `BREW`/`CASK`, and `DESCRIPTION`. A package name may exist in only
  one `app.conf` in the whole catalog.
- **Mark a JB Pick:** `JB_PICK=true` **and** `JB_PICK_NOTE=<why JB Repair recommends
  it>`. A pick without its reasoning is invalid.
- **Add a bundle:** `bundles/<id>.bundle`, first line `# Display Name`, then existing
  application IDs, one per line.
- **Add a menu entry:** just add a profile — menus regenerate from `CATEGORY`,
  `SUBCATEGORY`, and `ORDER`. No code changes.
