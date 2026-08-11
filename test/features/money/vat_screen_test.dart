// SPDX-License-Identifier: 0BSD
//
// The VAT rate editor (0072) — owner-only. A rate is a fact about the
// business, so the screen offers the country's usual ones as a starting
// point and refuses to save a set the server would reject.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

Future<FakeMoneyRepository> pumpVat(
  WidgetTester tester, {
  FakeMoneyRepository? money,
  FakeWorkspaceRepository? workspace,
  String route = '/vat',
}) async {
  money ??= FakeMoneyRepository();
  await tester.binding.setSurfaceSize(const Size(900, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(money: money, workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).push(route);
  await tester.pumpAndSettle();
  return money;
}

void main() {
  testWidgets('a workspace with no rate says so — VAT is simply off',
      (tester) async {
    await pumpVat(tester);

    expect(find.byKey(const ValueKey('vat-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('vat-rate-label-0')), findsNothing);
  });

  testWidgets(
      'the country\'s usual rates seed the editor, standard first and '
      'default', (tester) async {
    final money = await pumpVat(tester);

    // The test workspace is German: 19 / 7.
    await tester.tap(find.byKey(const ValueKey('vat-seed')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('vat-rate-percent-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('vat-save')));
    await tester.pumpAndSettle();

    expect(money.vatRates.map((r) => r.percent), [19, 7]);
    expect(money.vatRates.first.isDefault, isTrue,
        reason: 'the standard rate is what a subscription falls under');
    expect(money.vatRates.every((r) => r.category == 'S'), isTrue);
    expect(find.text('VAT rates saved.'), findsOneWidget);
  });

  testWidgets('a hand-typed rate is saved with its label and percentage',
      (tester) async {
    final money = await pumpVat(tester);

    await tester.tap(find.byKey(const ValueKey('vat-add-rate')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('vat-rate-label-0')),
      'Réduit',
    );
    // A comma is what a French or German keyboard types.
    await tester.enterText(
      find.byKey(const ValueKey('vat-rate-percent-0')),
      '5,5',
    );
    await tester.tap(find.byKey(const ValueKey('vat-save')));
    await tester.pumpAndSettle();

    expect(money.vatRates.single.label, 'Réduit');
    expect(money.vatRates.single.percent, 5.5);
    expect(money.vatRates.single.isDefault, isTrue,
        reason: 'the only rate there is cannot be anything else');
  });

  testWidgets('a rate without a name is refused before it reaches the server',
      (tester) async {
    final money = await pumpVat(tester);

    await tester.tap(find.byKey(const ValueKey('vat-add-rate')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('vat-rate-percent-0')),
      '20',
    );
    await tester.tap(find.byKey(const ValueKey('vat-save')));
    await tester.pumpAndSettle();

    expect(money.vatRates, isEmpty);
    expect(
      find.textContaining('needs a name and a percentage'),
      findsOneWidget,
    );
  });

  testWidgets('the default can be moved, and only one rate ever holds it',
      (tester) async {
    final money = await pumpVat(
      tester,
      money: FakeMoneyRepository()
        ..vatRates = [
          const VatRate(
              id: 'vat-1', label: 'Standard', percent: 19, isDefault: true),
          const VatRate(id: 'vat-2', label: 'Reduced', percent: 7),
        ],
    );

    await tester.tap(find.byKey(const ValueKey('vat-rate-default-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vat-save')));
    await tester.pumpAndSettle();

    expect(money.vatRates.where((r) => r.isDefault).map((r) => r.id),
        ['vat-2']);
  });

  testWidgets('removing a rate keeps its id out of the saved set — the '
      'server deactivates it rather than deleting it', (tester) async {
    final money = await pumpVat(
      tester,
      money: FakeMoneyRepository()
        ..vatRates = [
          const VatRate(
              id: 'vat-1', label: 'Standard', percent: 19, isDefault: true),
          const VatRate(id: 'vat-2', label: 'Reduced', percent: 7),
        ],
    );

    await tester.tap(find.byKey(const ValueKey('vat-rate-remove-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vat-save')));
    await tester.pumpAndSettle();

    expect(money.vatRates.map((r) => r.id), ['vat-1']);
  });

  testWidgets('a workspace that does not charge VAT is told the rates will '
      'not show', (tester) async {
    await pumpVat(tester);

    expect(find.byKey(const ValueKey('vat-regime-hint')), findsOneWidget);
  });

  testWidgets('a plain member cannot reach the editor', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.myMember =
        workspace.myMember.copyWith(isOwner: false, isAdmin: false);
    await pumpVat(tester, workspace: workspace);

    expect(find.byKey(const ValueKey('vat-save')), findsNothing);
  });

  testWidgets('the legal identity screen links to the rates and lists them',
      (tester) async {
    // #484 — the rates tile shows only under a VAT-charging regime.
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.workspaces[0] =
        workspace.workspaces[0].copyWith(vatRegime: 'vat_registered');
    await pumpVat(
      tester,
      money: FakeMoneyRepository()
        ..vatRates = [
          const VatRate(
              id: 'vat-1', label: 'Standard', percent: 19, isDefault: true),
        ],
      workspace: workspace,
      route: '/legal-identity',
    );

    expect(find.byKey(const ValueKey('legal-identity-vat-rates')),
        findsOneWidget);
    expect(find.textContaining('Standard'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('legal-identity-vat-rates')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('vat-rate-label-0')), findsOneWidget);
  });

  testWidgets('a service is taxed at a rate the owner picks', (tester) async {
    // #484 — the picker exists only under a VAT-charging regime.
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.workspaces[0] =
        workspace.workspaces[0].copyWith(vatRegime: 'vat_registered');
    final money = await pumpVat(
      tester,
      money: FakeMoneyRepository()
        ..vatRates = [
          const VatRate(
              id: 'vat-1', label: 'Standard', percent: 19, isDefault: true),
          const VatRate(id: 'vat-2', label: 'Reduced', percent: 7),
        ],
      workspace: workspace,
      route: '/services',
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Lunch');
    await tester.enterText(find.widgetWithText(TextField, 'Price'), '12.00');
    await tester.tap(find.byKey(const ValueKey('vat-rate-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reduced (7 %)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final service = money.services.last;
    expect(service.name, 'Lunch');
    expect(service.priceCents, 1200,
        reason: 'the price is still what the member pays — VAT is inside it');
    expect(service.vatRateId, 'vat-2');
  });

  testWidgets('with no rate configured the service sheet shows no VAT field '
      'at all', (tester) async {
    await pumpVat(tester, route: '/services');

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('vat-rate-field')), findsNothing);
  });

  testWidgets('a workspace that declared NO VAT regime never sees the '
      'service VAT picker — even with leftover rates (#484)',
      (tester) async {
    await pumpVat(
      tester,
      money: FakeMoneyRepository()
        ..vatRates = [
          const VatRate(
              id: 'vat-1', label: 'Standard', percent: 19, isDefault: true),
        ],
      route: '/services',
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('vat-rate-field')), findsNothing);
  });

  testWidgets(
      'vatManagement feature off (#544): /vat bounces to /money, the '
      'rates tile disappears, and rate pickers hide everywhere',
      (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace(
      featureFlags: const {'vatManagement': false},
    );
    workspace.workspaces[0] =
        workspace.workspaces[0].copyWith(vatRegime: 'vat_registered');
    final money = FakeMoneyRepository()
      ..vatRates = [
        const VatRate(
            id: 'vat-1', label: 'Standard', percent: 19, isDefault: true),
      ];
    await pumpVat(tester, money: money, workspace: workspace);

    // The route bounced: no rates editor on screen.
    expect(find.byKey(const ValueKey('vat-rate-label-0')), findsNothing);
    expect(find.byKey(const ValueKey('vat-save')), findsNothing);

    // The legal identity screen keeps its identity fields but loses the
    // rates entry — the regime still charges, only the CONFIG is gone.
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push('/legal-identity');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('legal-identity-vat-id')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('legal-identity-vat-rates')),
        findsNothing);
  });
}
