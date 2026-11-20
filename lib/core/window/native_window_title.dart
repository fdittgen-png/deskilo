// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../trace/trace_logger.dart';

/// #3621 — the program window's title, sent to the runner.
///
/// Flutter's `Title` names a browser tab and the app switcher; the Windows
/// runner names its window once and has no way to follow the page. This is the
/// one channel it listens on, `deskilo/window`, method `setTitle` with the
/// whole title. A platform without the handler (every other one, today) is
/// left alone: nothing is sent where it is not heard.
class NativeWindowTitle {
  NativeWindowTitle({
    this.channel = const MethodChannel(channelName),
    bool Function()? supported,
  }) : _supported = supported ?? _runnerListens;

  static const String channelName = 'deskilo/window';

  final MethodChannel channel;
  final bool Function() _supported;
  String? _last;

  static bool _runnerListens() =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// Tells the runner [title], once per change.
  Future<void> set(String title) async {
    if (!_supported() || title == _last) return;
    _last = title;
    try {
      await channel.invokeMethod<void>('setTitle', title);
    } on MissingPluginException {
      // trace-exempt: a runner that does not listen is a runner without a
      // title channel (an older build); the title stays as the runner named it.
      return;
    } on Object catch (e, st) {
      TraceLogger.instance.error(
        'window',
        'setTitle failed',
        error: e,
        stackTrace: st,
      );
    }
  }
}

/// The app's one window-title sender; a test overrides it.
final nativeWindowTitleProvider = Provider<NativeWindowTitle>(
  (ref) => NativeWindowTitle(),
);
