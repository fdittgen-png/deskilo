// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/accounting_format.dart';

/// Picks the accounting export (#669).
///
/// The sheet's real job is not choosing a file type. It is making sure
/// nobody sends an authority something the app never claimed: each row
/// states what its file IS — the tax office's own format, something an
/// accountant imports and reviews, or a declared subset — because the
/// person tapping is rarely the person who will be asked to defend it.
///
/// Ordered by the registry: the country's regulatory file first when
/// there is one. Someone under audit is looking for one specific thing
/// and should not have to read past three alternatives to find it.
Future<AccountingFormat?> showAccountingExportSheet(
  BuildContext context, {
  required List<AccountingFormat> formats,
}) async {
  if (formats.isEmpty) return null;
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<AccountingFormat>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
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
              for (final format in formats)
                _FormatTile(format: format, l10n: l10n),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FormatTile extends StatelessWidget {
  const _FormatTile({required this.format, required this.l10n});

  final AccountingFormat format;
  final AppLocalizations? l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        key: ValueKey('accounting-export-${format.id}'),
        contentPadding: EdgeInsets.zero,
        leading: Icon(_icon),
        title: Text(_name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_claimText, style: Theme.of(context).textTheme.bodySmall),
            // The certification note is NOT folded into the claim line.
            // "This is Portugal's own format" and "this software is not
            // certified in Portugal" are both true, and an owner who
            // reads only the first has been misled by omission.
            if (format.uncertifiedSoftware)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n?.exportUncertifiedSoftware ??
                      'Built to the published spec, but DesKilo is not '
                          'certified software in this country — check with '
                          'your accountant whether that is required of you.',
                  key: const ValueKey('accounting-export-uncertified'),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.error),
                ),
              ),
          ],
        ),
        onTap: () => Navigator.of(context).pop(format),
      ),
    );
  }

  IconData get _icon => switch (format.id) {
        'fec' || 'datev' || 'sage50' => Icons.table_chart_outlined,
        'saft' || 'saft_pt' => Icons.code_outlined,
        'audit_trail' => Icons.fact_check_outlined,
        _ => Icons.description_outlined,
      };

  String get _name => switch (format.id) {
        'fec' => l10n?.invoiceExportFec ?? 'FEC (France)',
        'saft' => l10n?.invoiceExportSafT ?? 'SAF-T (XML, international)',
        'saft_pt' => l10n?.invoiceExportSafTPt ?? 'SAF-T (Portugal)',
        'datev' => l10n?.invoiceExportDatev ?? 'DATEV (Buchungsstapel)',
        'sage50' => l10n?.invoiceExportSage ?? 'Sage 50 (audit trail)',
        'accountant_csv' =>
          l10n?.invoiceExportAccountantCsv ?? 'Accounting CSV',
        'audit_trail' => l10n?.invoiceExportAuditTrail ?? 'Audit trail',
        _ => format.id,
      };

  /// What the file claims. Deliberately blunt: this is the sentence that
  /// stops someone filing an accountant's working file as a tax return.
  String get _claimText => switch (format.claim) {
        FormatClaim.regulatory => l10n?.exportClaimRegulatory ??
            'The format your tax authority asks for.',
        FormatClaim.exchange => l10n?.exportClaimExchange ??
            'For your accountant to import and review — not a filing.',
        FormatClaim.subset => l10n?.exportClaimSubset ??
            'Invoices and payments only; no general ledger. The file says '
                'so in its header.',
      };
}
