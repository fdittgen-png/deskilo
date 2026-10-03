// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1879 — the one small encoder seam.
//
// A platform encoder takes raw RGBA frames with presentation times and
// produces ONE finished MP4 (H.264, no audio track). The seam is
// deliberately narrow: frames go in one at a time and each addFrame
// completes only when the encoder accepted it (backpressure), cancel
// completes only when the encoder released its resources and deleted the
// temporary file it owned, and finish returns the bytes only after the
// container was finalized. Native implementations live in
// packages/deskilo_video_encoder (AVAssetWriter on macOS/iOS,
// MediaCodec + MediaMuxer on Android); a platform without one says so in
// [VideoEncoder.probe] instead of failing late.
import 'dart:typed_data';

/// What is asked of the encoder.
class VideoSpec {
  const VideoSpec({
    required this.width,
    required this.height,
    this.bitrate = 2000000,
    this.keyframeIntervalMs = 2000,
  });

  final int width;
  final int height;
  final int bitrate;
  final int keyframeIntervalMs;

  Map<String, Object> toMap() => {
    'width': width,
    'height': height,
    'bitrate': bitrate,
    'keyframeIntervalMs': keyframeIntervalMs,
  };
}

/// Whether this runtime can encode [VideoSpec]; [reasonKey] (an ARB key)
/// when it cannot.
class EncoderCapability {
  const EncoderCapability.supported() : supported = true, reasonKey = null;
  const EncoderCapability.unsupported(this.reasonKey) : supported = false;

  final bool supported;
  final String? reasonKey;
}

/// An encoder failure. Carries a reason key, never a native message.
class VideoEncoderException implements Exception {
  const VideoEncoderException(this.reasonKey);

  final String reasonKey;

  @override
  String toString() => 'VideoEncoderException($reasonKey)';
}

/// A platform's encoder.
abstract interface class VideoEncoder {
  Future<EncoderCapability> probe(VideoSpec spec);

  /// Starts one encode. Throws [VideoEncoderException].
  Future<EncoderSession> start(VideoSpec spec);
}

/// One running encode.
abstract interface class EncoderSession {
  /// Appends a frame of `width * height * 4` RGBA bytes at [ptsMs].
  /// Completes when the encoder took it.
  Future<void> addFrame(Uint8List rgba, int ptsMs);

  /// Finalizes the container ending at [endMs] and returns its bytes.
  Future<Uint8List> finish(int endMs);

  /// Stops, releases the encoder and deletes the partial file. Completes
  /// only once that is done.
  Future<void> cancel();
}
