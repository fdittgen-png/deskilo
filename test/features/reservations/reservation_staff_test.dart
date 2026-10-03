// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2137 — manageReservations, given through a role, works in the app: the
// member who holds it acts on reservations as staff (and the server agrees
// since 0364), and finds the controls that say so; a member without it
// does not.
import 'package:deskilo/core/demo/data/workspace_roles_repository.dart';
import 'package:deskilo/features/members/presentation/screens/member_page.dart';
import 'package:deskilo/features/plan/domain/seat_block_policy.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/domain/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Member _member({
  String id = 'member-1',
  bool isAdmin = false,
  bool isOwner = false,
  MemberStatus status = MemberStatus.active,
}) => Member(
  id: id,
  workspaceId: 'ws-1',
  userId: 'user-${id.split('-').last}',
  isAdmin: isAdmin,
  isOwner: isOwner,
  status: status,
);

const _reservations = {WorkspacePermission.manageReservations};

FakeWorkspaceRoles _frontDesk() => FakeWorkspaceRoles()
  ..callerMemberId = 'member-1'
  ..roles.add(
    const WorkspaceRole(
      id: 'role-fd',
      key: 'front_desk',
      names: {'en': 'Front desk'},
      permissions: _reservations,
    ),
  )
  ..assignments['role-fd'] = ['member-1'];

Future<void> _pumpPage(WidgetTester tester, FakeWorkspaceRoles roles) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final workspace =
      FakeWorkspaceRepository.withWorkspace(
          featureFlags: const {'customRoles': true, 'levelBooking': true},
        )
        ..myMember = _member()
        ..otherMembers.add(_member(id: 'member-3'))
        ..memberNames = {'member-1': 'Flo', 'member-3': 'Ben'};
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace, roles: roles),
      child: const MaterialApp(home: MemberPage(memberId: 'member-3')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('seat blocks: staff block seats where an admin may', () {
    bool may({MemberStatus status = MemberStatus.active, bool on = true}) =>
        canManageSeatBlocks(
          member: _member(status: status),
          features: {if (on) WorkspaceFeature.adminSeatBlocking},
          staff: true,
        );
    expect(may(), isTrue);
    // The owner's switch still decides for staff, as it does for admins.
    expect(may(on: false), isFalse);
    expect(may(status: MemberStatus.paused), isFalse);
    expect(
      canManageSeatBlocks(
        member: _member(),
        features: const {WorkspaceFeature.adminSeatBlocking},
      ),
      isFalse,
    );
  });

  testWidgets('a role holder finds a member\'s booking allowances; a plain '
      'member does not', (tester) async {
    await _pumpPage(tester, _frontDesk());
    for (final key in [
      'member-page-reservation-limit',
      'member-page-simultaneous',
      'member-page-level',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }

    await _pumpPage(tester, FakeWorkspaceRoles());
    for (final key in [
      'member-page-reservation-limit',
      'member-page-simultaneous',
      'member-page-level',
    ]) {
      expect(find.byKey(ValueKey(key)), findsNothing, reason: key);
    }
  });
}
