// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — feature route list: the events path (it redirects into the calendar hub or the inbox) and validation settings.
// A route is one GoRoute and its RouteAccess here; router.dart only composes
// the lists.
import 'dart:async';

import 'package:go_router/go_router.dart';

import '../../features/calendar/providers/calendar_view_request.dart';
import '../../features/events/presentation/screens/validation_settings_screen.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import '../../features/workspace/presentation/screens/inbox_screen.dart';
import '../route_access.dart';
import '../route_env.dart';

/// Routes of the events feature.
List<RouteBase> eventsRoutes(RouteEnv env) {
  return [
    GoRoute(
      // Events feed (#230, a tab before that): since #702 it is the
      // inbox's Alerts face, so this path REDIRECTS there rather than
      // opening a second copy over the shell. Kept, not deleted —
      // notification taps, stored shortcuts and links already point
      // at it, and a dead path is a worse answer than the feed they
      // were asking for.
      path: '/events',
      redirect: (context, state) {
        if (!env.featureEnabled(WorkspaceFeature.eventsTab)) return '/messages';
        // The calendar hub holds the alerts: ask it for its Alerts view.
        final inCalendar =
            env.featureEnabled(WorkspaceFeature.calendarTab) &&
            env.featureEnabled(WorkspaceFeature.calendarHub);
        // Off the routing frame: setting a provider mid-redirect is
        // modifying state while the tree is building.
        unawaited(
          Future.microtask(
            () => inCalendar
                ? env.ref.read(calendarAlertsRequestProvider.notifier).request()
                : env.ref
                      .read(inboxTabControllerProvider.notifier)
                      .show(InboxTab.alerts),
          ),
        );
        return inCalendar ? '/calendar' : '/messages';
      },
    ),
    GoRoute(
      path: '/validation',
      // #816 — the `manageValidation` permission, which the server's
      // write policy now asks too (0144); owners always hold it.
      redirect: env.guard(
        const RouteAccess(permission: WorkspacePermission.manageValidation),
      ),
      builder: (context, state) => const ValidationSettingsScreen(),
    ),
  ];
}
