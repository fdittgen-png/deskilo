// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/workspace_permission.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/invoice.dart';
import '../../domain/invoice_ubl.dart';
import '../../providers/money_providers.dart';
import '../invoice_status.dart';
import '../period_label.dart';
import 'invoice_detail_sheet.dart';

/// #720 — the Invoices face lists MY documents right there, newest
/// first, each opening the same detail sheet the register uses. RLS
/// already scopes [invoicesProvider] to what the caller may read: a
/// member sees their own, an issuer sees everyone's — so the list is
/// filtered to the subject on the client only to keep an issuer's own
/// face about THEM, never as an access rule.
class MyInvoicesList extends ConsumerWidget {
  const MyInvoicesList({super.key, required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final invoices = (ref.watch(invoicesProvider).value ?? const [])
        .where((i) => i.memberId == memberId)
        .toList()
      ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
    final matches = ref.watch(invoiceMatchesProvider).value ?? const {};
    final dateFormat = DateFormat.yMMMd(
      Localizations.maybeLocaleOf(context)?.toString(),
    );
    if (invoices.isEmpty) {
      return Padding(
        key: const ValueKey('my-invoices-empty'),
        padding: AppSpacing.mdAll,
        child: Text(
          l10n?.moneyNoInvoicesYet ??
              'No invoice yet — the month is invoiced by the workspace once '
                  'it closes.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final invoice in invoices)
          Card(
            child: ListTile(
              key: ValueKey('my-invoice-${invoice.id}'),
              onTap: () => _open(context, ref, invoice, matches[invoice.id]),
              title: Wrap(
                spacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    invoice.number,
                    style: invoice.isVoided
                        ? const TextStyle(
                            decoration: TextDecoration.lineThrough)
                        : null,
                  ),
                  InvoiceStatusChip(
                    status: invoiceLifecycleOf(invoice, matches[invoice.id]),
                  ),
                ],
              ),
              subtitle: Text([
                invoicePeriodLabel(context, invoice),
                dateFormat.format(invoice.issuedAt),
              ].join(' · ')),
              trailing: Text(
                moneyFormat(invoice.currency).formatMinor(invoice.totalCents),
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    Invoice invoice,
    InvoiceMatch? match,
  ) async {
    final country = ref.read(currentWorkspaceProvider).value?.countryCode ?? '';
    await showInvoiceDetailSheet(
      context,
      invoice: invoice,
      match: match,
      canIssue: ref
          .read(myPermissionsProvider)
          .contains(WorkspacePermission.issueInvoices),
      isEu: isEuCountry(country),
    );
  }
}
