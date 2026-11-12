// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3606 — the invoice register as a records table, its first consumer. The
// export of a selection carries exactly the selected invoices: after a
// filter change (a hidden row leaves the selection) and after a reload (a
// row that is gone is dropped, and the table says so). The footer totals
// per currency, says what it adds up, and never sums two currencies.
import 'dart:convert';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

Finder _k(String key) => find.byKey(ValueKey(key));

Finder _tick(String id) =>
    find.descendant(of: _k('records-row-$id'), matching: find.byType(Checkbox));

/// Three invoices for three members; the second in Swiss francs.
Future<FakeMoneyRepository> _money() async {
  final money = FakeMoneyRepository();
  for (final member in ['member-1', 'member-2', 'member-3']) {
    await money.createInvoice(
      workspaceId: 'ws-1',
      memberId: member,
      period: kTestPeriod,
    );
  }
  money.invoices[1] = money.invoices[1].copyWith(currency: 'CHF');
  return money;
}

Future<List<({String name, String body})>> _pump(
  WidgetTester tester,
  FakeMoneyRepository money,
) async {
  SharedPreferences.setMockInitialValues({});
  final saved = <({String name, String body})>[];
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(money: money),
        typedFileSaverProvider.overrideWithValue(({
          required bytes,
          required fileName,
        }) async {
          saved.add((name: fileName, body: utf8.decode(bytes)));
          return SavedFile('Download/$fileName');
        }),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  ProviderScope.containerOf(tester.element(find.byType(DeskiloApp)))
      .read(routerProvider)
      .go('/invoice-register');
  await tester.pumpAndSettle();
  return saved;
}

/// Exports the selection as a documents-only SAF-T file.
Future<String> _exportSelection(
  WidgetTester tester,
  List<({String name, String body})> saved,
) async {
  await tester.tap(_k('records-bulk-export'));
  await tester.pumpAndSettle();
  await tester.tap(_k('accounting-export-saft'));
  await tester.pumpAndSettle();
  // The documents-only branch, where the file offers postings too.
  if (_k('saft-documents-only').evaluate().isNotEmpty) {
    await tester.tap(_k('saft-documents-only'));
    await tester.pumpAndSettle();
  }
  expect(saved, isNotEmpty, reason: 'the export wrote a file');
  return saved.last.body;
}

void main() {
  testWidgets('the export carries exactly the selection, after a filter '
      'takes a selected row out of it', (tester) async {
    final money = await _money();
    final saved = await _pump(tester, money);
    final [a, b, c] = money.invoices;
    await tester.tap(_tick(a.id));
    await tester.tap(_tick(b.id));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    // A filter that hides b takes it out of the selection.
    await tester.enterText(_k('records-filter'), a.number);
    await tester.pumpAndSettle();
    final body = await _exportSelection(tester, saved);
    expect(body, contains(a.number));
    expect(body, isNot(contains(b.number)));
    expect(body, isNot(contains(c.number)));
    expect(body, contains('<NumberOfEntries>1</NumberOfEntries>'));
  });

  testWidgets('after a reload without a selected invoice it is dropped, the '
      'table says so, and the export carries the rest', (tester) async {
    final money = await _money();
    final saved = await _pump(tester, money);
    final [a, b, c] = money.invoices;
    await tester.tap(_tick(a.id));
    await tester.tap(_tick(c.id));
    await tester.pumpAndSettle();
    money.invoices.removeWhere((i) => i.id == c.id);
    ProviderScope.containerOf(tester.element(find.byType(DeskiloApp)))
        .invalidate(invoicesProvider);
    await tester.pumpAndSettle();
    expect(_k('records-dropped'), findsOneWidget);
    expect(find.text('1 selected'), findsOneWidget);
    final body = await _exportSelection(tester, saved);
    expect(body, contains(a.number));
    expect(body, isNot(contains(b.number)));
    expect(body, isNot(contains(c.number)));
  });

  testWidgets('two currencies give two totals, each in its own currency, of '
      'what is shown, then of the selection', (tester) async {
    final money = await _money();
    await _pump(tester, money);
    expect(find.text('Total of the rows shown'), findsOneWidget);
    expect(_k('records-total-EUR'), findsOneWidget);
    expect(_k('records-total-CHF'), findsOneWidget);
    expect(find.text('€332.00'), findsOneWidget, reason: '2 × 166.00 EUR');
    final [_, b, _] = money.invoices;
    await tester.tap(_tick(b.id));
    await tester.pumpAndSettle();
    expect(find.text('Total of the selection'), findsOneWidget);
    expect(_k('records-total-EUR'), findsNothing);
    expect(_k('records-total-CHF'), findsOneWidget);
  });
}
