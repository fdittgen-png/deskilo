// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1640 — the preflight shows what the accountant file holds before it is
// saved; a blocking finding keeps Save disabled, Cancel saves nothing.
import 'package:deskilo/features/money/domain/accountant_csv.dart';
import 'package:deskilo/features/money/domain/accountant_handoff.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/presentation/widgets/accountant_handoff_preflight.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Invoice _inv(String id, {String currency = 'EUR'}) => Invoice(
  id: id,
  workspaceId: 'ws',
  memberId: 'm',
  number: 'INV-$id',
  issuedAt: DateTime.utc(2026, 3, 1),
  title: 'March',
  lines: const [InvoiceLine(label: 'Desk', amountCents: 5000)],
  totalCents: 5000,
  currency: currency,
  memberName: 'A',
  memberAddress: '',
  workspaceName: 'W',
  workspaceAddress: '',
  issuerName: 'O',
  signature: '',
);

AccountantHandoff _report(List<Invoice> invoices) {
  final csv = buildAccountantCsv(
    invoices: invoices,
    matches: const {},
    generatedAt: DateTime.utc(2026, 4),
    workspaceName: 'W',
  );
  return buildAccountantHandoff(
    invoices: invoices,
    matches: const {},
    csv: csv,
    generatedAt: DateTime.utc(2026, 4),
  );
}

Future<List<bool>> _open(WidgetTester tester, AccountantHandoff report) async {
  final results = <bool>[];
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => results.add(
            await showAccountantHandoffPreflight(context, report),
          ),
          child: const Text('go'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
  return results;
}

void main() {
  testWidgets('a clean file shows its counts and totals, and Save saves', (
    tester,
  ) async {
    final results = await _open(tester, _report([_inv('1'), _inv('2')]));
    expect(find.text('2 document(s) in the file'), findsOneWidget);
    expect(find.textContaining('100.00 EUR'), findsOneWidget);
    expect(find.byKey(const ValueKey('handoff-blocked')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('handoff-save')));
    await tester.pumpAndSettle();
    expect(results, [true]);
  });

  testWidgets('a blocking finding is named and Save stays disabled', (
    tester,
  ) async {
    final results = await _open(tester, _report([_inv('1', currency: '')]));
    expect(find.text('INV-1: no currency'), findsOneWidget);
    expect(find.byKey(const ValueKey('handoff-blocked')), findsOneWidget);
    final save = tester.widget<FilledButton>(
      find.byKey(const ValueKey('handoff-save')),
    );
    expect(save.onPressed, isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(results, [false]);
  });
}
