// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — feature route list: one page per member and managed profiles.
// A route is one GoRoute and its RouteAccess here; router.dart only composes
// the lists.
import 'package:go_router/go_router.dart';

import '../../features/members/presentation/screens/managed_profile_screen.dart';
import '../../features/members/presentation/screens/member_page.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../route_access.dart';
import '../route_env.dart';

/// Routes of the members feature.
List<RouteBase> membersRoutes(RouteEnv env) {
  return [
    // #825 — one page per member.
    GoRoute(
      path: '/member/:memberId',
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.memberPage],
          to: '/directory',
        ),
      ),
      builder: (context, state) =>
          MemberPage(memberId: state.pathParameters['memberId'] ?? ''),
    ),
    // #887 — create or edit a managed member's identity.
    GoRoute(
      path: '/members/managed',
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.managedProfiles],
          to: '/members',
        ),
      ),
      builder: (context, state) =>
          ManagedProfileScreen(memberId: state.uri.queryParameters['member']),
    ),
  ];
}
