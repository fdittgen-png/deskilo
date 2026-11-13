// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #123 — the service catalogue: listed with prices and VAT, created,
// edited, deactivated but never deleted.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

Future<FakeMoneyRepository> pumpServices(
  WidgetTester tester, {
  FakeMoneyRepository? money,
  FakeWorkspaceRepository? workspace,
}) async {
  money ??= FakeMoneyRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides:
          standardTestOverrides(money: money, workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(Scaffold).first);
  unawaited(GoRouter.of(context).push('/services'));
  await tester.pumpAndSettle();
  return money;
}

void main() {
  testWidgets('the catalog lists every service with price, inactive marked',
      (tester) async {
    await pumpServices(tester);

    expect(find.text('Coffee'), findsOneWidget);
    expect(find.textContaining('1.50'), findsOneWidget);
    expect(find.text('Printing'), findsOneWidget);
    expect(find.textContaining('0.20'), findsOneWidget);
    expect(find.text('Locker'), findsOneWidget);
    expect(find.text('Inactive'), findsOneWidget);
  });

  testWidgets('an empty catalog shows the empty state', (tester) async {
    await pumpServices(tester, money: FakeMoneyRepository()..services.clear());

    expect(find.text('No services yet.'), findsOneWidget);
  });

  testWidgets('creating a service persists name and price (#123)',
      (tester) async {
    final money = await pumpServices(tester);

    await tester.tap(find.byKey(const ValueKey('services-new')));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Day pass');
    await tester.enterText(find.widgetWithText(TextField, 'Price'), '2.50');
    await _tapVisible(tester, find.text('Save'));
    await tester.pumpAndSettle();

    final created = money.services.singleWhere((s) => s.name == 'Day pass');
    expect(created.priceCents, 250);
    expect(created.active, isTrue);
    expect(find.text('Day pass'), findsOneWidget);
  });

  testWidgets('editing a service updates price and can deactivate it',
      (tester) async {
    final money = await pumpServices(tester);

    await tester.tap(find.text('Coffee'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Price'), '3');
    await _tapVisible(tester, find.byKey(const ValueKey('services-active')));
    await _tapVisible(tester, find.text('Save'));
    await tester.pumpAndSettle();

    final updated = money.services.singleWhere((s) => s.name == 'Coffee');
    expect(updated.priceCents, 300);
    expect(updated.active, isFalse);
    expect(find.text('Inactive'), findsNWidgets(2));
  });

  testWidgets('a deactivated service can be reactivated, never deleted',
      (tester) async {
    final money = await pumpServices(tester);

    await tester.tap(find.text('Locker'));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.byKey(const ValueKey('services-active')));
    await _tapVisible(tester, find.text('Save'));
    await tester.pumpAndSettle();

    final updated = money.services.singleWhere((s) => s.name == 'Locker');
    expect(updated.active, isTrue);
    expect(money.services.length, 3);
    expect(find.text('Inactive'), findsNothing);
  });

  testWidgets('workers get no services entry in settings', (tester) async {
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
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Services'), findsNothing);
  });

  testWidgets(
      'VAT-charging regime: every row names its rate — own rate, or the '
      'workspace default (#537)', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.workspaces[0] =
        workspace.workspaces[0].copyWith(vatRegime: 'vat_registered');
    final money = FakeMoneyRepository()
      ..vatRates = [
        const VatRate(
            id: 'vat-1', label: 'Standard', percent: 20, isDefault: true),
        const VatRate(id: 'vat-2', label: 'Reduced', percent: 5.5),
      ];
    // Seed BEFORE the pump — the provider caches its first read.
    money.services.clear();
    money.services.addAll([
      const ServiceItem(
          id: 's1',
          workspaceId: 'ws-1',
          name: 'Coffee',
          priceCents: 2000,
          active: true,
          vatRateId: 'vat-2'),
      const ServiceItem(
          id: 's2',
          workspaceId: 'ws-1',
          name: 'Locker',
          priceCents: 1000,
          active: true),
    ]);
    await pumpServices(tester, money: money, workspace: workspace);

    expect(find.textContaining('incl. VAT 5.5%'), findsOneWidget);
    expect(find.textContaining('incl. VAT 20%'), findsOneWidget);
  });

  testWidgets('no VAT regime → prices stay bare (#537)', (tester) async {
    await pumpServices(tester);
    expect(find.textContaining('incl. VAT'), findsNothing);
  });

  // #2354 — where a service is supplied for VAT: the owner marks mail
  // handling a general service; a desk-like service stays with the
  // premises. Only a VAT-charging workspace with the flag on is asked.
  Future<FakeMoneyRepository> pumpVatServices(WidgetTester tester,
      {Map<String, dynamic> flags = const {}}) async {
    final workspace = FakeWorkspaceRepository.withWorkspace(featureFlags: flags);
    workspace.workspaces[0] =
        workspace.workspaces[0].copyWith(vatRegime: 'vat_registered');
    final money = FakeMoneyRepository()
      ..vatRates = [
        const VatRate(
            id: 'vat-1', label: 'Standard', percent: 20, isDefault: true),
      ];
    return pumpServices(tester, money: money, workspace: workspace);
  }

  testWidgets('#2354 — a service is marked a general service and keeps it',
      (tester) async {
    final money = await pumpVatServices(tester);

    await tester.tap(find.text('Coffee'));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('supply-class-field'));
    await tester.ensureVisible(field);
    expect(find.text('Connected with the premises'), findsOneWidget,
        reason: 'the default: taxed where the building stands');
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(
        find.text('General service (not connected with the premises)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('services-save')));
    await tester.pumpAndSettle();

    expect(money.services.singleWhere((s) => s.name == 'Coffee').supplyClass,
        SupplyClass.general);
  });

  testWidgets('#2354 — the flag off: no place of supply to choose',
      (tester) async {
    await pumpVatServices(tester, flags: const {'supplyClassification': false});

    await tester.tap(find.text('Coffee'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('supply-class-field')), findsNothing);
  });

  // #3864 — a new service starts from the business's own switches, and the
  // seller sees what each choice means.
  // The new-service sheet with the class field is taller than the default
  // test window: a phone-tall window keeps its Save button on screen.
  void tallWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<ServiceItem> createDayPass(
      WidgetTester tester, FakeMoneyRepository money,
      {String? expectShown}) async {
    await tester.tap(find.byKey(const ValueKey('services-new')));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Day pass');
    await tester.enterText(find.widgetWithText(TextField, 'Price'), '2.50');
    if (expectShown != null) {
      final field = find.byKey(const ValueKey('supply-class-field'));
      await tester.ensureVisible(field);
      expect(find.text(expectShown), findsOneWidget);
    }
    final save = find.byKey(const ValueKey('services-save'));
    await tester.ensureVisible(save);
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();
    return money.services.singleWhere((s) => s.name == 'Day pass');
  }

  testWidgets('#3864 — a business that books no places starts a general '
      'service, and is asked even without the classification', (tester) async {
    tallWindow(tester);
    final money = await pumpVatServices(tester,
        flags: const {'placeBooking': false, 'supplyClassification': false});
    final created = await createDayPass(tester, money,
        expectShown: 'General service (not connected with the premises)');
    expect(created.supplyClass, SupplyClass.general);
  });

  testWidgets('#3864 — a business that books places starts at the premises',
      (tester) async {
    tallWindow(tester);
    final money = await pumpVatServices(tester,
        flags: const {'placeBooking': true, 'supplyClassification': true});
    final created = await createDayPass(tester, money,
        expectShown: 'Connected with the premises');
    expect(created.supplyClass, SupplyClass.property);
  });

  testWidgets('#3864 — each choice says how it is taxed', (tester) async {
    await pumpVatServices(tester, flags: const {'placeBooking': false});
    await tester.tap(find.byKey(const ValueKey('services-new')));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('supply-class-field'));
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(find.text('Taxed where the premises are.'), findsOneWidget);
    expect(
        find.text('Taxed by the general rule: a business customer in another '
            'member state accounts for the VAT.'),
        findsOneWidget);
  });

  testWidgets('#3864 — an existing service keeps its class when place '
      'booking is switched off', (tester) async {
    final money = await pumpVatServices(tester,
        flags: const {'placeBooking': false});

    await tester.tap(find.text('Coffee'));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('supply-class-field'));
    await tester.ensureVisible(field);
    expect(find.text('Connected with the premises'), findsOneWidget,
        reason: 'the class it was saved with, not the new default');
    await tester.tap(find.byKey(const ValueKey('services-save')));
    await tester.pumpAndSettle();

    expect(money.services.singleWhere((s) => s.name == 'Coffee').supplyClass,
        SupplyClass.property);
  });
}

/// #3552 — the sheet is taller: a control is brought into view first.
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
  await tester.tap(finder);
}
