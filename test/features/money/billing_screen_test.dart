// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

Future<FakeMoneyRepository> pumpBilling(
  WidgetTester tester, {
  FakeMoneyRepository? money,
}) async {
  money ??= FakeMoneyRepository();
  // The editor stacks both sections; a taller surface keeps every control
  // hit-testable without scrolling choreography.
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(money: money),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).push('/billing');
  await tester.pumpAndSettle();
  return money;
}

void main() {
  testWidgets('fee bands render ordered with boundaries and prices',
      (tester) async {
    await pumpBilling(tester);

    // Boundaries of the three seeded bands: (0,25], (25,50], (50,100].
    expect(find.text('from 0%'), findsOneWidget);
    expect(find.text('from 25%'), findsOneWidget);
    expect(find.text('from 50%'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '25'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '100'), findsOneWidget);
    // Fees in major units: 150 and 250; overage 15 and 8.
    expect(find.widgetWithText(TextFormField, '150'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '250'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '15'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '8'), findsOneWidget);
  });

  testWidgets('editing a fee persists the whole band set via the RPC shape',
      (tester) async {
    final money = await pumpBilling(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, '250'),
      '300',
    );
    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();

    expect(money.feeBands, hasLength(3));
    expect(money.feeBands.last.fromPct, 50);
    expect(money.feeBands.last.toPct, 100);
    expect(money.feeBands.last.feeCents, 30000);
    expect(find.text('Saved.'), findsOneWidget);
  });

  testWidgets('a non-increasing boundary blocks the save', (tester) async {
    final money = await pumpBilling(tester);
    final before = List.of(money.feeBands);

    // Second band's upper boundary below the first band's 25.
    await tester.enterText(find.widgetWithText(TextFormField, '50'), '20');
    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();

    expect(
      find.text('Bands must increase and end at 100%.'),
      findsOneWidget,
    );
    expect(money.feeBands, before);
  });

  testWidgets('adding a band splits the last one; removing merges it back',
      (tester) async {
    final money = await pumpBilling(tester);

    await tester.tap(find.text('Add band'));
    await tester.pumpAndSettle();
    // Midpoint of (50,100] is 75.
    expect(find.text('from 75%'), findsOneWidget);

    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();
    expect(money.feeBands, hasLength(4));
    expect(money.feeBands[2].toPct, 75);

    await tester.tap(find.byIcon(Icons.remove_circle_outline).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();
    expect(money.feeBands, hasLength(3));
    expect(money.feeBands.last.fromPct, 50);
  });

  testWidgets(
      "editing a boundary refreshes the next row's from-label (#194)",
      (tester) async {
    await pumpBilling(tester);

    // Raise the first band's upper boundary 25 → 30: the second row's
    // derived lower boundary must follow immediately, before any save.
    await tester.enterText(find.widgetWithText(TextFormField, '25'), '30');
    await tester.pump();

    expect(find.text('from 30%'), findsOneWidget);
    expect(find.text('from 25%'), findsNothing);
    expect(find.text('from 0%'), findsOneWidget);
    expect(find.text('from 50%'), findsOneWidget);
  });

  testWidgets('removing the first band deletes exactly that range (#194)',
      (tester) async {
    final money = await pumpBilling(tester);

    await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
    await tester.pumpAndSettle();

    // (0,25] is gone; the former second band now starts at 0.
    expect(find.text('from 0%'), findsOneWidget);
    expect(find.text('from 50%'), findsOneWidget);
    expect(find.text('from 25%'), findsNothing);
    expect(find.widgetWithText(TextFormField, '25'), findsNothing);
    // The survivors keep their own prices; the removed band's overage 15
    // vanishes with it.
    expect(find.widgetWithText(TextFormField, '150'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '250'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '15'), findsNothing);

    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();
    expect(money.feeBands, hasLength(2));
    expect(money.feeBands.first.fromPct, 0);
    expect(money.feeBands.first.toPct, 50);
    expect(money.feeBands.first.feeCents, 15000);
  });

  testWidgets('removing the middle band deletes exactly that range (#194)',
      (tester) async {
    await pumpBilling(tester);

    await tester.tap(find.byIcon(Icons.remove_circle_outline).at(1));
    await tester.pumpAndSettle();

    // (25,50] is gone; the last band now starts at 25.
    expect(find.text('from 0%'), findsOneWidget);
    expect(find.text('from 25%'), findsOneWidget);
    expect(find.text('from 50%'), findsNothing);
    expect(find.widgetWithText(TextFormField, '50'), findsNothing);
    // The removed band's prices (fee 150, overage 8) go with it; its
    // neighbours keep theirs.
    expect(find.widgetWithText(TextFormField, '150'), findsNothing);
    expect(find.widgetWithText(TextFormField, '8'), findsNothing);
    expect(find.widgetWithText(TextFormField, '15'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '250'), findsOneWidget);
  });

  testWidgets('the last band row shows no remove button (#194)',
      (tester) async {
    await pumpBilling(tester);

    // Three bands, but only the two non-last rows are removable — the
    // last one has no minus icon at all instead of a disabled one.
    expect(find.byIcon(Icons.remove_circle_outline), findsNWidgets(2));
  });

  testWidgets(
      'level toggles, an added level and allow-custom persist (#128)',
      (tester) async {
    final money = await pumpBilling(tester);

    await tester.tap(find.text('75%')); // disable the 75 preset
    await tester.enterText(
      find.widgetWithText(TextField, 'Level (1–100)'),
      '60',
    );
    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pumpAndSettle();
    expect(find.text('60%'), findsOneWidget);

    await tester.tap(find.text('Allow negotiated custom value'));
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(money.subscriptionLevels.enabledPresets, [25, 50, 100]);
    expect(money.subscriptionLevels.extraLevels, [60]);
    expect(money.subscriptionLevels.allowCustom, isTrue);
    expect(money.subscriptionLevels.offeredLevels, [25, 50, 60, 100]);
  });

  testWidgets('workers are redirected away from /billing', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..myMember = const Member(
        id: 'member-1',
        workspaceId: 'ws-1',
        userId: 'user-1',
        isAdmin: false,
        isOwner: false,
        status: MemberStatus.active,
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(workspace: workspace),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push('/billing');
    await tester.pumpAndSettle();

    expect(find.text('Billing'), findsNothing);
    expect(find.text('Fee bands'), findsNothing);
  });
}
