// SPDX-License-Identifier: 0BSD
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/plan/presentation/screens/accessories_screen.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_accessory_repository.dart';
import '../../helpers/mock_providers.dart';

/// Widget tests default to 800x600 with lazy lists — use a taller
/// viewport so every list item is on-stage when tapped.
void useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<FakeAccessoryRepository> pumpAccessories(
  WidgetTester tester, {
  FakeAccessoryRepository? accessories,
}) async {
  useTallViewport(tester);
  accessories ??= FakeAccessoryRepository()..seedSmallCatalog();
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(accessories: accessories),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).push('/accessories');
  await tester.pumpAndSettle();
  return accessories;
}

Future<void> pumpSettingsAs(
  WidgetTester tester, {
  required Member member,
  FakeAccessoryRepository? accessories,
}) async {
  useTallViewport(tester);
  final workspace = FakeWorkspaceRepository.withWorkspace()..myMember = member;
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        workspace: workspace,
        accessories: accessories,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'the catalog lists every accessory with its supplement, inactive marked',
      (tester) async {
    await pumpAccessories(tester);

    expect(find.text('Monitor'), findsOneWidget);
    expect(find.textContaining('1.00'), findsOneWidget);
    expect(find.text('Standing desk'), findsOneWidget);
    expect(find.text('No supplement'), findsOneWidget);
    expect(find.text('Docking station'), findsOneWidget);
    expect(find.textContaining('0.50'), findsOneWidget);
    expect(find.text('Inactive'), findsOneWidget);
  });

  testWidgets('an empty catalog shows the empty state', (tester) async {
    await pumpAccessories(tester, accessories: FakeAccessoryRepository());

    expect(find.text('No accessories yet.'), findsOneWidget);
  });

  testWidgets(
      'creating an accessory persists name and supplement cents, appended '
      'to the catalog order (#167)', (tester) async {
    final accessories = await pumpAccessories(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Desk lamp',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Supplement per half-day'),
      '2.50',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final created =
        accessories.accessories.singleWhere((a) => a.name == 'Desk lamp');
    expect(created.supplementCents, 250);
    expect(created.active, isTrue);
    // Seeded sort orders are 0..2 — the new accessory goes to the end.
    expect(created.sortOrder, 3);
    expect(find.text('Desk lamp'), findsOneWidget);
  });

  testWidgets('editing an accessory updates name and supplement',
      (tester) async {
    final accessories = await pumpAccessories(tester);

    await tester.tap(find.text('Monitor'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Curved monitor',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Supplement per half-day'),
      '3',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final updated =
        accessories.accessories.singleWhere((a) => a.name == 'Curved monitor');
    expect(updated.supplementCents, 300);
    expect(find.text('Curved monitor'), findsOneWidget);
    expect(find.text('Monitor'), findsNothing);
  });

  testWidgets('deactivating keeps the accessory listed as inactive',
      (tester) async {
    final accessories = await pumpAccessories(tester);

    await tester.tap(find.text('Standing desk'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Active'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final updated =
        accessories.accessories.singleWhere((a) => a.name == 'Standing desk');
    expect(updated.active, isFalse);
    expect(find.text('Standing desk'), findsOneWidget);
    expect(find.text('Inactive'), findsNWidgets(2));
  });

  testWidgets('a deactivated accessory can be reactivated, never deleted',
      (tester) async {
    final accessories = await pumpAccessories(tester);

    await tester.tap(find.text('Docking station'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Active'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final updated = accessories.accessories
        .singleWhere((a) => a.name == 'Docking station');
    expect(updated.active, isTrue);
    expect(accessories.accessories.length, 3);
    expect(find.text('Inactive'), findsNothing);
  });

  testWidgets('plain members get no accessories entry in settings',
      (tester) async {
    await pumpSettingsAs(
      tester,
      member: const Member(
        id: 'member-1',
        workspaceId: 'ws-1',
        userId: 'user-1',
        isAdmin: false,
        isOwner: false,
        status: MemberStatus.active,
      ),
    );

    expect(find.text('Accessories'), findsNothing);
  });

  testWidgets(
      'a non-owner admin sees the accessories entry and it opens the '
      'catalog (#167: canAdminister, not owner-only)', (tester) async {
    await pumpSettingsAs(
      tester,
      member: const Member(
        id: 'member-1',
        workspaceId: 'ws-1',
        userId: 'user-1',
        isAdmin: true,
        isOwner: false,
        status: MemberStatus.active,
      ),
      accessories: FakeAccessoryRepository()..seedSmallCatalog(),
    );

    await tester.tap(find.text('Accessories'));
    await tester.pumpAndSettle();

    expect(find.byType(AccessoriesScreen), findsOneWidget);
    expect(find.text('Monitor'), findsOneWidget);
  });
}
