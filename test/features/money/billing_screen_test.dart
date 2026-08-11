// SPDX-License-Identifier: 0BSD
import 'dart:io';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
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
  FakeWorkspaceRepository? workspace,
}) async {
  money ??= FakeMoneyRepository();
  // The editor stacks both sections; a taller surface keeps every control
  // hit-testable without scrolling choreography.
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(money: money, workspace: workspace),
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

    // Removing (50,75] takes ITS lower boundary 50: the range merges
    // into the previous band, (25,50] → (25,75].
    await tester.tap(find.byIcon(Icons.remove_circle_outline).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();
    expect(money.feeBands, hasLength(3));
    expect(money.feeBands[1].fromPct, 25);
    expect(money.feeBands[1].toPct, 75);
    expect(money.feeBands.last.fromPct, 75);
  });

  testWidgets(
      "removing a middle band takes ITS 'from' boundary — the range merges "
      'into the previous band, not the next (field report: deleting the '
      '"from 25%" row must not erase the 50 boundary)', (tester) async {
    final money = await pumpBilling(tester);

    // Row 2 is (25,50] — its remove button deletes boundary 25, not 50.
    await tester.tap(find.byIcon(Icons.remove_circle_outline).at(1));
    await tester.pumpAndSettle();

    expect(find.text('from 0%'), findsOneWidget);
    expect(find.text('from 50%'), findsOneWidget);
    expect(find.text('from 25%'), findsNothing);
    // The first band's upper bound extended to the removed row's 50,
    // keeping ITS prices (overage 15); the removed band's fee 150 and
    // overage 8 vanish with the row.
    expect(find.widgetWithText(TextFormField, '50'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '25'), findsNothing);
    expect(find.widgetWithText(TextFormField, '15'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '150'), findsNothing);
    expect(find.widgetWithText(TextFormField, '8'), findsNothing);

    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();
    expect(money.feeBands, hasLength(2));
    expect(money.feeBands.first.fromPct, 0);
    expect(money.feeBands.first.toPct, 50);
    expect(money.feeBands.first.feeCents, 0);
    expect(money.feeBands.first.overageFeeCents, 1500);
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

  // The #194 middle-band test pinned forward-merging (the deleted row's
  // UPPER boundary vanished, its 'from' label survived) — exactly the
  // behavior reported as wrong; the merge-into-previous test above is
  // its replacement.

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

  testWidgets('the packages editor lists the seeded pack and adds a new one '
      '(0042)', (tester) async {
    final money = await pumpBilling(tester);

    // The default fake seeds one 5-day pack at €40.
    expect(find.text('5-day pack'), findsOneWidget);
    expect(find.text('5 days · 40 EUR'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      '10-day pack',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Days'), '10');
    await tester.enterText(find.widgetWithText(TextField, 'Price'), '70');
    await tester.tap(find.byTooltip('Add package'));
    await tester.pumpAndSettle();

    expect(money.packages, hasLength(2));
    final added = money.packages.last;
    expect(added.name, '10-day pack');
    expect(added.days, 10);
    expect(added.priceCents, 7000);
    expect(find.text('Saved.'), findsOneWidget);
  });

  testWidgets('toggling a package off deactivates it (0042)', (tester) async {
    final money = await pumpBilling(tester);

    expect(money.packages.single.active, isTrue);
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();

    expect(money.packages.single.active, isFalse);
  });

  testWidgets(
      'the tariff VAT rate is configurable (#542): picking a rate persists '
      'it and re-prices the band VAT shares', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.workspaces[0] =
        workspace.workspaces[0].copyWith(vatRegime: 'vat_registered');
    final money = FakeMoneyRepository()
      ..vatRates = [
        const VatRate(
            id: 'vat-1', label: 'Standard', percent: 20, isDefault: true),
        const VatRate(id: 'vat-2', label: 'Reduced', percent: 10),
      ];
    await pumpBilling(tester, money: money, workspace: workspace);

    // Default: the workspace default rate prices the bands (band-3 fee
    // 250.00 gross → 41.67 VAT at 20 %).
    expect(find.textContaining('(the workspace default'), findsOneWidget);
    expect(find.textContaining('incl. VAT 41.67'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('billing-tariff-vat')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reduced (10 %)').last);
    await tester.pumpAndSettle();

    // Persisted on pick, and every band share re-prices at 10 %
    // (250.00 gross → 22.73 VAT).
    expect(workspace.workspaces[0].subscriptionVatRateId, 'vat-2');
    expect(find.textContaining('(the tariff rate)'), findsOneWidget);
    expect(find.textContaining('incl. VAT 22.73'), findsOneWidget);
    expect(find.textContaining('incl. VAT 41.67'), findsNothing);
  });

  test(
      'migration 0109 wires the configurable tariff/accessory rates into '
      'the invoice', () {
    final sql =
        File('supabase/migrations/0109_configurable_tariff_accessory_vat.sql')
            .readAsStringSync();
    // The two new nullable rate columns (null = workspace default).
    expect(sql, contains('alter table public.accessories'));
    expect(sql, contains('alter table public.workspaces'));
    expect(sql, contains('subscription_vat_rate_id'));
    // The tariff resolution helper + its use for subscription/overage.
    expect(sql, contains('workspace_tariff_vat_percent'));
    expect(sql, contains("'vat_percent', v_tariff,"));
    // The statement's per-rate accessory breakdown feeds one invoice
    // line per rate.
    expect(sql, contains("'accessory_supplement_by_rate', v_supp_by_rate"));
    expect(sql, contains("jsonb_array_elements(v_stmt->'accessory_supplement_by_rate')"));
    // Both regenerated functions stay locked away from clients.
    expect(sql,
        contains('revoke execute on function public.member_statement'));
    expect(sql,
        contains('revoke execute on function public.invoice_lines_for'));
  });
}
