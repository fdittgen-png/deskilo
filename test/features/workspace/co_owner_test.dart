// SPDX-License-Identifier: 0BSD
//
// Co-owners (0058): the owner appoints active/passive co-owners from
// the member sheet; an ACTIVE co-owner acts with owner permissions
// (actsAsOwner drives every owner gate); "Promote to owner now"
// (activation) makes a co-owner a full owner. Succession on owner
// removal is a server-side trigger — pinned by the migration, not here.
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deskilo/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../helpers/mock_providers.dart';

/// Seeds Ana BEFORE the pump (the member providers cache their first
/// fetch), then walks Settings → Members & plans.
Future<FakeWorkspaceRepository> pumpMembersWithAna(
  WidgetTester tester, {
  Map<String, dynamic> featureFlags = const {},
  CoOwnerStatus anaCoOwner = CoOwnerStatus.none,
}) async {
  tester.view.physicalSize = const Size(800, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final workspace =
      FakeWorkspaceRepository.withWorkspace(
          // #825 — these tests drive the legacy sheet; the page has its own.
          featureFlags: {'memberPage': false, ...featureFlags})
        ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
        ..otherMembers.add(
          Member(
            id: 'member-2',
            workspaceId: 'ws-1',
            userId: 'user-2',
            isAdmin: false,
            isOwner: false,
            coOwner: anaCoOwner,
            status: MemberStatus.active,
          ),
        );
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Members & plans'));
  await tester.pumpAndSettle();
  return workspace;
}

void main() {
  group('Member.actsAsOwner', () {
    const base = Member(
      id: 'm',
      workspaceId: 'ws-1',
      userId: 'u',
      isAdmin: false,
      isOwner: false,
      status: MemberStatus.active,
    );

    test('owner and ACTIVE co-owner act as owner; passive does not', () {
      expect(base.actsAsOwner, isFalse);
      expect(base.copyWith(isOwner: true).actsAsOwner, isTrue);
      expect(
        base.copyWith(coOwner: CoOwnerStatus.active).actsAsOwner,
        isTrue,
      );
      expect(
        base.copyWith(coOwner: CoOwnerStatus.passive).actsAsOwner,
        isFalse,
      );
    });

    test('an inactive membership never acts as owner', () {
      expect(
        base
            .copyWith(
              coOwner: CoOwnerStatus.active,
              status: MemberStatus.paused,
            )
            .actsAsOwner,
        isFalse,
      );
    });
  });

  testWidgets(
      'the owner appoints an ACTIVE co-owner from the member sheet: the '
      'chip appears and the fake mirrors the server (admin too)',
      (tester) async {
    final workspace = await pumpMembersWithAna(tester);

    await tester.tap(find.text('Ana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Co-ownership'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('co-owner-active')));
    await tester.pumpAndSettle();

    final ana = workspace.otherMembers.single;
    expect(ana.coOwner, CoOwnerStatus.active);
    expect(ana.isAdmin, isTrue);
    expect(find.text('Co-owner'), findsOneWidget);
  });

  testWidgets(
      '"Promote to owner now" turns a passive co-owner into a FULL '
      'owner', (tester) async {
    final workspace = await pumpMembersWithAna(
      tester,
      anaCoOwner: CoOwnerStatus.passive,
    );
    expect(find.text('Co-owner (passive)'), findsOneWidget);

    await tester.tap(find.text('Ana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Promote to owner now'));
    await tester.pumpAndSettle();

    final ana = workspace.otherMembers.single;
    expect(ana.isOwner, isTrue);
    expect(ana.coOwner, CoOwnerStatus.none);
  });

  testWidgets('coOwner feature OFF hides the co-ownership actions',
      (tester) async {
    await pumpMembersWithAna(
      tester,
      featureFlags: const {'coOwner': false},
    );
    await tester.tap(find.text('Ana'));
    await tester.pumpAndSettle();

    expect(find.text('Co-ownership'), findsNothing);
  });
}
