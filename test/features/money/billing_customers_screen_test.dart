// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 A2 -- the billing customers screen as a person uses it: the list reads
// as the seller's own, an add and an edit go through the editor and the command,
// a stale edit says so and keeps the sheet open, a person without the right sees
// the list but no door, and a list that could not be read is not an empty one.
import 'package:deskilo/core/demo/data/fake_billing_customers.dart';
import 'package:deskilo/features/money/domain/billing_customer.dart';
import 'package:deskilo/features/money/presentation/screens/billing_customers_screen.dart';
import 'package:deskilo/features/money/providers/billing_customer_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

const _lumi = BillingParty(
  subjectId: 'c-1',
  revision: 2,
  capacity: 'business',
  draft: BillingPartyDraft(
    company: 'Atelier Lumi',
    street: '1 rue du Port',
    postalCode: '34120',
    city: 'Pezenas',
    countryCode: 'FR',
  ),
);

Future<(FakeBillingCustomerRepository, ProviderContainer)> _open(
  WidgetTester tester, {
  Set<WorkspacePermission>? permissions,
  bool seeded = true,
}) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = FakeBillingCustomerRepository();
  await pumpApp(
    tester,
    const BillingCustomersScreen(),
    overrides: [
      ...standardTestOverrides(),
      billingCustomerRepositoryProvider.overrideWithValue(repo),
      if (permissions != null)
        myPermissionsProvider.overrideWithValue(permissions),
    ],
  );
  await tester.pumpAndSettle();
  final workspace = ProviderScope.containerOf(
    tester.element(find.byType(BillingCustomersScreen)),
  ).read(currentWorkspaceProvider).value!;
  if (seeded) {
    repo.seed(workspace.id, _lumi);
    ProviderScope.containerOf(
      tester.element(find.byType(BillingCustomersScreen)),
    ).invalidate(billingCustomersProvider(workspace.id));
    await tester.pumpAndSettle();
  }
  return (
    repo,
    ProviderScope.containerOf(
      tester.element(find.byType(BillingCustomersScreen)),
    ),
  );
}

void main() {
  testWidgets('the list shows the seller\'s customers, says they have no '
      'account, and searches', (tester) async {
    await _open(tester);
    expect(find.text(_en.billingCustomersNoAccount), findsOneWidget);
    expect(find.text('Atelier Lumi'), findsOneWidget);
    expect(find.textContaining('34120 Pezenas'), findsOneWidget);
    expect(find.text(_en.billingCustomerBusiness), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('billing-customers-search')),
      'zzz',
    );
    await tester.pump();
    expect(find.text('Atelier Lumi'), findsNothing);
  });

  testWidgets('add: a missing name shows under its field and sends nothing; '
      'a named customer is saved and listed', (tester) async {
    final (repo, _) = await _open(tester, seeded: false);
    expect(find.text(_en.billingCustomersEmpty), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('billing-customer-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('billing-customer-save')));
    await tester.pumpAndSettle();
    expect(find.text(_en.billingCustomerNameNeeded), findsOneWidget);
    expect(repo.calls, isNot(contains('create')));

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('billing-customer-company')),
        matching: find.byType(EditableText),
      ),
      'Nordlicht GmbH',
    );
    await tester.tap(find.byKey(const ValueKey('billing-customer-save')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('create'));
    expect(find.text('Nordlicht GmbH'), findsOneWidget);
  });

  testWidgets('the region is edited with the country-aware picker and asked again when the country changes (#4501)', (tester) async {
    final (repo, container) = await _open(tester, seeded: false);
    await tester.tap(find.byKey(const ValueKey('billing-customer-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(of: find.byKey(const ValueKey('billing-customer-company')), matching: find.byType(EditableText)),
      'Rossi SRL',
    );
    // France has no region to ask for; Italy asks for its province
    expect(find.byKey(const ValueKey('billing-customer-region')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('billing-customer-country')), 'Ital');
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Italy').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('billing-customer-region')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('billing-customer-save')));
    await tester.pumpAndSettle();
    expect(repo.calls, isNot(contains('create')));
    expect(find.text('An address in this country needs its region.'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('billing-customer-region')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('billing-customer-region')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agrigento').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('billing-customer-save')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('create'));
    final workspace = container.read(currentWorkspaceProvider).value!;
    expect(repo.of(workspace.id).single.draft.subdivision, 'AG');
  });

  testWidgets('edit: a stale revision is refused in words, the sheet stays '
      'open and nothing is saved', (tester) async {
    final (repo, container) = await _open(tester);
    final workspace = container.read(currentWorkspaceProvider).value!;
    await tester.tap(find.byKey(const ValueKey('billing-customer-row-c-1')));
    await tester.pumpAndSettle();
    // Someone else edits it while the sheet is open.
    repo.of(workspace.id)[0] = BillingParty(
      subjectId: 'c-1',
      revision: 3,
      capacity: 'business',
      draft: _lumi.draft,
    );
    await tester.tap(find.byKey(const ValueKey('billing-customer-save')));
    await tester.pumpAndSettle();
    expect(find.text(_en.billingCustomerStale), findsOneWidget);
    expect(find.byKey(const ValueKey('billing-customer-save')), findsOneWidget);
    expect(repo.of(workspace.id).single.revision, 3);
  });

  testWidgets('without the right the list is there and no door opens', (
    tester,
  ) async {
    await _open(tester, permissions: {WorkspacePermission.viewFinances});
    expect(find.text('Atelier Lumi'), findsOneWidget);
    expect(find.byKey(const ValueKey('billing-customer-add')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('billing-customer-row-c-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('billing-customer-save')), findsNothing);
  });

  testWidgets('a list that could not be read says so, offers a retry and is '
      'never shown as empty', (tester) async {
    final (repo, container) = await _open(tester, seeded: false);
    final id = container.read(currentWorkspaceProvider).value!.id;
    repo.failNext = http.ClientException('connection closed');
    container.invalidate(billingCustomersProvider(id));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('read-failure')), findsOneWidget);
    expect(find.text(_en.billingCustomersEmpty), findsNothing);
    await tester.tap(find.byKey(const ValueKey('billing-customers-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('read-failure')), findsNothing);
    expect(find.text(_en.billingCustomersEmpty), findsOneWidget);
  });
}
