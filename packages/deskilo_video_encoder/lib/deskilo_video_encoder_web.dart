// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1879 — the browser half of the encoder channel.
//
// Registers a handler for the same channel protocol the native halves
// answer (see deskilo_video_encoder.dart), backed by assets/encoder.mjs:
// the browser's WebCodecs H.264 encoder and the bundled Mediabunny muxer.
// The module is imported from the app's own assets on first use, so a
// generation needs no network. probe() answers false where WebCodecs or
// an H.264 encoder is missing; it never claims what it cannot do.
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

@JS()
extension type _Encoder._(JSObject _) implements JSObject {
  external JSPromise<JSBoolean> probe(JSNumber w, JSNumber h, JSNumber bitrate);
  external JSPromise<JSNumber> start(
    JSNumber w,
    JSNumber h,
    JSNumber bitrate,
    JSNumber keyframeMs,
  );
  external JSPromise<JSAny?> addFrame(
    JSNumber id,
    JSUint8Array rgba,
    JSNumber ptsMs,
  );
  external JSPromise<JSUint8Array> finish(JSNumber id, JSNumber endMs);
  external JSPromise<JSAny?> cancel(JSNumber id);
}

class DeskiloVideoEncoderWeb {
  static void registerWith(Registrar registrar) {
    final channel = MethodChannel(
      'deskilo/video_encoder',
      const StandardMethodCodec(),
      registrar,
    );
    channel.setMethodCallHandler(DeskiloVideoEncoderWeb()._handle);
    // The bundled muxer's licence, shown with every other licence.
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks(
        const ['mediabunny'],
        await rootBundle.loadString(
          'packages/deskilo_video_encoder/assets/MEDIABUNNY_LICENSE',
        ),
      );
    });
  }

  Future<_Encoder>? _module;

  Future<_Encoder> _encoder() => _module ??= () async {
    final path = ui_web.assetManager.getAssetUrl(
      'packages/deskilo_video_encoder/assets/encoder.mjs',
    );
    final url = Uri.base.resolve(path).toString();
    return (await importModule(url.toJS).toDart) as _Encoder;
  }();

  int _int(Map<Object?, Object?> a, String k) => (a[k] as num?)?.toInt() ?? 0;

  Future<Object?> _handle(MethodCall call) async {
    final a = (call.arguments as Map<Object?, Object?>?) ?? const {};
    final Map<Object?, Object?> args = a;
    try {
      final e = await _encoder();
      switch (call.method) {
        case 'probe':
          final ok =
              (await e
                      .probe(
                        _int(args, 'width').toJS,
                        _int(args, 'height').toJS,
                        _int(args, 'bitrate').toJS,
                      )
                      .toDart)
                  .toDart;
          return {'supported': ok, 'reason': ok ? null : 'unsupported'};
        case 'start':
          return (await e
                  .start(
                    _int(args, 'width').toJS,
                    _int(args, 'height').toJS,
                    _int(args, 'bitrate').toJS,
                    _int(args, 'keyframeIntervalMs').toJS,
                  )
                  .toDart)
              .toDartInt;
        case 'addFrame':
          final rgba = args['rgba'];
          if (rgba is! Uint8List) {
            throw PlatformException(code: 'bad_args');
          }
          await e
              .addFrame(
                _int(args, 'session').toJS,
                rgba.toJS,
                _int(args, 'ptsMs').toJS,
              )
              .toDart;
          return null;
        case 'finish':
          return (await e
                  .finish(_int(args, 'session').toJS, _int(args, 'endMs').toJS)
                  .toDart)
              .toDart;
        case 'cancel':
          await e.cancel(_int(args, 'session').toJS).toDart;
          return null;
      }
      throw MissingPluginException(call.method);
    } on PlatformException {
      rethrow;
    } on MissingPluginException {
      rethrow;
    } catch (e) {
      // Only a code leaves: the browser's own message is not passed on.
      debugPrint('video encoder ${call.method} failed: ${e.runtimeType}');
      throw PlatformException(
        code: call.method == 'probe' ? 'unsupported' : 'encode_failed',
      );
    }
  }
}
