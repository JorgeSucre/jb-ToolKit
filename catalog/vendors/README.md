# Vendors — RESERVED

This directory is **reserved architectural space**. Nothing parses it today, and
nothing should be built against it yet.

## Intended purpose (future)

Vendor presets: named compositions of **presets** for specific organizations —
JB Repair's own defaults, Business, Education, LCS, individual clients. A vendor
would compose existing presets without modifying the catalog itself:

```
vendors → presets → applications → Homebrew packages
```

**Known tension, deliberately unresolved:** a vendor that composes multiple
presets is structurally the same shape as the "bundle" grouping layer removed
in v2.2 (see [docs/architecture/0006-deployment-flattening.md](../../docs/architecture/0006-deployment-flattening.md)).
If this layer is ever designed for real, design it consciously against that
tension — don't silently resurrect bundles under the name "vendor."

## Rules until the layer is designed

- Do not place parseable data files here.
- Do not reference this directory from any loader or menu.
- When the need becomes real, design the layer first
  (see docs/Deployment-Design.md), then implement.
