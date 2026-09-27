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

Future<
  ({FakeMoneyRepository money, List<({String name, Uint8List bytes})> saved})
>
_openPreflight(WidgetTester tester) async {
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
  await tester.ensureVisible(find.byKey(const ValueKey('invoices-button')));
  await tester.tap(find.byKey(const ValueKey('invoices-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('invoice-register-button')));
  await tester.pumpAndSettle();
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
}
