// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:intl/intl.dart';

import 'app_format.dart';

/// #3819 — the "when" of a reference label (who · space · when) that a
/// message or a picker row carries.
///
/// With no [reader] the label is BAKED into a message for other readers:
/// day and time in the reference language's own convention ([locale], the
/// workspace's), never the sender's clock preference. A 12-hour sender in a
/// 24-hour workspace must not freeze `2:30 PM` into a line every
/// participant reads. This is the one place that convention is chosen (it
/// is pinned in `format_boundary_test.dart` with that reason).
///
/// With a [reader] the label is only for THIS person (a picker's row): the
/// day in the locale's form, the time on the person's own clock.
String referenceWhen(DateTime at, String? locale, {AppFormat? reader}) {
  final wall = at.toLocal();
  if (reader == null) return DateFormat.MMMd(locale).add_jm().format(wall);
  return '${DateFormat.MMMd(reader.locale).format(wall)}, '
      '${reader.wallTime(wall)}';
}
