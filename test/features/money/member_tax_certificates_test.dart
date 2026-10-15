// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2362 -- a customer's exemption certificates on the member's page of a US
// seller: the tile appears only for whoever manages billing in sales-tax mode,
// a certificate is added through the form and shown with its validity, and
// ending one closes it today. The server (pgTAP 190) decides what it exempts.
import 'package:deskilo/core/demo/data/sales_tax_repository.dart';
import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/tax_exemption_certificate.dart';
import 'package:deskilo/features/money/presentation/widgets/member_tax_certificates.dart';
import 'package:deskilo/features/money/providers/sales_tax_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

TaxReferenceSet _withUsGate(TaxReferenceSet base) => TaxReferenceSet([
  ...base.rows,
  const TaxReferenceRow(
    country: 'US',
    key: 'gate',
    validFrom: '1900-01-01',
    value: IssuingGateValue(
      supported: true,
      currency: 'USD',
      taxSystem: salesTaxSystem,
    ),
    source: 'test',
    confirmed: false,
  ),
], origin: base.origin);

Future<FakeSalesTaxRepository> _pump(
  WidgetTester tester, {
  String country = 'US',
  bool canManage = true,
  FakeSalesTaxRepository? sales,
}) async {
  final repo = sales ?? FakeSalesTaxRepository();
  final workspace = FakeWorkspaceRepository.withWorkspace();
  workspace.workspaces[0] = workspace.workspaces[0].copyWith(
    countryCode: country,
    currencyCode: 'USD',
  );
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          money: FakeMoneyRepository(),
          workspace: workspace,
        ),
        salesTaxRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MemberTaxCertificatesTile(
            workspaceId: workspace.workspaces[0].id,
            memberId: 'member-1',
            canManage: canManage,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  const tile = ValueKey('member-page-tax-certificates');
  late TaxReferenceSet previous;

  setUp(() {
    previous = ActiveTaxReference.current;
    ActiveTaxReference.install(_withUsGate(previous));
  });
  tearDown(() => ActiveTaxReference.install(previous));

  testWidgets('shown to whoever manages billing in sales-tax mode only', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byKey(tile), findsOneWidget);
    await _pump(tester, canManage: false);
    expect(find.byKey(tile), findsNothing);
    await _pump(tester, country: 'FR');
    expect(find.byKey(tile), findsNothing);
  });

  testWidgets('a certificate is added through the form and listed', (
    tester,
  ) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(tile));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tax-cert-empty')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tax-cert-add')));
    await tester.pumpAndSettle();
    // nothing typed: the form names what is missing and saves nothing
    await tester.tap(find.byKey(const ValueKey('tax-cert-save')));
    await tester.pumpAndSettle();
    expect(repo.certificates['member-1'], isNull);

    await tester.enterText(find.byKey(const ValueKey('tax-cert-state')), 'ny');
    await tester.enterText(
      find.byKey(const ValueKey('tax-cert-number')),
      'ST-119.1',
    );
    await tester.tap(find.byKey(const ValueKey('tax-cert-save')));
    await tester.pumpAndSettle();

    final saved = repo.certificates['member-1']!.single;
    expect(
      (saved.kind, saved.state, saved.number),
      ('resale', 'NY', 'ST-119.1'),
    );
    expect(find.textContaining('ST-119.1'), findsOneWidget);
    expect(find.byKey(ValueKey('tax-cert-end-${saved.id}')), findsOneWidget);
  });

  testWidgets('ending a certificate closes it today', (tester) async {
    final repo = FakeSalesTaxRepository()
      ..certificates['member-1'] = [
        const TaxExemptionCertificate(
          id: 'c1',
          kind: 'nonprofit',
          state: 'NY',
          number: 'ST-1',
          validFrom: '2020-01-01',
        ),
      ];
    await _pump(tester, sales: repo);
    await tester.tap(find.byKey(tile));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tax-cert-end-c1')));
    await tester.pumpAndSettle();
    expect(repo.certificates['member-1']!.single.validTo, isNotNull);
    expect(find.byKey(const ValueKey('tax-cert-end-c1')), findsNothing);
  });
}
