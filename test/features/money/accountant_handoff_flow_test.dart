// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1640 — the accountant CSV through the real app: the preflight shows
// before anything is saved, Save writes the file and its report, and a
// document that changes while the owner reviews stops the save.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'package:crypto/crypto.dart';
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';

Future<
  ({FakeMoneyRepository money, List<({String name, Uint8List bytes})> saved})
>
_openPreflight(
  WidgetTester tester, {
  bool failSave = false,
  Future<void> Function(FakeMoneyRepository money)? prepare,
}) async {
  final money = FakeMoneyRepository();
  await money.createInvoice(
    workspaceId: 'ws-1',
    memberId: 'member-1',
    period: '2026-06',
  );
  await money.createInvoice(
    workspaceId: 'ws-1',
    memberId: 'member-1',
    period: '2026-07',
  );
  await prepare?.call(money);
  final saved = <({String name, Uint8List bytes})>[];
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(money: money),
        fileSaverProvider.overrideWithValue(({
          required bytes,
          required fileName,
        }) async {
          if (failSave) throw Exception('disk full');
          saved.add((name: fileName, bytes: bytes));
          return 'Download/$fileName';
        }),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Money'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('money-face-invoices')));
  await tester.pumpAndSettle();
  await openMoneyWorkspaceTools(tester);
  await tester.ensureVisible(find.byKey(const ValueKey('invoices-button')));
  await tester.tap(find.byKey(const ValueKey('invoices-button')));
  await tester.pumpAndSettle();
  await tapInvoicingTool(tester, 'invoice-register-button');
  await tester.tap(find.byKey(const ValueKey('invoice-accounting-export')));
  await tester.pumpAndSettle();
  final option = find.byKey(const ValueKey('accounting-export-accountant_csv'));
  await tester.ensureVisible(option);
  await tester.tap(option);
  await tester.pumpAndSettle();
  return (money: money, saved: saved);
}

void main() {
  testWidgets('the preflight comes first; Save writes the file and its '
      'report', (tester) async {
    final r = await _openPreflight(tester);
    expect(find.byKey(const ValueKey('handoff-preflight')), findsOneWidget);
    expect(r.saved, isEmpty, reason: 'nothing is saved before Save');
    await tester.tap(find.byKey(const ValueKey('handoff-save')));
    await tester.pumpAndSettle();
    expect(
      r.saved.single.name,
      endsWith('.zip'),
      reason: 'the file and its report travel as one archive',
    );
    final zip = ZipDecoder().decodeBytes(r.saved.single.bytes);
    final csv = zip.files.singleWhere((f) => f.name.endsWith('.csv'));
    final json = zip.files.singleWhere((f) => f.name == 'report.json');
    final csvText = utf8.decode(csv.content as List<int>);
    expect(csvText, contains('# 2 invoice(s)'));
    final report = jsonDecode(
      utf8.decode(json.content as List<int>),
    ) as Map<String, Object?>;
    expect(report['included'], 2);
    expect(report['clean'], isTrue);
    expect(
      (report['file'] as Map)['sha256'],
      sha256.convert(utf8.encode(csvText)).toString(),
      reason: 'the report names the very bytes beside it',
    );
  });

  testWidgets('a document voided during the review stops the save', (
    tester,
  ) async {
    final r = await _openPreflight(tester);
    await r.money.voidInvoice(r.money.invoices.first.id);
    await tester.tap(find.byKey(const ValueKey('handoff-save')));
    await tester.pumpAndSettle();
    expect(r.saved, isEmpty);
    expect(
      find.textContaining('The invoices changed while you were reviewing'),
      findsOneWidget,
    );
  });

  testWidgets('Cancel in the preflight saves nothing', (tester) async {
    final r = await _openPreflight(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(r.saved, isEmpty);
    expect(find.byKey(const ValueKey('handoff-preflight')), findsNothing);
  });

  testWidgets('a save that fails says so and leaves nothing half-written', (
    tester,
  ) async {
    final r = await _openPreflight(tester, failSave: true);
    await tester.tap(find.byKey(const ValueKey('handoff-save')));
    await tester.pumpAndSettle();
    expect(r.saved, isEmpty);
    expect(tester.takeException(), isNull);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('#1885 — the saved file, read back on its own, accounts for '
      'every document once and each currency apart', (tester) async {
    final r = await _openPreflight(tester, prepare: (money) async {
      await money.createInvoice(
        workspaceId: 'ws-1',
        memberId: 'member-1',
        period: '2026-08',
      );
      // A second currency: never added to the first.
      money.invoices[2] = money.invoices[2].copyWith(currency: 'CHF');
    });
    await tester.tap(find.byKey(const ValueKey('handoff-save')));
    await tester.pumpAndSettle();

    final zip = ZipDecoder().decodeBytes(r.saved.single.bytes);
    final csv = utf8.decode(
      zip.files.singleWhere((f) => f.name.endsWith('.csv')).content as List<int>,
    );
    final report = jsonDecode(utf8.decode(
      zip.files.singleWhere((f) => f.name == 'report.json').content as List<int>,
    )) as Map<String, Object?>;

    // Read independently of the app's own reader: comment lines and the
    // header skipped, then the columns by the header's names.
    final lines = [
      for (final l in const LineSplitter().convert(csv))
        if (l.isNotEmpty && !l.startsWith('#')) l,
    ];
    final header = lines.first.split(',');
    final rows = [for (final l in lines.skip(1)) _cells(l)];
    String col(List<String> row, String name) => row[header.indexOf(name)];

    expect({for (final row in rows) col(row, 'invoice_number')},
        {for (final i in r.money.invoices) i.number},
        reason: 'every issued document, by its number');
    expect(rows.length, r.money.invoices.length, reason: 'and each once');

    int minor(String major) => int.parse(major.replaceAll('.', ''));
    final gross = <String, int>{};
    for (final row in rows) {
      gross.update(col(row, 'currency'), (v) => v + minor(col(row, 'gross')),
          ifAbsent: () => minor(col(row, 'gross')));
    }
    final totals = report['totals'] as Map<String, Object?>;
    expect(gross.keys.toSet(), {'EUR', 'CHF'});
    for (final currency in gross.keys) {
      final issued = (totals[currency] as Map)['issued'] as Map;
      expect(issued['gross_minor'], gross[currency],
          reason: '$currency: the report counts what the file holds');
      expect(issued['gross_minor'], r.money.invoices
          .where((i) => i.currency == currency)
          .fold<int>(0, (sum, i) => sum + i.totalCents),
          reason: '$currency: and what was issued');
    }
  });
}

/// One CSV line's cells, quotes honoured — a reader written here, apart
/// from the app's own, so the file is checked by something it did not make.
List<String> _cells(String line) {
  final cells = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (quoted && ch == '"' && i + 1 < line.length && line[i + 1] == '"') {
      cell.write('"');
      i++;
    } else if (ch == '"') {
      quoted = !quoted;
    } else if (ch == ',' && !quoted) {
      cells.add(cell.toString());
      cell.clear();
    } else {
      cell.write(ch);
    }
  }
  return cells..add(cell.toString());
}
