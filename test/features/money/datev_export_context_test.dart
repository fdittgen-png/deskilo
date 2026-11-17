// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/core/jurisdiction/installed_accounting_formats.dart';
import 'package:deskilo/features/money/presentation/accounting_export_german.dart';
import 'package:deskilo/features/money/presentation/accounting_export_run.dart';
import 'package:deskilo/features/money/presentation/widgets/export_accounts_dialogs.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'support/datev_test_requests.dart';
import 'support/seeded_export_year.dart';

TaxReferenceSet _reference(String chart, String revenue, String bank) =>
    TaxReferenceSet([
      for (final entry in {
        'chart': chart,
        'revenue': revenue,
        'bank': bank,
        'expenses': '4900',
      }.entries)
        TaxReferenceRow(
          country: 'DE',
          key: 'coa/${entry.key}',
          validFrom: '2020-01-01',
          value: AccountMapValue(
            format: 'coa',
            role: entry.key,
            account: entry.value,
          ),
          source: 'held test chart',
          confirmed: true,
        ),
    ]);

DatevPackage _export(AccountingExportRun run, DatevExportSettings settings) =>
    run.datevPackage(
      datev: settings,
      periods: const BookPeriodsOverview(),
      sequences: const [],
      numbers: const {},
    );

void main() {
  testWidgets(
    'the dialog and production DATEV adapter retain A after selecting B',
    (tester) async {
      Workspace business(String id, String country, String currency) =>
          Workspace(
            id: id,
            name: id,
            countryCode: country,
            currencyCode: currency,
            timezone: 'UTC',
            inviteCode: 'INVITE1234',
            defaultLocale: 'en',
          );
      final container = ProviderContainer(
        overrides: standardTestOverrides(
          auth: FakeAuthRepository.signedIn(),
          workspace: FakeWorkspaceRepository(
            workspaces: [
              business('ws-1', 'AT', 'EUR'),
              business('ws-2', 'DE', 'EUR'),
            business('ws-3', 'US', 'USD'),
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
        final invoice = datevGerman(SeededExportYear.acceptanceInvoices.first)
            .copyWith(
              issuedAt: DateTime.utc(2026, 3, 1, 0, 30),
              memberId: 'departed-subject',
            );
        final result =
            AccountingExportRun(context, ref, [invoice], label: 'Export')
              ..taxReference = reference
              ..workspaceDayOf = dayOf
              ..year = 2026
              ..matches = const {}
              ..now = DateTime.utc(2027, 1, 5)
              ..development = false
              ..posted = null
              ..taxPoints = const []
              ..memberNames = const {}
              ..books = (
                invoices: [invoice],
                matches: const {},
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
        // The real start() reads the workspace before opening the format sheet.
        expect(result.workspace.id, container.read(currentWorkspaceProvider).requireValue!.id);
        return result;
      }

      Future<DatevExportSettings> settings(AccountingExportRun run) async {
        final pending = showDatevAccountsDialog(
          context,
          costCentre: run.workspace.name,
          initial: DatevAccounts(
            reference: run.taxReference,
            chartCountry: accountingFormatOf('datev').chartCountry,
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('datev-consultant')),
          '1234567',
        );
        await tester.enterText(
          find.byKey(const ValueKey('datev-client')),
          '54321',
        );
        await tester.tap(find.byKey(const ValueKey('datev-accounts-confirm')));
        await tester.pumpAndSettle();
        return (await pending)!;
      }

      final a = run(
        _reference('SKR03', '8400', '1200'),
        (d) => DateTime(d.year, d.month, d.day),
      );
      final settingsA = await settings(a);
      expect(settingsA.accounts.reference, same(a.taxReference));
      expect(
        settingsA.accounts.chartCountry,
        'DE',
        reason: 'AT uses the declared German chart',
      );
      final firstA = _export(a, settingsA);
      expect(firstA.problems, isEmpty);
      expect(firstA.files.values.join(), contains('Ana Kowalczyk'));
      expect(firstA.files.values.join(), contains('10042'));

      await container.read(activeWorkspaceIdProvider.notifier).select('ws-2');
      await tester.pumpAndSettle();
      final b = run(
        _reference('SKR04', '4400', '1800'),
        (d) => d.subtract(const Duration(hours: 2)),
      );
      final settingsB = await settings(b);
      expect(settingsB.accounts.chart, 'SKR04');
      expect(settingsB.accounts.reference, same(b.taxReference));
      final other = _export(b, settingsB);
      final secondA = _export(a, settingsA);
      expect(other.problems, isEmpty);
      expect(other.files, isNot(firstA.files));
      expect(secondA.problems, isEmpty);
      expect(secondA.files, firstA.files);
      expect(
        firstA.files.keys,
        contains('EXTF_Buchungsstapel_202603_sales.csv'),
      );
      expect(
        other.files.keys,
        contains('EXTF_Buchungsstapel_202602_sales.csv'),
      );
      await container.read(activeWorkspaceIdProvider.notifier).select('ws-3');
      await tester.pumpAndSettle();
      final unsupported = run(b.taxReference, b.workspaceDayOf);
      final refused = _export(unsupported, settingsB);
      expect(refused.problems.whereType<DatevCurrency>(), hasLength(1));
      expect(refused.files, isEmpty);
      expect(_export(a, settingsA).files, firstA.files);
    },
  );
}
