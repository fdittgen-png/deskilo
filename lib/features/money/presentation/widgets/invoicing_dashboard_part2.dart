// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'invoicing_dashboard.dart';


/// How old an open invoice has to be before the hub starts pointing at it.
const _overdueDays = 30;

/// The issuer's invoicing summary strip (field request: "everything an
/// invoicing tool would need"): how many months wait to be invoiced and
/// how much is outstanding, at a glance.
///
/// Two pills rather than one grey sentence — and the money turns red once
/// something has been waiting longer than [_overdueDays].
class InvoicingSummaryBar extends ConsumerWidget {
  const InvoicingSummaryBar({super.key, required this.currency});

  final MoneyFormat currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final overview = ref.watch(invoicingOverviewProvider).value;
    if (overview == null) return const SizedBox.shrink();
    if (overview.toInvoice.isEmpty && overview.open.isEmpty) {
      return const SizedBox.shrink();
    }
    // #510 — the two DIRECTIONS of the payment process, separately: what
    // members still owe (positive invoices at their REMAINING value —
    // a €500 invoice with €280 paid counts €220, not €500) and what the
    // workspace owes back (open credit notes, #508).
    int remainingOf(OpenInvoiceEntry e) {
      final match = e.pendingMatch;
      if (match != null &&
          !match.pending &&
          match.resolution == 'under_accepted') {
        return e.invoice.totalCents - match.paidCents;
      }
      return e.invoice.totalCents;
    }

    final collectable =
        overview.open.where((e) => e.invoice.totalCents > 0).toList();
    final refundable =
        overview.open.where((e) => e.invoice.totalCents < 0).toList();
    final toCollect = collectable.fold(0, (sum, e) => sum + remainingOf(e));
    final toRefund =
        refundable.fold(0, (sum, e) => sum - e.invoice.totalCents);
    final now = ref.read(clockProvider).now();
    final overdue = collectable.any(
      (e) => now.difference(e.invoice.issuedAt).inDays >= _overdueDays,
    );
    return Padding(
      key: const ValueKey('invoicing-summary'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          if (overview.toInvoice.isNotEmpty)
            _Pill(
              icon: Icons.pending_actions_outlined,
              text: l10n.invoiceSummaryToInvoice(overview.toInvoice.length),
            ),
          if (collectable.isNotEmpty)
            _Pill(
              icon: Icons.hourglass_bottom_outlined,
              alert: overdue,
              text: l10n.invoiceSummaryOpen(
                    collectable.length,
                    currency.formatMinor(toCollect),
                  ),
            ),
          if (refundable.isNotEmpty)
            _Pill(
              icon: Icons.replay_outlined,
              text: l10n.invoiceSummaryToRefund(
                    refundable.length,
                    currency.formatMinor(toRefund),
                  ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, this.alert = false});

  final IconData icon;
  final String text;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background =
        alert ? colors.errorContainer : colors.surfaceContainerHighest;
    final foreground =
        alert ? colors.onErrorContainer : colors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.xlAll,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: foreground),
        const SizedBox(width: AppSpacing.xs),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
        ),
      ]),
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
    required this.onProforma,
  });

  final MoneyFormat currency;
  final void Function(String memberId, String period) onIssue;

  /// Shares the month as a PROFORMA — what the member will owe, before
  /// anything is issued.
  final void Function(String memberId, String period) onProforma;
  final void Function(List<ToInvoiceEntry> entries, String period)
      onIssueAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(children: [
        // #827 — the guided process, when its flag is on.
        const WizardEntryCard(),
        Expanded(child: _list(context, ref)),
      ]);

  Widget _list(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final overviewAsync = ref.watch(invoicingOverviewProvider);
    final overview = overviewAsync.value;
    if (overview == null) return const LoadingView();
    if (overview.toInvoice.isEmpty) {
      return EmptyState(
        icon: Icons.task_alt_outlined,
        title: l10n.invoiceAllCaughtUp,
      );
    }
    final total =
        overview.toInvoice.fold(0, (sum, e) => sum + e.totalCents);
    return ListView(
      padding: AppSpacing.mdAll,
      children: [

        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  monthLabel(context, overview.period),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                // What the sweep is worth, before it runs.
                Text(
                  currency.formatMinor(total),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          // #1339 — the Column flexes and this did not, so at 2x text
          // the Row ran 15 px over. A no-op at normal scale.
          Flexible(
            child: FilledButton.tonalIcon(
              key: const ValueKey('invoice-issue-all'),
              onPressed: () => onIssueAll(overview.toInvoice, overview.period),
              icon: const Icon(Icons.playlist_add_check_outlined),
              label: Text(l10n.invoiceIssueAll),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        for (final entry in overview.toInvoice)
          Card(
            child: ListTile(
              key: ValueKey('invoice-todo-${entry.memberId}'),
              title: Text(entry.name),
              subtitle: Text(currency.formatMinor(entry.totalCents)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  key: ValueKey('invoice-proforma-${entry.memberId}'),
                  tooltip: l10n.invoiceProformaAction,
                  icon: const Icon(Icons.description_outlined),
                  onPressed: () =>
                      onProforma(entry.memberId, overview.period),
                ),
                FilledButton(
                  key: ValueKey('invoice-issue-${entry.memberId}'),
                  onPressed: () => onIssue(entry.memberId, overview.period),
                  child: Text(l10n.invoiceIssueOne),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}
