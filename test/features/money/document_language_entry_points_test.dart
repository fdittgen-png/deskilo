// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3850 — every way an issued invoice is rendered reads the language the
// server froze with it: the PDF (download, share, e-mail), the quick view and
// a reminder of it. The invoice below is frozen in French while the business's
// own setting is German and the person looking at it uses the app in Italian,
// so the frozen language differs from both.
import 'dart:typed_data';

import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/presentation/invoice_documents.dart';
import 'package:deskilo/features/money/presentation/invoice_pdf_actions.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/real_async.dart';
import '../../helpers/test_workspace_context.dart';

final _fr = lookupAppLocalizations(const Locale('fr'));
final _de = lookupAppLocalizations(const Locale('de'));
final _it = lookupAppLocalizations(const Locale('it'));

/// A Belgian business whose own document language is German.
FakeWorkspaceRepository _business() {
  final repo = FakeWorkspaceRepository.withWorkspace();
  repo.workspaces[0] = repo.workspaces[0].copyWith(
    countryCode: 'BE',
    defaultLocale: 'de',
  );
  return repo;
}

/// An invoice of that business, frozen in French at issue.
Future<(FakeMoneyRepository, Invoice)> _frozen() async {
  final money = FakeMoneyRepository();
  await money.createInvoice(
    workspaceId: 'ws-1',
    memberId: 'member-1',
    period: '2026-11',
  );
  final invoice = money.invoices.single.copyWith(
    documentLanguage: 'fr',
    formatLocale: 'fr_BE',
  );
  return (money, invoice);
}

/// Runs [action] from a button of an app shown in Italian.
Future<void> _act(
  WidgetTester tester,
  List<Override> overrides,
  Future<void> Function(BuildContext context, WidgetRef ref) action,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              key: const ValueKey('go'),
              onPressed: () => action(context, ref),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('go')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('the PDF is titled in the frozen language', (tester) async {
    final (_, invoice) = await _frozen();
    final workspace = _business().workspaces.single;
    Uint8List? bytes;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            key: const ValueKey('go'),
            onPressed: () async {
              final pdf = await buildInvoicePdfFile(
                context,
                invoice,
                InvoicePdfFileOptions(
                  reference: ActiveTaxReference.current,
                  workspace: workspace,
                ),
              );
              bytes = Uint8List.fromList(pdf.bytes);
            },
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('go')));
      await untilReal(() => bytes != null, what: 'the invoice PDF build');
    });
    expect(bytes, isNotNull);
    // The document's title is written as plain metadata (`/Title`).
    final raw = String.fromCharCodes(bytes!);
    expect(raw, contains(_fr.billInvoiceCard(invoice.number)));
    expect(raw, isNot(contains(_de.billInvoiceCard(invoice.number))));
    expect(raw, isNot(contains(_it.billInvoiceCard(invoice.number))));
  });

  testWidgets('the quick view reads the frozen language', (tester) async {
    final (money, invoice) = await _frozen();
    await _act(tester, [
      ...standardTestOverrides(money: money, workspace: _business()),
      testReadyWorkspaceContext(),
    ], (context, ref) => quickViewInvoice(context, ref, invoice));
    expect(find.byKey(const ValueKey('report-quick-preview')), findsOneWidget);
    // The document's words; the preview's own frame is the interface's.
    expect(find.text(_fr.invoicePdfBilledTo), findsOneWidget);
    expect(find.text(_de.invoicePdfBilledTo), findsNothing);
    expect(find.text(_it.invoicePdfBilledTo), findsNothing);
  });

  testWidgets('a reminder of it is written in the frozen language', (
    tester,
  ) async {
    final (money, invoice) = await _frozen();
    ({String title, String language})? letter;
    await _act(
      tester,
      [
        ...standardTestOverrides(money: money, workspace: _business()),
        testReadyWorkspaceContext(),
      ],
      (context, ref) async {
        await readDocumentPolicies(ref);
        if (!context.mounted) return;
        final r = await reminderLetterReport(
          ref,
          context,
          invoice,
          level: 1,
          reference: ActiveTaxReference.current,
        );
        letter = (title: r.title, language: r.language);
      },
    );
    expect(letter, (title: _fr.reminderPdfTitleFriendly, language: 'fr'));
  });
}
