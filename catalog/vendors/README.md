# Vendors — RESERVED

This directory is **reserved architectural space**. Nothing parses it today, and
nothing should be built against it yet.

## Intended purpose (future)

Vendor presets: named compositions of **profiles** for specific organizations —
JB Repair's own defaults, Business, Education, LCS, individual clients. A vendor
will compose existing profiles without modifying the catalog itself, the same
referential relationship profiles have to bundles, one level up:

```
vendors → profiles → bundles → applications → Homebrew packages
```

## Rules until the layer is designed

- Do not place parseable data files here.
- Do not reference this directory from any loader or menu.
- When the need becomes real, design the layer first
  (see docs/Deployment-Design.md), then implement.
