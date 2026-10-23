// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2362 -- the VAT declarations screen offers the sales-tax worksheet of the
// period to a seller whose country's issuing gate says `sales_tax` (and not
// to anyone else), and saves the server's figures as a CSV; a period with no
// sales-tax invoice says so instead of saving an empty file.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/data/sales_tax_repository.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/sales_tax_return.dart';
import 'package:deskilo/features/money/providers/sales_tax_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

/// The installed snapshot plus a US gate row in sales-tax mode.
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

Future<List<({String name, Uint8List bytes})>> _open(
  WidgetTester tester, {
  required String country,
  required String currency,
  required FakeSalesTaxRepository sales,
}) async {
  final workspace = FakeWorkspaceRepository.withWorkspace();
  workspace.workspaces[0] = workspace.workspaces[0].copyWith(
    countryCode: country,
    currencyCode: currency,
    vatRegime: 'vat_registered',
  );
  final saved = <({String name, Uint8List bytes})>[];
  await tester.binding.setSurfaceSize(const Size(900, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          money: FakeMoneyRepository(),
          workspace: workspace,
        ),
        salesTaxRepositoryProvider.overrideWithValue(sales),
        typedFileSaverProvider.overrideWithValue(({
          required bytes,
          required fileName,
        }) async {
          saved.add((name: fileName, bytes: bytes));
          return SavedFile(fileName);
        }),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(Scaffold).first);
  unawaited(GoRouter.of(context).push('/vat-declarations'));
  await tester.pumpAndSettle();
  return saved;
}

void main() {
  const button = ValueKey('sales-tax-worksheet-csv');
  late TaxReferenceSet previous;

  setUp(() {
    previous = ActiveTaxReference.current;
    ActiveTaxReference.install(_withUsGate(previous));
  });
  tearDown(() => ActiveTaxReference.install(previous));

  testWidgets('a US seller saves the worksheet of the period', (tester) async {
    final sales = FakeSalesTaxRepository()
      ..rows.add(
        const SalesTaxReturnRow(
          state: 'NY',
          line: SalesTaxLine.taxable,
          baseCents: 10000,
          taxCents: 888,
          invoiceCount: 1,
        ),
      );
    final saved = await _open(
      tester,
      country: 'US',
      currency: 'USD',
      sales: sales,
    );
    await tester.ensureVisible(find.byKey(button));
    await tester.tap(find.byKey(button));
    await tester.pumpAndSettle();
    expect(saved, hasLength(1));
    expect(saved.single.name, startsWith('sales-tax-worksheet-'));
    expect(
      utf8.decode(saved.single.bytes),
      contains('"NY",taxable,,,,100.00,8.88,1'),
    );
  });

  testWidgets('a period with nothing to state saves nothing and says so', (
    tester,
  ) async {
    final saved = await _open(
      tester,
      country: 'US',
      currency: 'USD',
      sales: FakeSalesTaxRepository(),
    );
    await tester.ensureVisible(find.byKey(button));
    await tester.tap(find.byKey(button));
    await tester.pumpAndSettle();
    expect(saved, isEmpty);
    expect(
      find.text('No sales-tax invoice was issued in this period.'),
      findsOneWidget,
    );
  });

  testWidgets('a seller under VAT is not offered it', (tester) async {
    await _open(
      tester,
      country: 'FR',
      currency: 'EUR',
      sales: FakeSalesTaxRepository(),
    );
    expect(find.byKey(button), findsNothing);
  });
}
