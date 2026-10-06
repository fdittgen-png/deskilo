# ADR 0036 — The task recorder makes no video

**Status:** accepted · **Date:** 2026-10-06 · **Supersedes:** 0033

## Context

ADR 0033 had the recorder turn a reviewed storyboard into a captioned
tutorial video through a platform encoder seam (`VideoEncoder`), a native
package (`deskilo_video_encoder`: AVAssetWriter, MediaCodec, WebCodecs with a
bundled Mediabunny muxer), a render job, a frame composer, a caption track and
an Android emulator workflow. It was the heaviest part of the recorder to carry
— a native package on five platforms, a bundled third-party asset with its own
licence, and a CI job — for an output the owner does not use.

## Decision

The task recorder no longer generates a video or a caption track. Removed: the
`lib/features/task_recorder/video/` module, the `deskilo_video_encoder`
package and its Mediabunny asset, the `Mp4OutputGenerator` and
`VttOutputGenerator` registrations, the `TaskOutputKind.video` and `captions`
kinds, their strings in five languages, the integration test and the
`CI · Android video encoder` workflow.

What stays: the recording itself, the task package (whose format still accepts
approved media files), the Word document and the storyboard — the outputs
that need no encoder.

## Consequences

* One native dependency and one third-party asset fewer; the output registry
  lists two generators.
* A video of a task is made outside the app (screen capture); the recording
  and the storyboard are its script.
* The recording-privacy rule (0032) is unchanged: whatever is filmed outside
  the app is filmed with the substitutes on.
