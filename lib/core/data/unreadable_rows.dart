// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/foundation.dart';

import '../trace/trace_logger.dart';

/// #3884 -- the rows a list could not read, counted where the list is read
/// and said where the list is shown.
///
/// One row with a value this build does not know (a status, a role a newer
/// server sends) used to fail the WHOLE list. Such a row is now left out --
/// never read as a known value it is not -- and recorded here by its [area]
/// (the list it belongs to, e.g. `reservations:<workspace id>`) and its id.
/// The list's screen shows `UnreadableRowsNotice`'s line, and anything that
/// would be wrong without the row (a book's export) refuses instead.
///
/// The trace gets one entry per KIND of unknown value, not one per row.
/// A row counts once however often the list is read again.
class UnreadableRows {
  UnreadableRows._();

  static final UnreadableRows instance = UnreadableRows._();

  final Map<String, Set<String>> _ids = {};
  final Map<String, ValueNotifier<int>> _counts = {};
  final Set<String> _tracedKinds = {};

  /// Leaves [rowId] of [area] out of its list because of [what] (the
  /// unknown value, e.g. `reservation status future_state`).
  void skip(String area, String rowId, {required String what}) {
    if (_tracedKinds.add('$area|$what')) {
      TraceLogger.instance.warn(
        area,
        'row left out of its list: unknown $what',
      );
    }
    final ids = _ids.putIfAbsent(area, () => <String>{});
    if (ids.add(rowId)) _notifier(area).value = ids.length;
  }

  /// How many distinct rows of [area] were left out so far.
  int count(String area) => _ids[area]?.length ?? 0;

  /// The same count, to listen to.
  ValueListenable<int> watch(String area) => _notifier(area);

  ValueNotifier<int> _notifier(String area) =>
      _counts.putIfAbsent(area, () => ValueNotifier<int>(count(area)));

  /// Forgets everything (tests).
  @visibleForTesting
  void reset() {
    _ids.clear();
    _tracedKinds.clear();
    for (final n in _counts.values) {
      n.value = 0;
    }
  }
}
