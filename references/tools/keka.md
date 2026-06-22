---
title: Keka
category: Utilities
package: keka
install_method: Homebrew Cask
keywords: compression, archive, zip, 7z, extraction
recommended_profiles: all
recommend_reason: A better archive tool than Finder belongs on every technician Mac, regardless of model.
website: https://www.keka.io
---

# Keka

## What is it?

File compression and extraction utility for macOS, with broader format
support than Finder's built-in Archive Utility.

## When should I use it?

- A client sends or needs a `.7z`, `.rar`, or password-protected archive
  Finder can't open
- You need to package multiple files/reports into one archive before
  sending them
- You want to compress a backup before moving it to external storage

## Recommended for

- Technicians
- Mac users
- Client deployments

## Useful Commands

No CLI in the standard install — Keka is a GUI app (drag-and-drop and
Finder integration). Compression/extraction is done visually.

## Workflow

1. Drag the file(s) or folder onto the Keka window (or right-click →
   Services in Finder, once enabled).
2. Choose the output format (ZIP for compatibility, 7z for better
   compression, encrypted ZIP for sensitive data).
3. For extraction, double-click the archive or drag it onto Keka.

## Troubleshooting

- Problem: Finder right-click menu doesn't show Keka options. Fix: open
  Keka once after install and enable the Finder extension when prompted,
  or via System Settings → Extensions.
- Problem: archive created by Keka won't open on Windows. Fix: prefer
  standard ZIP over 7z when the recipient's OS is unknown.
- Problem: password-protected archive won't extract. Fix: confirm the
  password was set with AES-256 encryption when created — older
  encryption modes can behave inconsistently across tools.

## Dependencies

- None.

## JB Repair Use Cases

- Compressing a client's full user folder backup before copying it to an
  external drive.
- Packaging diagnostic reports and logs into a single ZIP before sending
  them to a client or vendor.
- Opening a `.7z` driver package a client received from a hardware
  vendor.

## References

- Official website: https://www.keka.io
