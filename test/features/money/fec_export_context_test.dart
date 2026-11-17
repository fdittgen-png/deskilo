// SPDX-License-Identifier: AGPL-3.0-or-later
// The production FEC dialog, document adapter and posted adapter retain the
// captured business facts after another business is selected. Frozen parties
// export without a live member map; unsupported currencies remain refused.
import 'package:deskilo/features/money/application/generic_journal_export.dart';
import 'package:deskilo/features/money/domain/accounting_journals.dart';
import 'package:deskilo/features/money/presentation/accounting_export_fec.dart';
import 'package:deskilo/features/money/presentation/accounting_export_run.dart';
import 'package:deskilo/features/money/presentation/widgets/export_accounts_dialogs.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

TaxReferenceSet _reference(String revenue, String bank) => TaxReferenceSet([
  for (final entry in {
    'coa/customers': '411000',
    'coa/revenue': revenue,
    'coa/bank': bank,
    'coa/vat': '445710',
    'coa/expenses': '606000',
    'fec/vat_pending': '445740',
    'fec/write_off': '654000',
  }.entries)
    TaxReferenceRow(
      country: 'FR',
      key: entry.key,
      validFrom: '2020-01-01',
      value: AccountMapValue(
        format: entry.key.split('/').first,
        role: entry.key.split('/').last,
        account: entry.value,
      ),
      source: 'held test chart',
      confirmed: true,
    ),
]);

FecJournals _journals(String suffix) => FecJournals(
  sales: FecJournal(code: 'VE$suffix', label: 'Sales $suffix'),
  bank: FecJournal(code: 'BQ$suffix', label: 'Bank $suffix'),
  purchases: FecJournal(code: 'AC$suffix', label: 'Purchases $suffix'),
  misc: FecJournal(code: 'OD$suffix', label: 'Misc $suffix'),
);

Invoice _invoice() => Invoice(
  id: 'invoice-a',
  workspaceId: 'issuer-a',
  memberId: 'departed-subject',
  number: 'INV-A',
  issuedAt: DateTime.utc(2026, 3, 1, 0, 30),
  period: '2026-03',
  title: 'Issued service',
  lines: const [
    InvoiceLine(kind: 'service', label: 'Service', amountCents: 10000),
  ],
  totalCents: 10000,
  currency: 'EUR',
  memberName: 'Frozen customer',
  memberAddress: 'Frozen street',
  workspaceName: 'Issuer A',
  workspaceAddress: 'Issuer street',
  issuerName: 'Issuer',
  signature: 'held',
  buyerParty: const InvoiceParty(
    name: 'Frozen customer',
    memberNumber: 'M-0042',
    street: 'Frozen street',
    country: 'FR',
  ),
  sellerParty: const InvoiceParty(name: 'Issuer A', country: 'FR'),
);

List<Posting> _postings(String revenue) => [
  Posting(
    journal: PostingJournal.sales,
    date: DateTime(2026, 3),
    kind: PostingKind.invoice,
    documentId: 'invoice-a',
    documentNumber: 'INV-A',
    lines: [
      PostingLine(
        role: BookRole.customers,
        accountCode: '411000',
        debit: AccountingAmount('EUR', 10000),
        credit: AccountingAmount('EUR', 0),
      ),
      PostingLine(
        role: BookRole.revenue,
        accountCode: revenue,
        debit: AccountingAmount('EUR', 0),
        credit: AccountingAmount('EUR', 10000),
      ),
    ],
  ),
];

void main() {
  testWidgets('FEC dialog and real document/posted adapters keep A after B', (
    tester,
  ) async {
    Workspace business(String id, String currency, String suffix) => Workspace(
      id: id,
      name: id,
      countryCode: 'FR',
      currencyCode: currency,
      timezone: 'UTC',
      inviteCode: 'INVITE1234',
      defaultLocale: 'en',
      accountingJournals: _journals(suffix).toJson(),
    );
    final container = ProviderContainer(
      overrides: standardTestOverrides(
        auth: FakeAuthRepository.signedIn(),
        workspace: FakeWorkspaceRepository(
          workspaces: [
            business('ws-1', 'EUR', 'A'),
            business('ws-2', 'EUR', 'B'),
            business('ws-3', 'USD', 'C'),
          ],
        ),
      ),
    );
    addTearDown(container.dispose);
    late BuildContext context;
    late WidgetRef ref;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (c, r, child) {
              r.watch(currentWorkspaceProvider);
              context = c;
              ref = r;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    AccountingExportRun run(
      TaxReferenceSet reference,
      DateTime Function(DateTime) dayOf,
    ) {
      final invoice = _invoice();
      final matches = {
        invoice.id: InvoiceMatch(
          invoiceId: invoice.id,
          paidCents: 4000,
          resolution: 'partial',
          matchedAt: DateTime(2026, 5),
          writeoffAt: DateTime.utc(2026, 6, 1, 0, 30),
        ),
      };
      final result =
          AccountingExportRun(context, ref, [invoice], label: 'Export')
            ..taxReference = reference
            ..workspaceDayOf = dayOf
            ..year = 2026
            ..matches = matches
            ..company = invoice.sellerParty!
            ..now = DateTime.utc(2027, 1, 5)
            ..development = false
            ..taxPoints = const []
            ..memberNames = const {}
            ..books = (
              invoices: [invoice],
              matches: matches,
              instalments: const {},
              ledger: const [],
              repartitions: const [],
              bookProfiles: const [],
              revisions: (
                settings: 's',
                taxReference: 't',
                bookProfile: 'b',
                calendar: 'c',
              ),
              purchases: const [],
            );
      // start() captures the workspace before any export dialog awaits.
      expect(
        result.workspace.id,
        container.read(currentWorkspaceProvider).requireValue!.id,
      );
      result.posted = JournalPosted(
        _postings(reference.accountOf('coa', 'revenue', 'FR')),
        year: FiscalYear.calendar(2026),
        functionalCurrency: result.workspace.currencyCode,
        parties: const {
          'invoice-a': PostingParty(
            kind: 'customer',
            number: 'M-0042',
            name: 'Frozen customer',
          ),
        },
      );
      return result;
    }

    Future<FecAccounts> accounts(AccountingExportRun run) async {
      final pending = showFecAccountsDialog(
        context,
        initial: fecAccountsOf(
          reference: run.taxReference,
          journals: run.journals,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('fec-accounts-confirm')));
      await tester.pumpAndSettle();
      return (await pending)!;
    }

    String posted(AccountingExportRun run) {
      final result = postedFecOf(
        run.posted! as JournalPosted,
        journals: run.journals,
      );
      expect(result, isA<JournalFile>());
      return (result as JournalFile).content;
    }

    final a = run(
      _reference('706001', '512001'),
      (d) => DateTime(d.year, d.month, d.day),
    );
    final accountsA = await accounts(a);
    expect(accountsA.reference, same(a.taxReference));
    expect(accountsA.journals, a.journals);
    final firstA = a.documentFec(accountsA), firstPostedA = posted(a);
    expect(firstA, contains('departed-subject'));
    expect(firstA, contains('Frozen customer'));
    expect(firstA, contains('20260601'));
    expect(firstA, contains('BQA'));
    expect(firstPostedA, contains('411M0042'));

    await container.read(activeWorkspaceIdProvider.notifier).select('ws-2');
    await tester.pumpAndSettle();
    final b = run(
      _reference('706002', '512002'),
      (d) => d.subtract(const Duration(hours: 2)),
    );
    final accountsB = await accounts(b);
    final other = b.documentFec(accountsB), otherPosted = posted(b);
    expect(other, isNot(firstA));
    expect(other, contains('20260531'));
    expect(other, contains('706002'));
    expect(otherPosted, isNot(firstPostedA));
    expect(a.documentFec(accountsA), firstA);
    expect(posted(a), firstPostedA);

    await container.read(activeWorkspaceIdProvider.notifier).select('ws-3');
    await tester.pumpAndSettle();
    final unsupported = run(b.taxReference, b.workspaceDayOf);
    expect(() => unsupported.documentFec(accountsB), throwsArgumentError);
    expect(
      postedFecOf(
        unsupported.posted! as JournalPosted,
        journals: unsupported.journals,
      ),
      isA<JournalRefused>(),
    );
    expect(a.documentFec(accountsA), firstA);
    expect(posted(a), firstPostedA);
  });
}
