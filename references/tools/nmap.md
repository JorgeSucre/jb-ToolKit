---
title: Nmap
category: Networking
package: nmap
install_method: Homebrew Formula
keywords: network, scan, port, subnet, host discovery
recommended_profiles: all
recommend_reason: Essential for diagnosing any network issue at a client site, regardless of the Mac model.
website: https://nmap.org
---

# Nmap

## What is it?

Network scanner used to discover hosts, open ports, and services on a
network.

## When should I use it?

- A client reports "the network is slow" or "a device won't connect"
- You need to find the IP address of a printer, NAS, or router on-site
- You need to confirm whether a service (SSH, SMB, a web admin panel) is
  actually reachable before troubleshooting further

## Recommended for

- Technicians
- Network troubleshooting
- Remote support

## Useful Commands

```bash
nmap 192.168.1.0/24
```
Scans every address in the `192.168.1.0/24` subnet and lists hosts that
respond, with their open ports.

```bash
nmap -A 192.168.1.100
```
Runs an aggressive scan against a single host: OS detection, service
version detection, and basic script scanning. Useful for identifying
exactly what is running on a device (e.g. a NAS or IoT device).

```bash
nmap -p 1-65535 192.168.1.100
```
Scans every TCP port on a single host instead of the default top-1000,
useful when a service is running on a nonstandard port.

```bash
nmap -sn 192.168.1.0/24
```
Ping-only sweep (no port scan). Fastest way to build a list of live hosts
on a subnet.

## Workflow

1. Identify the subnet of the client network (check the Mac's own IP via
   `ifconfig` or System Settings → Network).
2. Run `nmap -sn <subnet>` to get a quick list of live hosts.
3. Run `nmap -A <target>` against the specific host you need to inspect.
4. Cross-reference open ports against the service the client expects
   (e.g. port 9100 for a network printer, 445 for SMB file sharing).

## Troubleshooting

- Problem: scan returns no hosts at all. Fix: confirm the Mac is on the
  same subnet/VLAN as the target, and that the client's router/firewall
  doesn't block ICMP — retry with `-Pn` to skip the host-discovery ping.
- Problem: scan is very slow. Fix: narrow the port range with `-p` or scan
  a smaller subnet instead of a full `/24` sweep.
- Problem: "Permission denied" or incomplete results. Fix: some scan types
  (like `-O` OS detection inside `-A`) need elevated privileges; run with
  `sudo nmap -A ...`.

## Dependencies

- None. Works standalone.

## JB Repair Use Cases

- Locating a misconfigured printer's IP address on a client's office
  network before reinstalling drivers.
- Confirming a client's NAS is actually reachable before troubleshooting
  a "files not syncing" complaint.
- Verifying that a port a piece of software needs (e.g. a remote-support
  agent) isn't being blocked by the client's router.

## References

- Official website: https://nmap.org
- Official documentation: https://nmap.org/book/man.html
