// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2553 C3 -- whether the app is in front of the person: true while it is
// resumed or only inactive (a system sheet over it), false once hidden,
// paused or detached. Readers pause the work nobody can see and resume it
// once, when the app comes back.
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_foreground.g.dart';

/// [state] seen by the person: resumed, or inactive in front of them.
@visibleForTesting
bool isForeground(AppLifecycleState state) =>
    state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;

/// Whether a widgets binding exists. A pure unit test has none and is in
/// front by definition; the app always has one, so the check only asks in
/// debug builds.
bool _hasBinding() {
  var ready = true;
  assert(() {
    ready = BindingBase.debugBindingType() != null;
    return true;
  }(), 'only debug builds may run without a binding');
  return ready;
}

@riverpod
class AppForeground extends _$AppForeground {
  @override
  bool build() {
    if (!_hasBinding()) return true;
    final listener = AppLifecycleListener(
      onStateChange: (s) => state = isForeground(s),
    );
    ref.onDispose(listener.dispose);
    final initial = WidgetsBinding.instance.lifecycleState;
    // Null before the first transition: just launched, in front.
    return initial == null || isForeground(initial);
  }
}
