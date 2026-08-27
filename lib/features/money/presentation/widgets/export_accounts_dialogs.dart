// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/datev.dart';
import '../../domain/fec.dart';
import '../../domain/sage.dart';

/// The account dialogs for the three mapped exports (#669).
///
/// FEC, DATEV and Sage all post to a chart of accounts DesKilo does not
/// own. The rule they share, and the reason these dialogs exist at all:
/// **show the numbers before writing the file, never invent them behind
/// the owner\'s back.** Every wrong code has to be unbooked by hand, and
/// the person who unbooks it is not the person who tapped Export.
///
/// The shipped defaults are each country\'s standard chart — the PCG for
/// France, SKR03 for Germany, Sage\'s own nominal ranges for the UK — so
/// the common case is a glance and a confirm rather than four blank
/// fields nobody can fill in.

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

/// The DATEV batch\'s identity and accounts.
///
/// [consultantNumber] and [clientNumber] come from the accountant, and
/// they are REQUIRED: DATEV refuses an import whose numbers do not match
/// the target client. That refusal is the feature — it is what stops a
/// file landing in the wrong company\'s books — so the dialog cannot
/// default them to anything.
class DatevExportSettings {
  const DatevExportSettings({
    required this.accounts,
    required this.consultantNumber,
    required this.clientNumber,
  });

  final DatevAccounts accounts;
  final String consultantNumber;
  final String clientNumber;
}

Future<DatevExportSettings?> showDatevAccountsDialog(
  BuildContext context, {
  DatevAccounts initial = const DatevAccounts(),
}) {
  final l10n = AppLocalizations.of(context);
  final consultant = TextEditingController();
  final client = TextEditingController();
  final customers = TextEditingController(text: initial.customers);
  final revenue = TextEditingController(text: initial.revenue);
  final bank = TextEditingController(text: initial.bank);
  final vat = TextEditingController(text: initial.vat);

  Widget field(String key, TextEditingController controller, String label) =>
      TextField(
        key: ValueKey(key),
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
      );

  return showDialog<DatevExportSettings>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n?.datevAccountsTitle ?? 'DATEV export'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            l10n?.datevAccountsIntro ??
                'Your accountant gives you the consultant and client '
                    'numbers. DATEV refuses a file whose numbers do not '
                    'match — which is what keeps it out of the wrong '
                    'company\'s books.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          field('datev-consultant', consultant,
              l10n?.datevConsultantNumber ?? 'Beraternummer'),
          field('datev-client', client,
              l10n?.datevClientNumber ?? 'Mandantennummer'),
          const SizedBox(height: AppSpacing.md),
          field('datev-account-customers', customers,
              l10n?.fecAccountCustomers ?? 'Debitoren'),
          field('datev-account-revenue', revenue,
              l10n?.fecAccountRevenue ?? 'Erlöse'),
          field('datev-account-vat', vat,
              l10n?.fecAccountVat ?? 'Umsatzsteuer'),
          field('datev-account-bank', bank, l10n?.fecAccountBank ?? 'Bank'),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          key: const ValueKey('datev-accounts-confirm'),
          onPressed: () => Navigator.of(context).pop(DatevExportSettings(
            consultantNumber: consultant.text.trim(),
            clientNumber: client.text.trim(),
            accounts: DatevAccounts(
              customers: customers.text.trim(),
              revenue: revenue.text.trim(),
              bank: bank.text.trim(),
              vat: vat.text.trim(),
            ),
          )),
          child: Text(l10n?.commonSave ?? 'Save'),
        ),
      ],
    ),
  );
}

/// Sage\'s nominal codes. No consultant number here — Sage imports into
/// whichever company file is open, so the safeguard DATEV has does not
/// exist and the accountant is the one who checks.
Future<SageAccounts?> showSageAccountsDialog(
  BuildContext context, {
  SageAccounts initial = const SageAccounts(),
}) {
  final l10n = AppLocalizations.of(context);
  final debtors = TextEditingController(text: initial.debtors);
  final sales = TextEditingController(text: initial.sales);
  final bank = TextEditingController(text: initial.bank);
  final taxCode = TextEditingController(text: initial.taxCode);

  return showDialog<SageAccounts>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n?.sageAccountsTitle ?? 'Sage export'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            l10n?.sageAccountsIntro ??
                'The defaults are Sage\'s own shipped nominal codes. The '
                    'tax code decides which VAT return these land on, so '
                    'check it with your accountant if you are not on the '
                    'standard rate.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('sage-account-debtors'),
            controller: debtors,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n?.fecAccountCustomers ?? 'Debtors',
            ),
          ),
          TextField(
            key: const ValueKey('sage-account-sales'),
            controller: sales,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n?.fecAccountRevenue ?? 'Sales',
            ),
          ),
          TextField(
            key: const ValueKey('sage-account-bank'),
            controller: bank,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n?.fecAccountBank ?? 'Bank',
            ),
          ),
          TextField(
            key: const ValueKey('sage-tax-code'),
            controller: taxCode,
            decoration: InputDecoration(
              labelText: l10n?.sageTaxCode ?? 'VAT code (T1 / T0 / T9)',
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
          key: const ValueKey('sage-accounts-confirm'),
          onPressed: () => Navigator.of(context).pop(SageAccounts(
            debtors: debtors.text.trim(),
            sales: sales.text.trim(),
            bank: bank.text.trim(),
            taxCode: taxCode.text.trim(),
          )),
          child: Text(l10n?.commonSave ?? 'Save'),
        ),
      ],
    ),
  );
}

/// Whether the SAF-T carries derived postings, and to which accounts
/// (#669).
///
/// [withPostings] false is a real answer, not a cancellation: a
/// documents-only SAF-T is the right file for an accountant who will do
/// their own mapping, and it is what this export produced before
/// postings existed. The dialog returning null means the owner backed
/// out, and nothing is written.
class SafTLedgerChoice {
  const SafTLedgerChoice({required this.withPostings, required this.accounts});

  final bool withPostings;
  final FecAccounts accounts;
}

Future<SafTLedgerChoice?> showSafTLedgerDialog(
  BuildContext context, {
  FecAccounts initial = const FecAccounts(),
}) {
  final l10n = AppLocalizations.of(context);
  final customers = TextEditingController(text: initial.customers);
  final revenue = TextEditingController(text: initial.revenue);
  final bank = TextEditingController(text: initial.bank);
  final vat = TextEditingController(text: initial.vat);

  Widget field(String key, TextEditingController controller, String label) =>
      TextField(
        key: ValueKey(key),
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
      );

  return showDialog<SafTLedgerChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n?.saftLedgerTitle ?? 'Include postings?'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            l10n?.saftLedgerIntro ??
                'With account numbers, the file carries double-entry '
                    'postings your accountant can import instead of '
                    'keying in. They cover your sales and the payments '
                    'against them — not your whole books.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          field('saft-account-customers', customers,
              l10n?.fecAccountCustomers ?? 'Customers'),
          field('saft-account-revenue', revenue,
              l10n?.fecAccountRevenue ?? 'Revenue'),
          field('saft-account-vat', vat, l10n?.fecAccountVat ?? 'Collected VAT'),
          field('saft-account-bank', bank, l10n?.fecAccountBank ?? 'Bank'),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        TextButton(
          key: const ValueKey('saft-documents-only'),
          onPressed: () => Navigator.of(context).pop(
            const SafTLedgerChoice(
              withPostings: false,
              accounts: FecAccounts(),
            ),
          ),
          child: Text(l10n?.saftDocumentsOnly ?? 'Documents only'),
        ),
        FilledButton(
          key: const ValueKey('saft-ledger-confirm'),
          onPressed: () => Navigator.of(context).pop(SafTLedgerChoice(
            withPostings: true,
            accounts: FecAccounts(
              customers: customers.text.trim(),
              revenue: revenue.text.trim(),
              bank: bank.text.trim(),
              vat: vat.text.trim(),
            ),
          )),
          child: Text(l10n?.saftWithPostings ?? 'With postings'),
        ),
      ],
    ),
  );
}
