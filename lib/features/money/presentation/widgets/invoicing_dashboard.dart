// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/money_providers.dart';

/// The issuer's invoicing summary strip (field request: "everything an
/// invoicing tool would need"): how many months wait to be invoiced
/// and how much is outstanding, at a glance.
class InvoicingSummaryBar extends ConsumerWidget {
  const InvoicingSummaryBar({super.key, required this.currency});

  final NumberFormat currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final overview = ref.watch(invoicingOverviewProvider).value;
    if (overview == null) return const SizedBox.shrink();
    final outstanding =
        overview.open.fold(0, (sum, e) => sum + e.liveSoldeCents);
    final parts = <String>[
      if (overview.toInvoice.isNotEmpty)
        l10n?.invoiceSummaryToInvoice(overview.toInvoice.length) ??
            '${overview.toInvoice.length} to invoice',
      if (overview.open.isNotEmpty)
        l10n?.invoiceSummaryOpen(
              overview.open.length,
              currency.format(outstanding / 100),
            ) ??
            '${overview.open.length} open · '
                '${currency.format(outstanding / 100)} outstanding',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Text(
        parts.join('   ·   '),
        key: const ValueKey('invoicing-summary'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// TO INVOICE: the previous month's uninvoiced members, each with the
/// derived total, a per-member Issue button and an Invoice-all sweep.
class ToInvoiceTab extends ConsumerWidget {
  const ToInvoiceTab({
    super.key,
    required this.currency,
    required this.onIssue,
    required this.onIssueAll,
  });

  final NumberFormat currency;
  final void Function(String memberId, String period) onIssue;
  final void Function(List<ToInvoiceEntry> entries, String period)
      onIssueAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final overviewAsync = ref.watch(invoicingOverviewProvider);
    final overview = overviewAsync.value;
    if (overview == null) return const LoadingView();
    if (overview.toInvoice.isEmpty) {
      return EmptyState(
        icon: Icons.task_alt_outlined,
        title: l10n?.invoiceAllCaughtUp ??
            'All caught up — nothing to invoice.',
      );
    }
    final monthLabel = _monthLabel(context, overview.period);
    return ListView(
      padding: AppSpacing.mdAll,
      children: [
        Row(children: [
          Expanded(
            child: Text(
              monthLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          FilledButton.tonalIcon(
            key: const ValueKey('invoice-issue-all'),
            onPressed: () =>
                onIssueAll(overview.toInvoice, overview.period),
            icon: const Icon(Icons.playlist_add_check_outlined),
            label: Text(l10n?.invoiceIssueAll ?? 'Invoice all'),
          ),
        ]),
        const SizedBox(height: 4),
        for (final entry in overview.toInvoice)
          Card(
            child: ListTile(
              key: ValueKey('invoice-todo-${entry.memberId}'),
              title: Text(entry.name),
              subtitle: Text(currency.format(entry.totalCents / 100)),
              trailing: FilledButton(
                key: ValueKey('invoice-issue-${entry.memberId}'),
                onPressed: () => onIssue(entry.memberId, overview.period),
                child: Text(l10n?.invoiceIssueOne ?? 'Issue'),
              ),
            ),
          ),
      ],
    );
  }
}

/// OPEN: issued invoices whose month still carries a positive LIVE
/// solde — with age, reminder history and a direct Remind button.
class OpenInvoicesTab extends ConsumerWidget {
  const OpenInvoicesTab({
    super.key,
    required this.currency,
    required this.onRemind,
  });

  final NumberFormat currency;
  final void Function(OpenInvoiceEntry entry) onRemind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final overview = ref.watch(invoicingOverviewProvider).value;
    final reminders =
        ref.watch(invoiceRemindersProvider).value ?? const {};
    if (overview == null) return const LoadingView();
    if (overview.open.isEmpty) {
      return EmptyState(
        icon: Icons.price_check_outlined,
        title: l10n?.invoiceNoOpen ?? 'No open invoices.',
      );
    }
    final dateFormat = DateFormat.yMMMd(
      Localizations.maybeLocaleOf(context)?.toString(),
    );
    return ListView(
      padding: AppSpacing.mdAll,
      children: [
        for (final entry in overview.open)
          Card(
            key: ValueKey('invoice-open-${entry.invoice.id}'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        '${entry.invoice.number} · '
                        '${entry.invoice.memberName}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      currency.format(entry.liveSoldeCents / 100),
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    Expanded(
                      child: Text(
                        [
                          dateFormat.format(entry.invoice.issuedAt),
                          l10n?.invoiceOpenAge(DateTime.now()
                                  .difference(entry.invoice.issuedAt)
                                  .inDays) ??
                              '${DateTime.now().difference(entry.invoice.issuedAt).inDays}d',
                          if (reminders[entry.invoice.id] != null)
                            l10n?.invoiceRemindedBadge(
                                    reminders[entry.invoice.id]!.count) ??
                                'Reminded ×'
                                    '${reminders[entry.invoice.id]!.count}',
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    TextButton(
                      key: ValueKey('invoice-remind-${entry.invoice.id}'),
                      onPressed: () => onRemind(entry),
                      child: Text(
                          l10n?.invoiceRemindAction ?? 'Send a reminder'),
                    ),
                  ]),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

String _monthLabel(BuildContext context, String period) {
  final parts = period.split('-');
  return DateFormat.yMMMM(
    Localizations.maybeLocaleOf(context)?.toString(),
  ).format(DateTime(int.parse(parts[0]), int.parse(parts[1])));
}
