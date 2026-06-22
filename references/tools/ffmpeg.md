---
title: FFmpeg
category: Multimedia
package: ffmpeg
install_method: Homebrew Formula
keywords: video, audio, convert, compress, multimedia
---

# FFmpeg

## What is it?

Command-line tool for converting, compressing, and editing video and audio
files.

## When should I use it?

- A client sends a video in a format that won't play or upload anywhere
- You need to shrink a screen recording before emailing or uploading it
- You need to pull just the audio out of a video file

## Recommended for

- Technicians
- Power users
- Client deployments involving media files

## Useful Commands

Convert video:

```bash
ffmpeg -i input.mov output.mp4
```
Converts `input.mov` to `output.mp4`, re-encoding as needed so it plays on
virtually any device or platform.

Extract audio:

```bash
ffmpeg -i video.mp4 audio.mp3
```
Pulls the audio track out of `video.mp4` and saves it as `audio.mp3`.

Compress a video:

```bash
ffmpeg -i input.mp4 -vcodec libx264 -crf 28 output.mp4
```
Re-encodes with H.264 at a lower quality/bitrate (`-crf 28`, higher number
= smaller file) — useful for shrinking large screen recordings before
sending them.

Trim a clip:

```bash
ffmpeg -i input.mp4 -ss 00:00:10 -to 00:00:30 -c copy output.mp4
```
Cuts the segment from 10s to 30s without re-encoding (`-c copy`), so it
finishes almost instantly.

## Workflow

1. Confirm the input format with `ffmpeg -i input.ext` (it prints
   container/codec info even without converting).
2. Pick the matching command above for the task (convert, extract audio,
   compress, trim).
3. Always write to a new output filename — FFmpeg will not overwrite the
   source by default and this avoids accidental data loss.

## Troubleshooting

- Problem: "Unknown encoder" error. Fix: the target codec isn't built into
  this FFmpeg build; use a more common codec like `libx264` for video or
  `aac` for audio.
- Problem: output file is huge. Fix: raise the `-crf` value (e.g. 28–32)
  to trade quality for size.
- Problem: command hangs with no output. Fix: confirm the input path is
  correct and quoted if it contains spaces.

## Dependencies

- yt-dlp often feeds FFmpeg for post-processing downloaded media.

## JB Repair Use Cases

- Converting a client's `.mov` screen recording into `.mp4` so it can be
  attached to a support ticket.
- Compressing a large diagnostic video before sending it over email or
  LocalSend.
- Extracting audio from a recorded client call for documentation.

## References

- Official website: https://ffmpeg.org
- Official documentation: https://ffmpeg.org/documentation.html
