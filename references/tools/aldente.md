---
title: AlDente
category: Monitoring
package: aldente
install_method: Homebrew Cask
keywords: battery, charge limit, laptop, power
---

# AlDente

## What is it?

Battery-charge limiter for MacBooks. Stops charging at a configurable
percentage to slow long-term battery wear.

## When should I use it?

- A laptop stays plugged in at a desk most of the day (common for
  technicians' own machines and many client setups)
- A client complains about reduced battery health/cycle count over time

## Recommended for

- Technicians
- MacBook users who keep their laptop plugged in often

## Useful Commands

No command-line interface — AlDente is a menu-bar GUI application.

## Workflow

1. Install and open AlDente from the menu bar.
2. Set a charge limit (commonly 80%) for daily plugged-in use.
3. Optionally enable "Top-up" mode before travel to charge fully on
   demand.

## Troubleshooting

- Problem: battery still charges to 100%. Fix: confirm the limit is
  enabled in the AlDente menu, not just configured — some macOS updates
  can reset background helper permissions.
- Problem: app doesn't appear after install. Fix: check
  System Settings → Privacy & Security and approve the AlDente system
  extension.

## Dependencies

- None.

## JB Repair Use Cases

- Recommending it to a client whose MacBook lives on a desk plugged in
  permanently, to extend battery lifespan.
- Installing it as a standard part of MacBook Air/Pro setups during
  Initial Setup.

## References

- Official website: https://aldente.macupdate.com
