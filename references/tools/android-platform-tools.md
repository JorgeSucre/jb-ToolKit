---
title: Android Platform Tools
category: Android
package: android-platform-tools
install_method: Homebrew Cask
keywords: android, adb, fastboot, usb debugging, bootloader
---

# Android Platform Tools

## What is it?

Google's official Android command-line tools — `adb` (Android Debug
Bridge) and `fastboot` — for communicating with Android devices over USB
or Wi-Fi.

## When should I use it?

- A client's Android device needs file access, app installs/uninstalls,
  or log inspection over USB
- A device is stuck in a boot loop and needs a `fastboot` recovery
  command
- Scrcpy needs `adb` available to mirror or control a device

## Recommended for

- Technicians
- Android device diagnostics

## Useful Commands

```bash
adb devices
```
Lists Android devices currently connected and authorized over USB/Wi-Fi.
Required first step before any other `adb` command will work.

```bash
adb shell
```
Opens an interactive shell on the connected device for direct
inspection.

```bash
adb install app.apk
```
Installs an APK file directly onto the connected device.

```bash
fastboot devices
```
Lists devices in fastboot (bootloader) mode — used for flashing or
recovery when a device won't boot normally.

## Workflow

1. Enable Developer Options and USB Debugging on the Android device.
2. Connect via USB and accept the "Allow USB debugging" prompt on the
   device screen.
3. Confirm the connection with `adb devices` before running further
   commands.

## Troubleshooting

- Problem: `adb devices` shows nothing. Fix: check the USB cable supports
  data (not charge-only), and confirm USB debugging is enabled on the
  device.
- Problem: device shows as "unauthorized". Fix: look at the device screen
  for the debugging confirmation prompt and accept it.
- Problem: `fastboot` doesn't see the device. Fix: confirm the device is
  actually in bootloader mode (varies by manufacturer key combo).

## Dependencies

- Required by Scrcpy for device mirroring.

## JB Repair Use Cases

- Pulling diagnostic logs off a client's Android phone before a repair.
- Sideloading an APK that isn't available on the Play Store for a client.
- Using `fastboot` to assist recovery on a device stuck in a boot loop.

## References

- Official website: https://developer.android.com/tools/releases/platform-tools
- Official documentation: https://developer.android.com/tools/adb
