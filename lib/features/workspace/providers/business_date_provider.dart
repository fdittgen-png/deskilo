// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3659 (i18n I13) -- the calendar day of an instant on the active business's
// own calendar, read from its captured context (#2561 L4), not from the
// process-wide static. Renewed at the business's midnight and on resume
// (`businessTodayProvider`), so a reader that decides "today" with it moves
// to the next day with no data change. Until the context is read there is
// no business calendar yet: the device's date stands in for that moment
// only, as it did before.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/business_day_providers.dart';
import '../../../core/time/workspace_calendar.dart';
import 'operation_context_providers.dart';

/// An instant's day on the active business's calendar.
final businessDateOfProvider = Provider<DateTime Function(DateTime instant)>((
  ref,
) {
  final calendar = ref.watch(readyWorkspaceContextProvider)?.calendar;
  if (calendar == null) {
    return (t) {
      final local = t.toLocal();
      return DateTime(local.year, local.month, local.day);
    };
  }
  ref.watch(businessTodayProvider(calendar.timezone));
  // A new value on every rebuild, so its readers rebuild with it.
  return _Dates(calendar).dateOf;
});

/// One read of [calendar]: its tear-off differs from the last build's.
class _Dates {
  _Dates(this.calendar);
  final WorkspaceCalendar calendar;
  DateTime dateOf(DateTime instant) => calendar.dateOf(instant);
}
