// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1879 — the app side of packages/deskilo_video_encoder's channel.
//
// Capability is DETECTED, never configured: macOS, iOS and Android answer
// on the channel natively, a browser through WebCodecs and the bundled
// muxer (and only where its own H.264 encoder exists); Windows and Linux
// have no encoder in this version and say so before any work starts. A missing plugin, a native
// error or a refused frame becomes a VideoEncoderException carrying an
// ARB reason key — never the native message — and the session is
// cancelled natively before the error reaches the job.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/trace/trace_logger.dart';
import 'video_encoder.dart';

/// Must match `videoEncoderChannel` in packages/deskilo_video_encoder.
const MethodChannel _channel = MethodChannel('deskilo/video_encoder');

/// Whether this build has a native encoder at all.
bool get platformHasVideoEncoder =>
    kIsWeb ||
    (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

String _reason(PlatformException e) => switch (e.code) {
  'unsupported' => 'taskExportVideoUnsupported',
  'too_large' => 'taskExportVideoTooLong',
  _ => 'taskExportVideoFailed',
};

/// The native encoder behind the channel.
class PlatformVideoEncoder implements VideoEncoder {
  const PlatformVideoEncoder();

  @override
  Future<EncoderCapability> probe(VideoSpec spec) async {
    if (!platformHasVideoEncoder) {
      return const EncoderCapability.unsupported('taskExportVideoUnsupported');
    }
    try {
      final answer = await _channel.invokeMapMethod<String, Object?>(
        'probe',
        spec.toMap(),
      );
      return answer?['supported'] == true
          ? const EncoderCapability.supported()
          : const EncoderCapability.unsupported('taskExportVideoUnsupported');
    } on MissingPluginException catch (e, st) {
      TraceLogger.instance.warn(
        'recorder',
        'no video encoder plugin',
        error: e,
        stackTrace: st,
      );
      return const EncoderCapability.unsupported('taskExportVideoUnsupported');
    } on PlatformException catch (e, st) {
      TraceLogger.instance.warn(
        'recorder',
        'video encoder probe failed',
        error: e.code,
        stackTrace: st,
      );
      return EncoderCapability.unsupported(_reason(e));
    }
  }

  @override
  Future<EncoderSession> start(VideoSpec spec) async {
    final id = await _call<int>('start', spec.toMap());
    if (id == null) throw const VideoEncoderException('taskExportVideoFailed');
    return _PlatformSession(id);
  }
}

Future<T?> _call<T>(String method, Map<String, Object> args) async {
  try {
    return await _channel.invokeMethod<T>(method, args);
  } on PlatformException catch (e, st) {
    TraceLogger.instance.warn(
      'recorder',
      'video encoder $method failed',
      error: e.code,
      stackTrace: st,
    );
    throw VideoEncoderException(_reason(e));
  } on MissingPluginException catch (e, st) {
    TraceLogger.instance.warn(
      'recorder',
      'no video encoder plugin',
      error: e,
      stackTrace: st,
    );
    throw const VideoEncoderException('taskExportVideoUnsupported');
  }
}

class _PlatformSession implements EncoderSession {
  _PlatformSession(this.id);
  final int id;

  @override
  Future<void> addFrame(Uint8List rgba, int ptsMs) =>
      _call<void>('addFrame', {'session': id, 'rgba': rgba, 'ptsMs': ptsMs});

  @override
  Future<Uint8List> finish(int endMs) async {
    final bytes = await _call<Uint8List>('finish', {
      'session': id,
      'endMs': endMs,
    });
    if (bytes == null) {
      throw const VideoEncoderException('taskExportVideoFailed');
    }
    return bytes;
  }

  @override
  Future<void> cancel() => _call<void>('cancel', {'session': id});
}
