// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4426 -- the money screens offer today on the active business's calendar. Composed here, where both features are, so
// the money feature does not import the workspace for it.
import 'package:flutter_riverpod/misc.dart' show Override;

import '../core/time/business_day_providers.dart';
import '../core/time/clock.dart';
import '../features/money/providers/business_day_provider.dart';
import '../features/workspace/providers/workspace_providers.dart';

/// Puts the business's day in a scope's overrides (main.dart, the demo container).
final Override businessDayFromApp = businessDayProvider.overrideWith((ref) {
  final now = ref.watch(clockProvider).now();
  // The business's zone: its captured calendar when the context is ready, else the zone its workspace row carries. Until
  // either is known the UTC date stands in (as everywhere else a zone is missing), never the device's; a reader that keeps
  // the day re-reads when it becomes known.
  final timezone = ref.watch(readyWorkspaceContextProvider)?.calendar.timezone ?? ref.watch(currentWorkspaceProvider).value?.timezone;
  if (timezone == null) return businessDateOf(now, null);
  ref.watch(businessTodayProvider(timezone)); // moves at the business's midnight
  return businessDateOf(now, timezone);
});
