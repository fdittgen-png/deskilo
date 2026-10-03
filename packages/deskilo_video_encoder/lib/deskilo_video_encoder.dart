// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1879 — the channel the native encoders answer on.
//
// The app's adapter (lib/features/task_recorder/video/
// platform_video_encoder.dart) speaks this protocol; this package only
// carries the native halves. Methods, all on [videoEncoderChannel]:
//
//   probe   {width, height, bitrate}            -> {supported, reason?}
//   start   {width, height, bitrate,
//            keyframeIntervalMs}                -> session id (int)
//   addFrame{session, rgba (Uint8List,
//            width*height*4), ptsMs}            -> null once accepted
//   finish  {session, endMs}                    -> Uint8List (the MP4)
//   cancel  {session}                           -> null once released
//
// Errors are PlatformExceptions whose code is one of [encoderErrorCodes];
// their messages never carry frame content. Every temporary file is
// created by the session that owns it and deleted by finish or cancel.
library;

/// The method channel name.
const String videoEncoderChannel = 'deskilo/video_encoder';

/// The error codes the native side may answer with.
const Set<String> encoderErrorCodes = {
  'unsupported',
  'bad_args',
  'no_session',
  'encode_failed',
  'finalize_failed',
  'too_large',
};
