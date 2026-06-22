---
title: RustDesk
category: Repair & Diagnostics
package: rustdesk
install_method: Homebrew Cask
keywords: remote, network, remote support, remote desktop
recommended_profiles: all
recommend_reason: Remote-support capability is useful on every technician Mac, independent of hardware model.
website: https://rustdesk.com
---

# RustDesk

## What is it?

Open-source remote desktop application for remote support and
diagnostics, with an optional self-hosted relay server.

## When should I use it?

- Diagnosing or fixing a client's Mac, Windows, or Linux machine
  remotely instead of an on-site visit
- Walking a non-technical client through a fix step by step
- Accessing a bench machine from your own desk without physical access

## Recommended for

- Technicians
- Remote support sessions
- Client troubleshooting without on-site visits

## Useful Commands

No required CLI for normal use — connections are made through the GUI
using a device ID and one-time password. RustDesk does expose a CLI for
advanced/headless setups (e.g. `rustdesk --connect <id>`), but this is
rarely needed for day-to-day support.

## Workflow

1. Install RustDesk on both the technician machine and the client
   machine.
2. On the client machine, read out the device ID and one-time password
   shown in the app.
3. On the technician machine, enter that ID to connect, then the password
   when prompted.
4. For repeat clients, set a permanent password to skip the one-time-code
   step on future visits (with their consent).

## Troubleshooting

- Problem: connection times out. Fix: confirm both machines have internet
  access — RustDesk needs to reach its relay server (or your self-hosted
  one) even though the session itself is direct when possible.
- Problem: client can't find their device ID. Fix: talk them through
  opening the app — the ID is shown in large text on the main screen,
  no login required.
- Problem: connection works but is laggy. Fix: lower the image quality
  setting in RustDesk's display options, especially over the client's
  home Wi-Fi.

## Dependencies

- None for ad-hoc use. A self-hosted relay server is optional for higher
  privacy/performance.

## JB Repair Use Cases

- Remotely diagnosing a client's "my Mac won't connect to Wi-Fi" call
  without a site visit.
- Walking a client through reinstalling a printer driver step by step.
- Accessing a machine left at the shop from a technician's desk to
  continue troubleshooting after hours.

## References

- Official website: https://rustdesk.com
- Official documentation: https://rustdesk.com/docs/en/
