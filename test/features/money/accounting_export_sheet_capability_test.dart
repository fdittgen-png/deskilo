// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1868 — the export picker states, beside the FEC, that it is not the
// entity's complete books; the generic formats carry no such note.
import 'package:deskilo/features/money/domain/accounting_format.dart';
import 'package:deskilo/features/money/presentation/widgets/accounting_export_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the FEC row says it is not complete books; the CSV does not',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAccountingExportSheet(
              context,
              formats: formatsFor('FR'),
            ),
            child: const Text('open'),
          ),
        ),
      )),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('accounting-export-incomplete-books')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('accounting-export-fec')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('accounting-export-accountant_csv')),
      findsOneWidget,
    );
  });

  testWidgets('a country with no national file shows no incomplete-books note',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAccountingExportSheet(
              context,
              formats: formatsFor('BE'),
            ),
            child: const Text('open'),
          ),
        ),
      )),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('accounting-export-incomplete-books')),
      findsNothing,
    );
  });
}
