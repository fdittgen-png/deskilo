// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3913 — a bank list read past a row this build cannot read: the row is
// left out, counted under its list's area (`UnreadableRows`) and said under
// the list, never read as a value it is not, and one such row no longer
// fails the whole list.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;

import '../../../core/data/unreadable_rows.dart';

/// The rows of [rows] [read] understands (a null from [read] is a row it
/// does not), the others left out and recorded under [area] for the read
/// [key] (the row's id and the [what] it did not know).
List<T> readableBankRows<T>(
  Object? rows,
  T? Function(Object? row) read, {
  required String area,
  required String key,
  required String what,
}) {
  final left = <String, String>{};
  final kept = <T>[];
  for (final row in rows is List ? rows : const <Object?>[]) {
    final value = read(row);
    if (value != null) {
      kept.add(value);
    } else {
      final r = JsonReader.of(row, context: 'bank');
      left[r.stringOr('id')] = '$what ${r.stringOr(what)}';
    }
  }
  UnreadableRows.instance.record(area, key, left, scope: key);
  return kept;
}
