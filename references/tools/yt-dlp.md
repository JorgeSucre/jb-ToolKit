---
title: yt-dlp
category: Multimedia
package: yt-dlp
install_method: Homebrew Formula
keywords: video, audio, download, multimedia
---

# yt-dlp

## What is it?

Command-line downloader for video and audio from YouTube and hundreds of
other sites.

## When should I use it?

- A client needs a local copy of a video (e.g. a tutorial they were sent)
  for offline use
- You need just the audio track of an online video, not the full video
- A streamed recording needs to be archived locally for documentation

## Recommended for

- Technicians
- Power users

## Useful Commands

```bash
yt-dlp URL
```
Downloads the video at the given URL in the best available quality.

```bash
yt-dlp -x URL
```
Downloads and extracts audio only (`-x`), converting it to an audio
format automatically.

```bash
yt-dlp -f "bestvideo[height<=720]+bestaudio" URL
```
Caps the downloaded resolution at 720p, useful for saving space or
bandwidth on a slow client connection.

```bash
yt-dlp -o "%(title)s.%(ext)s" URL
```
Saves the file using the video's title as the filename instead of a URL
fragment.

## Workflow

1. Confirm `ffmpeg` is installed — yt-dlp uses it for merging/extracting
   audio and video streams.
2. Run the appropriate command above for the task (full video, audio
   only, capped resolution).
3. Check the output filename printed at the end of the download.

## Troubleshooting

- Problem: "ERROR: Unsupported URL". Fix: the site isn't supported, or the
  tool needs an update — run `brew upgrade yt-dlp`, sites change frequently.
- Problem: audio extraction fails. Fix: confirm `ffmpeg` is installed,
  since `-x` depends on it for conversion.
- Problem: download is very slow. Fix: cap the resolution with `-f` to
  avoid pulling a 4K stream when it isn't needed.

## Dependencies

- FFmpeg (required for audio extraction and stream merging)

## JB Repair Use Cases

- Saving a manufacturer's repair tutorial locally so it's available
  offline at the bench.
- Pulling the audio from a recorded client walkthrough for documentation.
- Archiving a vendor's product demo video referenced in a support ticket.

## References

- Official website: https://github.com/yt-dlp/yt-dlp
- Official documentation: https://github.com/yt-dlp/yt-dlp#usage-and-options
