// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'app_durations.dart';

/// Runs the last of a burst of calls once the burst settles (#2388) — the
/// `Timer? _debounce; _debounce?.cancel(); _debounce = Timer(…)` every
/// search field used to write for itself. The owner disposes it.
class Debouncer {
  Debouncer({this.delay = AppDurations.searchDebounce});

  final Duration delay;
  Timer? _timer;

  /// Runs [action] after [delay], unless another call comes first.
  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Drops a pending run; the owner calls it from `dispose`.
  void dispose() => _timer?.cancel();
}
