---
title: OpenBoardView
category: Repair & Diagnostics
package: openboardview
install_method: Homebrew Cask
keywords: repair, boardview, logic board, schematic, no-power
website: https://openboardview.org
---

# OpenBoardView

## What is it?

Viewer for logic board (BoardView/ASC/BRD) files used to trace components
and test points during hardware repair.

## When should I use it?

- Component-level repair on a logic board (no-power, no-boot, liquid
  damage cases)
- Locating a specific test point or component referenced in a repair
  guide
- Tracing which components share a net before probing with a multimeter

## Recommended for

- Technicians
- Hardware repair specialists
- Logic board diagnostics

## Useful Commands

No CLI — OpenBoardView is a GUI viewer. Load a board file via
File → Open, then interact with the board visually.

## Workflow

1. Obtain the correct BoardView file for the exact board revision being
   repaired (mismatched revisions will mislabel components).
2. Open the file in OpenBoardView.
3. Search for a component or net by name using the search box.
4. Click a pin/component to highlight every other point on the same net
   — this is the core diagnostic technique for tracing shorts and opens.

## Troubleshooting

- Problem: board loads but components don't line up with the physical
  board. Fix: confirm the board revision matches exactly — Apple boards
  often have multiple revisions with different layouts.
- Problem: file won't open / "invalid format" error. Fix: confirm the
  file extension is one of the supported formats (`.brd`, `.bvr`, `.fz`,
  `.asc`, `.tvw`); some board files require a separate decryption step
  before they're readable.
- Problem: net highlighting shows too many points to be useful. Fix:
  zoom in and use the component list panel to narrow down by reference
  designator instead of clicking blindly.

## Dependencies

- None. Often used alongside a multimeter and microscope at the bench.

## JB Repair Use Cases

- Tracing a shorted rail on a no-power logic board back to a specific
  failed component.
- Locating an exact test point referenced in a third-party repair guide
  before probing with a multimeter.
- Cross-referencing a schematic against the physical board layout during
  liquid-damage cleanup.

## References

- Official website: https://openboardview.org
- Official documentation: https://github.com/OpenBoardView/OpenBoardView/wiki
