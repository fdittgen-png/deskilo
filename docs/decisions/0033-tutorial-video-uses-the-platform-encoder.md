# ADR 0033 — A tutorial video is encoded by the platform's own H.264 encoder

**Status:** superseded by [ADR 0036](0036-the-task-recorder-makes-no-video.md) · **Date:** 2026-10-02 · **Issues:** #1879 (this), #1876 (the storyboard it renders), #1981 (the recorder epic)

## Context

The task recorder turns a reviewed storyboard into a captioned tutorial
video that is saved on the person's own device. The video must be a
real, broadly playable file, made offline, with no cloud service and
nothing private in it. The candidates were a bundled FFmpeg (FFmpegKit
is archived; a fork is not maintained by anyone we can rely on, and
FFmpeg's codecs carry licences of their own), a pure-Dart H.264 encoder
(none is mature; writing one is out of scope) and the encoders each
platform already ships.

## Decision

One small seam (`VideoEncoder` / `EncoderSession` in
`lib/features/task_recorder/video/video_encoder.dart`) over one method
channel, answered by the platform's own encoder:

| Target | Encoder | Container |
|---|---|---|
| macOS, iOS | AVAssetWriter, H.264 | MP4 |
| Android | MediaCodec (`video/avc`) | MediaMuxer MP4 |
| Web | WebCodecs `VideoEncoder` (`avc`) | Mediabunny 1.61.0, bundled |
| Windows, Linux | none in this version: the capability probe says so before any work | — |

The app draws every frame itself (the storyboard's renderer), streams
raw RGBA frames one at a time and awaits each (backpressure), and the
platform side finalizes the container and deletes its own temporary
file before it answers. No audio track: narration is not offered in
this version.

**Mediabunny** (MPL-2.0, `packages/deskilo_video_encoder/assets/`,
licence beside it, npm tarball sha256
`2105c960b161cbfcba037c91527e73b89d5208e92d6fb64a14000e7addbe1a8f`) is
used only on the web, only as the MP4 muxer around the browser's own
encoder: WebCodecs produces encoded chunks, not a file. It ships in the
app's assets, so nothing is fetched when a video is made; the file is
unmodified, so the MPL obligation is met by keeping it and its licence
as they are.

## Consequences

- No FFmpeg, no third-party codec, no Play services: the F-Droid build
  carries the plugin unchanged.
- Support is detected, never configured: no feature flag. Where the
  probe answers no, the person is told to export the recording file and
  open it on a supported device.
- The bundled muxer adds about 0.7 MB to every build, because package
  assets are not per-platform.
- A new target means a new answer on the same channel, not a new
  renderer: the frames are the same everywhere.
