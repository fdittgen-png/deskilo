// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3623 — a bank file dropped onto the statements sheet takes the SAME path
// as a picked one: the format dialog, the import, the same refusals. A
// wrong kind and an oversized file are refused in words, nothing imported.
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/core/demo/data/bank_statement_repository.dart';
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/files/file_drop_backend.dart';
import 'package:deskilo/features/money/domain/bank/bank_import_settings.dart';
import 'package:deskilo/features/money/presentation/widgets/bank_statements_sheet.dart';
import 'package:deskilo/features/money/providers/bank_statement_providers.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_file_drop.dart';

final _camt = File(
  'test/features/money/fixtures/bank/camt054_notification.xml',
).readAsBytesSync();

XFile _dropped(String name) =>
    FakeDroppedFile(name, bytes: Uint8List.fromList(_camt));

void main() {
  late FakeBankStatementRepository bank;
  late FakeFileDrop drop;

  setUp(() {
    final money = FakeMoneyRepository();
    bank = FakeBankStatementRepository(
      money: money,
      today: DateTime.utc(2026, 10, 26),
    );
    drop = FakeFileDrop();
  });

  Future<void> pump(
    WidgetTester tester, {
    int? maxBytes,
    bool canMatch = true,
    bool available = true,
  }) async {
    tester.view.physicalSize = const Size(1200, 3000);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...drop.overrides(available: available),
          bankStatementRepositoryProvider.overrideWithValue(bank),
          invoicesProvider.overrideWith((ref) async => []),
          invoiceMatchesProvider.overrideWith((ref) async => {}),
          if (maxBytes != null)
            bankImportSettingsProvider.overrideWithValue(
              BankImportSettings(maxBytes: maxBytes),
            ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BankStatementsView(
              workspaceId: 'ws-1',
              currency: 'CHF',
              canMatch: canMatch,
              canReconcile: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a dropped bank file goes through the format dialog and is '
      'imported like a picked one', (tester) async {
    await pump(tester);
    drop.drop(DroppedItems([_dropped('notification.xml')]));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bank-format-group')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bank-format-read')));
    await tester.pumpAndSettle();
    expect(
      find.text('Imported: 3 new entries, 0 already known, 0 to review.'),
      findsOneWidget,
    );
    expect(await bank.fetchStatements('ws-1'), hasLength(1));
  });

  testWidgets('a file of another kind is refused and nothing is imported', (
    tester,
  ) async {
    await pump(tester);
    drop.drop(DroppedItems([_dropped('holiday.png')]));
    await tester.pumpAndSettle();
    expect(find.textContaining('takes .xml'), findsOneWidget);
    expect(find.byKey(const ValueKey('bank-format-group')), findsNothing);
    expect(await bank.fetchStatements('ws-1'), isEmpty);
  });

  testWidgets('a file over the bound is refused with the picker\'s sentence', (
    tester,
  ) async {
    await pump(tester, maxBytes: 10);
    drop.drop(DroppedItems([_dropped('notification.xml')]));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'The file is larger than this server imports. Nothing was imported.',
      ),
      findsOneWidget,
    );
    expect(await bank.fetchStatements('ws-1'), isEmpty);
  });

  testWidgets('a sheet that cannot import takes no drop, and a phone has '
      'no zone', (tester) async {
    await pump(tester, canMatch: false);
    expect(drop.present, isFalse);
    await pump(tester, available: false);
    expect(drop.present, isFalse);
    expect(find.byKey(const ValueKey('bank-import')), findsOneWidget);
  });
}
