---
title: LocalSend
category: Utilities
package: localsend
install_method: Homebrew Cask
keywords: file transfer, peer to peer, offline transfer, lan sharing
recommended_profiles: all
recommend_reason: Local, offline file transfer is useful for any technician Mac, regardless of model.
website: https://localsend.org
---

# LocalSend

## What is it?

Peer-to-peer file transfer over the local network, without internet,
accounts, or cloud storage.

## When should I use it?

- Moving files between two Macs, or between a Mac and a client's
  Windows/Android/iOS device, without email size limits
- A client site has no usable internet but devices share the same
  network/hotspot
- Transferring sensitive files without uploading them to a third party

## Recommended for

- Technicians
- Mac and cross-platform file transfers
- Client deployments

## Useful Commands

No CLI — LocalSend is a GUI app. Both devices must be on the same local
network (including a phone hotspot if no other network is available).

## Workflow

1. Open LocalSend on both the sending and receiving device.
2. On the sender, select the file(s) and choose the receiving device from
   the discovered list.
3. Accept the incoming transfer on the receiving device.

## Troubleshooting

- Problem: devices don't see each other. Fix: confirm both are on the
  same Wi-Fi network/subnet — guest networks and client isolation on some
  routers block local discovery.
- Problem: transfer is slow. Fix: confirm both devices are on the same
  band (5GHz vs 2.4GHz Wi-Fi) — mismatched bands and weak signal both hurt
  local-network throughput.
- Problem: firewall blocks discovery on macOS. Fix: allow LocalSend
  through the firewall in System Settings → Network → Firewall.

## Dependencies

- None.

## JB Repair Use Cases

- Moving a client backup from an old Mac to a new one during a
  migration, with no internet required.
- Transferring diagnostic logs or a session report between a technician's
  laptop and the shop's main machine.
- Sending an installer or driver package to a client machine at a site
  with no usable internet connection.

## References

- Official website: https://localsend.org
- Official documentation: https://github.com/localsend/localsend/wiki
