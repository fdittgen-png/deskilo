// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/fec.dart';

/// Which accounting file the period leaves as.
enum AccountingExportFormat {
  /// The OECD's XML — any country, any accountant's software.
  safT,

  /// France's own flat file, the one an audit asks for.
  fec,
}

/// Picks the format. Two standards, and which one you need depends on who
/// is asking: an accountant's software reads SAF-T, a French tax audit
/// demands the FEC.
Future<AccountingExportFormat?> showAccountingExportSheet(
  BuildContext context, {
  required bool offerFec,
}) async {
  final l10n = AppLocalizations.of(context);
  // Nothing to choose outside France.
  if (!offerFec) return AccountingExportFormat.safT;
  return showModalBottomSheet<AccountingExportFormat>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n?.invoiceExportChoose ?? 'Export for accounting',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const ValueKey('accounting-export-saft'),
              onPressed: () =>
                  Navigator.of(context).pop(AccountingExportFormat.safT),
              icon: const Icon(Icons.code_outlined),
              label: Text(
                l10n?.invoiceExportSafT ?? 'SAF-T (XML, international)',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const ValueKey('accounting-export-fec'),
              onPressed: () =>
                  Navigator.of(context).pop(AccountingExportFormat.fec),
              icon: const Icon(Icons.table_chart_outlined),
              label: Text(
                l10n?.invoiceExportFec ?? 'FEC (France, required in an audit)',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Asks which accounts the FEC will book to. A FEC is made of accounting
/// entries, so unlike SAF-T it cannot avoid account numbers — the honest
/// move is to show the ones about to be used and let them be corrected,
/// rather than inventing them behind the owner's back.
Future<FecAccounts?> showFecAccountsDialog(
  BuildContext context, {
  FecAccounts initial = const FecAccounts(),
}) {
  final l10n = AppLocalizations.of(context);
  final customers = TextEditingController(text: initial.customers);
  final revenue = TextEditingController(text: initial.revenue);
  final bank = TextEditingController(text: initial.bank);
  final vat = TextEditingController(text: initial.vat);
  return showDialog<FecAccounts>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n?.fecAccountsTitle ?? 'Accounts to book'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            l10n?.fecAccountsIntro ??
                'A FEC is made of accounting entries, so it needs account '
                    'numbers.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('fec-account-customers'),
            controller: customers,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n?.fecAccountCustomers ?? 'Customers',
            ),
          ),
          TextField(
            key: const ValueKey('fec-account-revenue'),
            controller: revenue,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n?.fecAccountRevenue ?? 'Revenue',
            ),
          ),
          TextField(
            key: const ValueKey('fec-account-vat'),
            controller: vat,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n?.fecAccountVat ?? 'Collected VAT',
            ),
          ),
          TextField(
            key: const ValueKey('fec-account-bank'),
            controller: bank,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n?.fecAccountBank ?? 'Bank',
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          key: const ValueKey('fec-accounts-confirm'),
          onPressed: () => Navigator.of(context).pop(FecAccounts(
            customers: customers.text.trim(),
            revenue: revenue.text.trim(),
            bank: bank.text.trim(),
            vat: vat.text.trim(),
          )),
          child: Text(l10n?.commonSave ?? 'Save'),
        ),
      ],
    ),
  );
}
