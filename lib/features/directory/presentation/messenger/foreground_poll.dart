// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/widgets.dart';

/// A periodic refresh that runs only while its view is shown and the app
/// is in the foreground.
///
/// A [TickerMode] that turns off (a hidden tab, a list under a focused
/// thread) stops animations, not timers: the owner reports it through
/// [setShown]. Hidden or in the background, nothing ticks; shown again,
/// ONE [onResume] catches up instead of the ticks it missed. After
/// [dispose] nothing fires, whatever was pending.
class ForegroundPoll {
  ForegroundPoll({
    required this.period,
    required this.onTick,
    required this.onResume,
  }) {
    _listener = AppLifecycleListener(onStateChange: _lifecycle);
    _restart();
  }

  final Duration period;
  final VoidCallback onTick;
  final VoidCallback onResume;

  late final AppLifecycleListener _listener;
  Timer? _timer;
  bool _shown = true;
  bool _foreground = _isForeground(WidgetsBinding.instance.lifecycleState);
  bool _disposed = false;

  static bool _isForeground(AppLifecycleState? state) =>
      state == null || state == AppLifecycleState.resumed;

  /// Whether the view is read now: shown and in the foreground.
  bool get active => !_disposed && _shown && _foreground;

  /// The view was shown or hidden.
  void setShown({required bool shown}) => _change(shown: shown);

  void _lifecycle(AppLifecycleState state) =>
      _change(foreground: _isForeground(state));

  void _change({bool? shown, bool? foreground}) {
    if (_disposed) return;
    final was = active;
    _shown = shown ?? _shown;
    _foreground = foreground ?? _foreground;
    if (was == active) return;
    _restart();
    // Outside the build that showed the view (never inside it), and
    // only if it is still shown by then.
    if (active) {
      scheduleMicrotask(() {
        if (active) onResume();
      });
    }
  }

  void _restart() {
    _timer?.cancel();
    _timer = active
        ? Timer.periodic(period, (_) {
            if (active) onTick();
          })
        : null;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _listener.dispose();
  }
}
