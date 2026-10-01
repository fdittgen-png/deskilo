// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../trace/trace_logger.dart';
import 'capture_web_stub.dart'
    if (dart.library.js_interop) 'capture_web_web.dart';

/// What the platform reported about the screen while a thread is open.
enum CaptureSignal {
  /// iOS: the person took a screenshot (it cannot be prevented there,
  /// only announced).
  screenshot,

  /// iOS: the screen started being recorded, mirrored or AirPlayed.
  recordingStarted,

  /// iOS: it stopped.
  recordingStopped,
}

/// #1824 — screen-capture protection for the messenger, one seam for
/// every platform.
///
/// The Dart side speaks ONE method channel, `deskilo/capture`:
///
/// | direction | method | meaning |
/// |---|---|---|
/// | Dart → native | `enable` | protect the window; answers whether the screen is being captured right now |
/// | Dart → native | `disable` | stop protecting it |
/// | native → Dart | `screenshot` | a screenshot was taken (iOS) |
/// | native → Dart | `captured` | `true`/`false`: recording or mirroring started/stopped (iOS) |
///
/// What each runner does with `enable`: Android sets `FLAG_SECURE`,
/// macOS sets `sharingType = .none`, Windows calls
/// `SetWindowDisplayAffinity(WDA_EXCLUDEFROMCAPTURE)`, iOS starts
/// observing captures and blurs its app-switcher snapshot. The web has no
/// channel: [obscured] reports when the page stops being looked at.
///
/// Several threads may be open at once (a sheet over a page), so the
/// window is protected while at least one of them holds it: [enable]
/// and [disable] count, and only the first and the last reach the
/// platform.
class CaptureProtection {
  CaptureProtection({
    this.channel = const MethodChannel(channelName),
    bool? web,
    this.webObscured,
  }) : _web = web ?? kIsWeb,
       _inert = false {
    if (!_web) channel.setMethodCallHandler(_onCall);
  }

  /// A protection that never reaches a platform — tests and Demo, where
  /// no window exists to protect.
  CaptureProtection.inert()
    : channel = const MethodChannel(channelName),
      _web = false,
      webObscured = null,
      _inert = true;

  static const String channelName = 'deskilo/capture';

  /// A platform that hangs must not leave a thread half-protected with
  /// a spinner; a bounded call turns the hang into a traced failure.
  static const Duration callTimeout = Duration(seconds: 5);

  final MethodChannel channel;
  final bool _web;

  /// The web's obscured signal; the real page events when null.
  final Stream<bool>? webObscured;
  final bool _inert;
  int _holders = 0;
  bool _captured = false;
  final _signals = StreamController<CaptureSignal>.broadcast();

  /// How many open threads hold the protection.
  int get holders => _holders;

  /// Whether the screen is being recorded or mirrored (iOS) right now.
  bool get captured => _captured;

  /// Whether this platform can refuse a screenshot outright. The web
  /// cannot, and the thread says so in its header.
  bool get canBlock => !_web;

  Stream<CaptureSignal> get signals => _signals.stream;

  /// The web's "nobody is looking at this page" (true) and "looked at
  /// again" (false). Empty everywhere else.
  Stream<bool> get obscured =>
      _web ? (webObscured ?? webObscuredChanges()) : const Stream.empty();

  Future<void> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'screenshot':
        _signals.add(CaptureSignal.screenshot);
      case 'captured':
        _setCaptured(call.arguments == true);
    }
  }

  void _setCaptured(bool value) {
    if (value == _captured) return;
    _captured = value;
    _signals.add(
      value ? CaptureSignal.recordingStarted : CaptureSignal.recordingStopped,
    );
  }

  Future<void> enable() async {
    _holders++;
    if (_holders != 1) return;
    final answer = await _invoke('enable');
    if (answer is bool) _setCaptured(answer);
  }

  Future<void> disable() async {
    if (_holders == 0) return;
    _holders--;
    if (_holders != 0) return;
    await _invoke('disable');
    _setCaptured(false);
  }

  Future<Object?> _invoke(String method) async {
    if (_web || _inert) return null;
    try {
      return await channel.invokeMethod<Object?>(method).timeout(callTimeout);
    } on MissingPluginException catch (e, st) {
      // A runner without the channel (Linux, a test binding): nothing
      // to protect with, which is not an error of the thread.
      TraceLogger.instance.warn(
        'capture',
        'capture $method: no platform channel',
        error: e,
        stackTrace: st,
      );
    } catch (e, st) {
      TraceLogger.instance.error(
        'capture',
        'capture $method failed',
        error: e,
        stackTrace: st,
      );
    }
    return null;
  }
}
