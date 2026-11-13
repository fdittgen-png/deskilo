// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — feature route list: one page per member and managed profiles.
// A route is one GoRoute and its RouteAccess here; router.dart only composes
// the lists.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/context_l10n.dart';

import '../../core/navigation/list_detail_route.dart';
import '../../features/members/presentation/screens/managed_profile_screen.dart';
import '../../features/members/presentation/screens/member_page.dart';
import '../../features/members/presentation/screens/member_record.dart';
import '../../features/members/presentation/screens/members_desk.dart';
import '../../features/members/presentation/screens/plans_desk.dart';
import '../../features/members/presentation/screens/privacy_admin_screen.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import '../../features/workspace/presentation/screens/members_screen.dart';
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
    // #3278 — the personal data admin: rights requests and privacy incidents.
    GoRoute(
      path: '/members/privacy',
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.memberDataExport],
          to: '/settings',
        ),
      ),
      builder: (context, state) => const PrivacyAdminScreen(),
    ),
    // #3618 — the plans: the fee bands with their members, a plan beside
    // the table on a large window, a page otherwise. Before '/members', so
    // its ':id' never takes 'plans'.
    GoRoute(
      path: plansPath,
      redirect: env.guard(_membersAccess),
      builder: (context, state) => const PlansScreen(),
      routes: [
        GoRoute(
          path: ':id',
          pageBuilder: (context, state) =>
              recordPage(context, state, (id) => PlanRecord(bandId: id)),
        ),
      ],
    ),
    GoRoute(
      path: membersPath,
      // Admins reach member management too (0044: they set reservation
      // limits and issue badges); owner-only controls gate inside.
      redirect: env.guard(_membersAccess),
      builder: (context, state) => MembersScreen(
        desk: const MembersDesk(),
        deskActions: [
          TextButton(
            key: const ValueKey('members-plans'),
            onPressed: () => context.go(plansPath),
            child: Text(context.l10n.membersPlansTitle),
          ),
        ],
      ),
      // #3618 — a member's address: beside the table on a large window,
      // the member with their tabs as a page otherwise.
      routes: [
        GoRoute(
          path: ':id',
          pageBuilder: (context, state) =>
              recordPage(context, state, (id) => MemberRecord(memberId: id)),
        ),
      ],
    ),
  ];
}

/// Who reaches the members and the plans.
const _membersAccess = RouteAccess(
  permission: WorkspacePermission.manageMembers,
  bypass: RoleBypass.administrator,
);
