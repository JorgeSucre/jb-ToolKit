---
title: Scrcpy
category: Android
package: scrcpy
install_method: Homebrew Formula
keywords: android, mirror, mirroring, screen, adb
website: https://github.com/Genymobile/scrcpy
---

# Scrcpy

## What is it?

Displays and controls an Android device's screen from the Mac over USB or
Wi-Fi, with no app installation required on the Android device itself.

## When should I use it?

- Demonstrating or performing a fix on a client's Android device from the
  Mac
- Recording or screenshotting an Android device's screen for a report
- Controlling a device with a cracked or unresponsive touchscreen

## Recommended for

- Technicians
- Android device diagnostics
- Client deployments involving Android hardware

## Useful Commands

```bash
adb devices
```
Confirms the Android device is connected and authorized before starting
Scrcpy — Scrcpy relies on `adb` (Android Platform Tools) under the hood.

```bash
scrcpy
```
Starts mirroring the first connected device's screen in a window, with
mouse/keyboard control passed through.

```bash
scrcpy --record screen.mp4
```
Mirrors the device as usual while also recording the session to
`screen.mp4` — useful for documenting a fix or a reported bug.

```bash
scrcpy -s <device-serial>
```
Targets a specific device by serial number when more than one is
connected (get the serial from `adb devices`).

## Workflow

1. Enable Developer Options and USB Debugging on the Android device.
2. Connect via USB and run `adb devices` to confirm it's authorized.
3. Run `scrcpy` to start mirroring; add `--record <file>.mp4` if the
   session needs to be documented.

## Troubleshooting

- Problem: "no devices/emulators found". Fix: run `adb devices` first —
  if it's also empty, the USB/debugging setup needs fixing before Scrcpy
  can work.
- Problem: control works but is laggy. Fix: try a USB connection instead
  of Wi-Fi, or lower the bitrate with `scrcpy -b 2M`.
- Problem: screen stays black. Fix: some manufacturers require the
  device to be unlocked once after connecting before mirroring starts.

## Dependencies

- Android Platform Tools (`adb`) — required.

## JB Repair Use Cases

- Demonstrating a settings fix on a client's Android phone directly from
  the Mac, without needing to handle the device hands-on.
- Recording a screen capture of a reproducible app crash for a vendor
  support ticket.
- Controlling an Android device with a broken touchscreen well enough to
  back up data before repair.

## References

- Official website: https://github.com/Genymobile/scrcpy
- Official documentation: https://github.com/Genymobile/scrcpy/blob/master/README.md
