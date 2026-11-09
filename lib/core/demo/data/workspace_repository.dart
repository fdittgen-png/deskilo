// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ADR 0028 (#1373) — moved out of test/helpers/mock_providers.dart so the
// Demo environment can run the real app against it. The suite reaches it
// through the same import as before.

import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/domain/workspace_repository.dart';

import 'fake_badges.dart';
import 'fake_booking_rules.dart';
import 'fake_conversations.dart';
import 'fake_managed_identity.dart';
import 'fake_role_permissions.dart';
import 'fake_sites.dart';
import 'fake_workspace_identity.dart';
import 'fake_workspace_lifecycle.dart';
import 'fake_workspace_members.dart';
import 'fake_workspace_state.dart';
import 'fake_workspace_templates.dart';

/// In-memory [WorkspaceRepository] for tests: the state plus the mixins.
class FakeWorkspaceRepository extends FakeWorkspaceState
    with
        FakeConversations,
        FakeBookingRules,
        FakeWorkspaceLifecycle,
        FakeWorkspaceMembers,
        FakeManagedIdentity,
        FakeBadges,
        FakeRolePermissions,
        FakeSites,
        FakeWorkspaceIdentity,
        FakeWorkspaceTemplates
    implements WorkspaceRepository {
  FakeWorkspaceRepository({super.workspaces});

  /// One seeded workspace; [featureFlags] seeds its feature overrides
  /// (#146) over the platform features that ship on (#2566).
  FakeWorkspaceRepository.withWorkspace({
    Map<String, dynamic> featureFlags = const {},
  }) : super(
         workspaces: [
           Workspace(
             id: 'ws-1',
             rolePermissions: everydayMatrix(),
             name: 'Test Space',
             countryCode: 'DE',
             currencyCode: 'EUR',
             timezone: 'Europe/Berlin',
             inviteCode: 'GOODCODE22',
             featureFlags: {...platformFeaturesOnByDefault, ...featureFlags},
             // #917 — the shared fixture is a PRODUCTION workspace, so the
             // development strip does not steal a row from every layout
             // assertion in the suite. The strip has its own tests
             // (environment_banner_test.dart), which pump the whole app on
             // a development one and walk a pushed route under it; a test
             // that is about the environment says so by setting it.
             environment: 'prod',
           ),
         ],
         // #1823: the fixture opens in ws-1, not on Me
         serverDefaultWorkspaceId: 'ws-1',
       );
}

/// #3293 — who a decision or a booking in this space is checked against.
extension FakeWorkspaceMembership on FakeWorkspaceRepository {
  /// [id]'s membership of this space, or null when they hold none.
  Member? memberOf(String id) =>
      [myMember, ...otherMembers].where((m) => m.id == id).firstOrNull;
}
