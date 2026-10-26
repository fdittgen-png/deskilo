// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2373 — Sage 50's export from the register of a British workspace: the
// sheet offers it, the nominal codes are confirmed, and a member with no
// number Sage can key stops the file, named in the snack, with nothing
// saved; with numbers, the 18-column file is saved.
import 'dart:convert';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/money/domain/book_period.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/providers/book_period_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';

/// The export log: the format of each file logged.
class _Log implements BookPeriodRepository {
  final formats = <String>[];

  @override
  Future<String?> recordExport(String workspaceId, BookExportRecord record) async {
    formats.add(record.formatId);
    return 'log-${formats.length}';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      fail('the export called ${invocation.memberName}');
}

final _log = _Log();

Future<List<({String name, String body})>> _export(
  WidgetTester tester, {
  String number = '',
}) async {
  final money = FakeMoneyRepository();
  await money.createInvoice(
    workspaceId: 'ws-1',
    memberId: 'member-1',
    period: '2026-06',
  );
  final invoice = money.invoices[0];
  money.invoices[0] = invoice.copyWith(
    issuedAt: DateTime(2026, 7),
    buyerParty: (invoice.buyerParty ?? const InvoiceParty()).copyWith(
      memberNumber: number,
    ),
  );
  final workspace = FakeWorkspaceRepository.withWorkspace();
  workspace.workspaces[0] = workspace.workspaces[0].copyWith(
    countryCode: 'GB',
    currencyCode: 'EUR',
  );
  final saved = <({String name, String body})>[];
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(money: money, workspace: workspace),
        bookPeriodRepositoryProvider.overrideWithValue(_log),
        typedFileSaverProvider.overrideWithValue(
          ({required bytes, required fileName}) async {
            saved.add((name: fileName, body: utf8.decode(bytes)));
            return SavedFile('Download/$fileName');
          },
        ),
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
  await tester.tap(find.byKey(const ValueKey('accounting-export-sage50')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('sage-accounts-confirm')));
  await tester.pumpAndSettle();
  return saved;
}

void main() {
  testWidgets('a member with no number Sage can key stops the file, named, '
      'and nothing is saved', (tester) async {
    final saved = await _export(tester);
    expect(saved, isEmpty);
    final snack = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(
      (snack.content as Text).data,
      allOf(
        startsWith('The Sage 50 file was not written:'),
        contains('no number Sage can take as its Account Reference'),
      ),
    );
  });

  testWidgets('with the member\'s number, the 18-column file is saved, '
      'keyed by that number', (tester) async {
    final saved = await _export(tester, number: 'M-7');
    final rows = saved.single.body.split('\r\n');
    expect(saved.single.name, startsWith('Sage_Audit_2026'));
    expect(rows.first.split(','), hasLength(18));
    expect(rows[1], startsWith('SI,"M7",4000,'));
    expect(_log.formats.last, 'sage50', reason: 'the file is logged');
  });
}
