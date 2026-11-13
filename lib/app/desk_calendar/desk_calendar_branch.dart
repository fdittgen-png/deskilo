// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — the Calendar branch at the desk. From the expanded window
// class (the navigation stands beside the page), and while the calendar hub is
// on, `/calendar` is the desk calendar: a week, a day and a month that use the
// monitor, the booking beside them. Below it, or with the hub off, the branch
// is the phone's, unchanged (`CalendarBranch`).
//
// It lives with the app's composition: it joins the calendar, reservations and
// plan features without adding a coupling between them.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/adaptive/window_class.dart';
import '../../features/calendar/presentation/screens/calendar_branch.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import 'desk_calendar_page.dart';

class DeskCalendarBranch extends ConsumerWidget {
  const DeskCalendarBranch({this.query = const {}, super.key});

  /// The address' query: the view, the day and the open booking.
  final Map<String, String> query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.calendarHub);
    return hub && WindowClass.of(context).atLeast(WindowClass.expanded)
        ? DeskCalendarPage(query: query)
        : const CalendarBranch();
  }
}
