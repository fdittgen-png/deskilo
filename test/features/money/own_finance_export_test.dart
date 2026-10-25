// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2557 C3 — Me › Finances: one export entry per workspace my documents
// come from; each writes that workspace's documents to one CSV file with
// safe text cells and exact amounts in each currency's own exponent, and
// hands it to the truthful delivery. No total and no other workspace's
// document is in the file.
import 'dart:convert';
import 'dart:typed_data';

import 'package:deskilo/core/demo/data/account_activity_repository.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:deskilo/features/money/domain/own_finance_csv.dart';
import 'package:deskilo/features/money/presentation/screens/my_finances_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/screens/my_finances_screen.dart' show invoice;

List<String> _lines(Uint8List bytes) =>
    utf8.decode(bytes).split('\r\n')..removeLast();

class _Saver {
  SaveOutcome answer = const SavedFile('Download/my-documents.csv');
  final files = <String, Uint8List>{};
  int calls = 0;

  Future<SaveOutcome> save({
    required Uint8List bytes,
    required String fileName,
  }) async {
    calls++;
    files[fileName] = bytes;
    return answer;
  }
}

Future<void> _show(
  WidgetTester tester,
  FinanceOverview overview,
  _Saver saver,
) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          auth: FakeAuthRepository.signedIn(),
          accountActivity: FakeAccountActivityRepository()
            ..financeOverview = overview,
        ),
        fileDeliveryModeProvider.overrideWithValue(FileDeliveryMode.direct),
        typedFileSaverProvider.overrideWithValue(saver.save),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MyFinancesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the CSV of one workspace', () {
    test('amounts are exact numbers in each currency\'s own exponent, '
        'newest first, with no total', () {
      final rows = _lines(
        ownFinanceCsv(
          FinanceOverview(
            invoices: [
              invoice('1'),
              invoice(
                '2',
                currency: 'CHF',
                total: 8000,
                paid: 3000,
                state: FinanceState.partiallyPaid,
              ),
              invoice('3', currency: 'JPY', total: 1200),
              invoice(
                '4',
                currency: 'KWD',
                total: 1234,
                state: FinanceState.paid,
              ),
            ],
          ),
        ),
      );
      expect(
        rows.first,
        'number,workspace,issued_at,due_on,state,currency,total,paid,'
        'remaining,reminders,invoice_id,record,source,paid_at,payment_id,'
        'description',
      );
      expect(rows, hasLength(5));
      // Same issue day: the id breaks the tie.
      expect(
        rows[1],
        startsWith(
          '"INV-1","Office A",2026-09-01T00:00:00.000Z,,open,"EUR",'
          '100.00,0.00,100.00,0,',
        ),
      );
      expect(rows[2], contains(',partially_paid,"CHF",80.00,30.00,50.00,'));
      expect(rows[3], contains(',"JPY",1200,0,1200,'));
      expect(rows[4], contains(',paid,"KWD",1.234,0.000,0.000,'));
      expect(rows.where((r) => r.contains('total')), hasLength(1));
    });

    test('text cells cannot start a formula or break a row', () {
      final evil = FinanceInvoice(
        id: 'x',
        workspaceId: 'ws',
        workspaceName: '=HYPERLINK("http://evil")',
        number: '+1\nINV',
        issuedAt: DateTime.utc(2026, 9),
        totalCents: -500,
        paidCents: 0,
        currency: 'EUR',
        state: FinanceState.refunded,
      );
      final rows = _lines(ownFinanceCsv(FinanceOverview(invoices: [evil])));
      expect(rows, hasLength(2));
      expect(
        rows[1],
        startsWith('"\'+1 INV","\'=HYPERLINK(""http://evil"")",'),
      );
      expect(rows[1], contains(',-5.00,'));
    });

    test('the file name is the workspace and the day, path-safe', () {
      expect(
        ownFinanceCsvName('Café / ../Hall', DateTime(2026, 10, 24)),
        'deskilo-my-documents-caf-hall-2026-10-24.csv',
      );
    });
  });

  group('Me › Finances › Export', () {
    testWidgets('one entry per workspace; each writes only that '
        'workspace\'s documents and says where the file went', (tester) async {
      final saver = _Saver();
      await _show(
        tester,
        FinanceOverview(
          invoices: [
            invoice('1'),
            invoice('2', ws: 'Office B'),
          ],
        ),
        saver,
      );
      await tester.tap(find.byKey(const ValueKey('my-finances-export')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('my-finances-export-ws-Office A')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('my-finances-export-ws-Office B')),
      );
      await tester.pumpAndSettle();
      expect(saver.files, hasLength(1));
      final file = saver.files.entries.single;
      expect(file.key, startsWith('deskilo-my-documents-office-b-'));
      final rows = _lines(file.value);
      expect(rows, hasLength(2));
      expect(rows[1], startsWith('"INV-2","Office B"'));
      expect(find.text('Saved to Download/my-documents.csv'), findsOneWidget);
    });

    testWidgets('a failed save says so and claims nothing', (tester) async {
      final saver = _Saver()..answer = const SaveFailed();
      await _show(tester, FinanceOverview(invoices: [invoice('1')]), saver);
      await tester.tap(find.byKey(const ValueKey('my-finances-export')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('my-finances-export-ws-Office A')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Saved to'), findsNothing);
      expect(saver.calls, 1);
    });

    testWidgets('a browser download is only requested; Download again hands '
        'the same file once more', (tester) async {
      final saver = _Saver()..answer = const DownloadRequested('x.csv');
      await _show(tester, FinanceOverview(invoices: [invoice('1')]), saver);
      await tester.tap(find.byKey(const ValueKey('my-finances-export')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('my-finances-export-ws-Office A')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Saved to'), findsNothing);
      final first = saver.files.values.single;
      await tester.tap(find.byKey(const ValueKey('file-download-again')));
      await tester.pumpAndSettle();
      expect(saver.calls, 2);
      expect(saver.files.values.single, first);
    });

    testWidgets('no document read, no export entry', (tester) async {
      await _show(tester, const FinanceOverview(), _Saver());
      expect(find.byKey(const ValueKey('my-finances-export')), findsNothing);
    });
  });
}
