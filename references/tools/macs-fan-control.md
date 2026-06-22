---
title: Macs Fan Control
category: Monitoring
package: macs-fan-control
install_method: Homebrew Cask
keywords: fan, temperature, cooling, sensors, rpm
---

# Macs Fan Control

## What is it?

Utility to monitor temperature sensors and manually control fan speed on
Macs that have fans (MacBook Pro, Mac mini, Mac Studio, iMac).

## When should I use it?

- A client's Mac runs hot or loud under normal use
- You need to confirm whether a fan is spinning at all during a repair
- A desktop Mac needs more aggressive cooling for sustained workloads

## Recommended for

- Technicians
- Hardware repair
- Desktop and MacBook Pro diagnostics

## Useful Commands

No CLI — this is a menu-bar GUI application with live sensor readouts.

## Workflow

1. Open Macs Fan Control and check the current temperature and fan RPM.
2. If a fan reads 0 RPM under load, suspect a hardware fault (dust, dead
   fan, broken connector) rather than software.
3. Optionally set a custom fan curve for sustained heavy workloads.

## Troubleshooting

- Problem: app shows no sensors. Fix: grant the app Full Disk
  Access / accessibility permissions if prompted, and confirm it's not
  blocked by Gatekeeper on first launch.
- Problem: fan stays at 0 RPM even under load. Fix: this points to a
  physical fan or sensor fault — escalate to hardware inspection rather
  than relying on software control.

## Dependencies

- None.

## JB Repair Use Cases

- Confirming a "dead fan" complaint is real before opening the case for a
  physical repair.
- Diagnosing thermal throttling on an aging Mac mini under sustained load.

## References

- Official website: https://crystalidea.com/macs-fan-control
