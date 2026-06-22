---
title: iPerf3
category: Networking
package: iperf3
install_method: Homebrew Formula
keywords: network, bandwidth, speed, throughput, wifi
---

# iPerf3

## What is it?

Active network bandwidth measurement tool — measures real throughput
between two points, unlike a simple ping.

## When should I use it?

- A client reports "slow Wi-Fi" or "slow network" and you need a real
  number, not a guess
- Comparing throughput between Wi-Fi and a wired connection on the same
  machine
- Verifying a network upgrade (new router, new switch, new cabling)
  actually improved speed

## Recommended for

- Technicians
- Network troubleshooting

## Useful Commands

```bash
iperf3 -s
```
Starts iPerf3 in server mode on one machine (e.g. a laptop connected via
Ethernet at the router).

```bash
iperf3 -c 192.168.1.50
```
Connects as a client to the server at `192.168.1.50` and runs a bandwidth
test, printing throughput in Mbits/sec.

```bash
iperf3 -c 192.168.1.50 -t 30
```
Runs the test for 30 seconds instead of the default 10, useful for
catching intermittent slowdowns.

```bash
iperf3 -c 192.168.1.50 -R
```
Runs the test in reverse mode (server sends to client) — useful for
testing download vs. upload separately.

## Workflow

1. Pick a stable machine to act as the server (ideally wired) and run
   `iperf3 -s`.
2. From the machine being tested, run `iperf3 -c <server-ip>`.
3. Repeat over Wi-Fi and Ethernet to compare, and with `-R` to check both
   directions.

## Troubleshooting

- Problem: client can't connect to server. Fix: confirm both machines are
  on the same network and that the client's firewall isn't blocking port
  5201 (iPerf3's default).
- Problem: results look capped at a suspiciously round number. Fix: that
  is often the actual link speed (e.g. a 100 Mbps switch port) — confirm
  the physical link speed on both ends.

## Dependencies

- Nmap is useful beforehand to confirm the target IP is reachable.

## JB Repair Use Cases

- Proving to a client that their "slow internet" is actually a local
  Wi-Fi throughput problem, not an ISP issue.
- Validating a network upgrade actually delivered the promised speed
  increase.

## References

- Official website: https://iperf.fr
- Official documentation: https://iperf.fr/iperf-doc.php
