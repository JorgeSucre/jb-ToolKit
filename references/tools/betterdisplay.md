---
title: BetterDisplay
category: Monitoring
package: betterdisplay
install_method: Homebrew Cask
keywords: display, monitor, resolution, hidpi, scaling
---

# BetterDisplay

## What is it?

Display management utility that adds HiDPI scaling, custom resolutions,
and per-display controls macOS doesn't expose natively.

## When should I use it?

- A Mac mini, Mac Studio, or iMac is connected to one or more external
  monitors that don't offer a sharp native HiDPI mode
- A client wants a non-standard resolution or scaling on an external
  display

## Recommended for

- Technicians
- Desktop Macs with external displays
- Multi-monitor client setups

## Useful Commands

No CLI required for everyday use — configuration is done through the
BetterDisplay menu-bar app.

## Workflow

1. Connect the external display(s).
2. Open BetterDisplay from the menu bar.
3. Enable HiDPI or set a custom resolution for the display that needs it.

## Troubleshooting

- Problem: display still looks blurry after enabling HiDPI. Fix: try a
  different scaled resolution from the BetterDisplay list — not every
  custom resolution renders cleanly on every panel.
- Problem: settings reset after sleep/wake. Fix: confirm BetterDisplay is
  set to launch at login so it reapplies settings automatically.

## Dependencies

- None.

## JB Repair Use Cases

- Sharpening text on a client's older external monitor connected to a
  Mac mini.
- Setting up a clean multi-monitor scaling configuration during a desktop
  deployment.

## References

- Official website: https://github.com/waydabber/BetterDisplay
