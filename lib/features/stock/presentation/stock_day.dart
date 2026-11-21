// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4161 (B) -- the business day of an instant, from the workspace's own
// calendar (its context), never the process-wide static. Before the context
// is ready the day of the instant in UTC stands in, which is only ever shown
// for a moment.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workspace/providers/workspace_providers.dart';

/// The day [instant] falls on in the business's calendar.
DateTime stockDayOf(WidgetRef ref, DateTime instant) {
  final calendar = ref.watch(readyWorkspaceContextProvider)?.calendar;
  final utc = instant.toUtc();
  return calendar?.dateOf(instant) ?? DateTime(utc.year, utc.month, utc.day);
}
