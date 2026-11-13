// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/foundation.dart';

import '../trace/trace_logger.dart';

/// What a list read answered: the rows it understood AND how many rows it
/// left out because this build does not know a value of theirs (#3884).
/// "Absent" and "present but unreadable" are never the same answer: a caller
/// that shows a total, writes a file or decides on availability reads
/// [unreadable] too.
typedef ReadWithUnreadable<T> = ({T rows, int unreadable});

/// #3884 -- the rows a list could not read, counted where the list is read
/// and said where the list is shown.
///
/// One row with a value this build does not know (a status, a role a newer
/// server sends) used to fail the WHOLE list. Such a row is now left out --
/// never read as a known value it is not -- and recorded here by its [area]
/// (the list it belongs to, e.g. `reservations:<workspace id>`), the read it
/// came from and its id. A read REPLACES what the previous read of the same
/// area and window recorded, so the count describes what is on screen now,
/// not everything ever seen. The screen of the list shows
/// `UnreadableRowsNotice`'s line, and anything that would be wrong without
/// the row (a book's export, a file) refuses or says so instead.
///
/// The trace gets one entry per KIND of unknown value, not one per row.
/// Everything is cleared when the signed-in account changes: the next
/// person on the device never sees the previous person's count.
class UnreadableRows {
  UnreadableRows._();

  static final UnreadableRows instance = UnreadableRows._();

  /// area -> read key -> ids left out by that read.
  final Map<String, Map<String, Set<String>>> _reads = {};
  final Map<String, ValueNotifier<int>> _counts = {};
  final Set<String> _tracedKinds = {};
  final Map<String, String> _scopes = {};
  Object? _account = _noAccount;

  static const Object _noAccount = Object();

  /// The signed-in account is [id]: when it is not the one the counts were
  /// read for, they are forgotten (sign-out, another person on the device).
  void account(String? id) {
    if (_account != _noAccount && _account != id) clear();
    _account = id;
  }

  /// Records what the read [read] of [area] left out: [ids] (with [what],
  /// the unknown value, per id, for the trace). Replaces that read's
  /// previous record, so an empty [ids] clears it. Returns how many rows
  /// this read left out.
  ///
  /// [scope] names what the area is read for (a workspace): a read for
  /// another scope drops the area's reads of the previous one, so a list
  /// never shows another workspace's count.
  int record(
    String area,
    String read,
    Map<String, String> ids, {
    String scope = '',
  }) {
    if (_scopes[area] != scope) _reads[area]?.clear();
    _scopes[area] = scope;
    for (final what in ids.values.toSet()) {
      if (_tracedKinds.add('$area|$what')) {
        TraceLogger.instance.warn(
          area,
          'row left out of its list: unknown $what',
        );
      }
    }
    final reads = _reads.putIfAbsent(area, () => {});
    if (ids.isEmpty) {
      reads.remove(read);
    } else {
      reads[read] = ids.keys.toSet();
    }
    _notifier(area).value = count(area);
    return ids.length;
  }

  /// How many distinct rows of [area] the latest read of each of its
  /// windows left out.
  int count(String area) => {
        for (final ids in (_reads[area] ?? const <String, Set<String>>{}).values)
          ...ids,
      }.length;

  /// The same count, to listen to.
  ValueListenable<int> watch(String area) => _notifier(area);

  ValueNotifier<int> _notifier(String area) =>
      _counts.putIfAbsent(area, () => ValueNotifier<int>(count(area)));

  /// Forgets every count (the account changed or signed out).
  void clear() {
    _reads.clear();
    _scopes.clear();
    _tracedKinds.clear();
    for (final n in _counts.values) {
      n.value = 0;
    }
  }

  /// Forgets everything (tests).
  @visibleForTesting
  void reset() => clear();
}
