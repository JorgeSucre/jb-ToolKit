---
title: Smartmontools
category: Repair & Diagnostics
package: smartmontools
install_method: Homebrew Formula
keywords: repair, disk health, smart, drive failure, diagnostics
---

# Smartmontools

## What is it?

Command-line utility (`smartctl`) for reading a drive's S.M.A.R.T. health
data — the self-monitoring data built into most HDDs and SSDs.

## When should I use it?

- A client reports random freezes, slow performance, or "disk read error"
  type messages
- Before doing a data migration, to confirm the source drive is actually
  healthy
- As a baseline check during any hardware repair involving storage

## Recommended for

- Technicians
- Hardware repair

## Useful Commands

```bash
smartctl -a /dev/disk0
```
Prints the full S.M.A.R.T. report for `disk0`: overall health, reallocated
sector count, power-on hours, temperature, and pending sectors.

Expected output highlights:

- `SMART overall-health self-assessment test result: PASSED` — drive
  reports itself healthy.
- `Reallocated_Sector_Ct` with a nonzero, climbing value — early sign of a
  failing drive.
- `Power_On_Hours` — useful to confirm a drive's real age versus what the
  client believes.

```bash
smartctl -i /dev/disk0
```
Prints identification info only (model, serial, firmware) — useful for
matching a drive against a recall or warranty list.

```bash
smartctl -t short /dev/disk0
```
Starts a short self-test on the drive. Check progress/results afterward
with `smartctl -a /dev/disk0`.

## Workflow

1. Identify the disk identifier with `diskutil list` (e.g. `disk0`,
   `disk1`).
2. Run `smartctl -a /dev/diskN` for the target drive.
3. Check the overall health line first, then scan for nonzero
   reallocated/pending sector counts.
4. If results are inconclusive, run a self-test with `-t short` and
   re-check.

## Troubleshooting

- Problem: "Operation not supported" on Apple Silicon internal SSDs. Fix:
  this is expected — Apple's internal NVMe controllers on T2/Apple Silicon
  Macs are not exposed the same way as standard drives. smartmontools is
  most useful here for external/USB drives and Intel Macs.
- Problem: command requires elevated access. Fix: re-run with `sudo`.
- Problem: drive not listed. Fix: confirm it's mounted/connected and check
  `diskutil list` again for the correct identifier.

## Dependencies

- None. Works standalone.

## JB Repair Use Cases

- Confirming a client's external backup drive is healthy before trusting
  it as the only copy during a migration.
- Diagnosing intermittent freezing on an older Intel Mac by checking for
  climbing reallocated-sector counts.
- Documenting drive health in a repair report before returning a machine.

## References

- Official website: https://www.smartmontools.org
- Official documentation: https://www.smartmontools.org/wiki/Smartctl
