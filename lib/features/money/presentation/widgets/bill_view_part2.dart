// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'bill_view.dart';


class _PackagesCard extends StatelessWidget {
  const _PackagesCard({required this.entries, required this.money});

  final List<LedgerEntry> entries;
  final String Function(int cents) money;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      key: const Key('packages-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.billPackages,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            for (final entry in entries)
              _BillLine(
                label: entry.description.isEmpty
                    ? (l10n.billPackages)
                    : entry.description,
                value: '−${money(entry.amountCents)}',
              ),
          ],
        ),
      ),
    );
  }
}

class _OpenPositionsCard extends StatelessWidget {
  const _OpenPositionsCard({required this.positions, required this.money});

  final List<OpenPosition> positions;
  final String Function(int cents) money;

  String _label(AppLocalizations l10n, WorkspaceEvent event) {
    switch (event.type) {
      case EventType.serviceCharge:
        final name = event.payload['name'] as String? ?? '';
        final quantity = (event.payload['quantity'] as num?)?.toInt() ?? 0;
        return '$name ×$quantity';
      case EventType.payment:
        return l10n.eventTypePayment;
      case EventType.expense:
        return l10n.eventTypeExpense;
      case EventType.expenseRepartition:
        return l10n.eventTypeExpenseRepartition;
      case EventType.expenseSchedule:
      case EventType.usageCorrection:
      case EventType.usageRecordDelete:
      case EventType.paymentTermsChange:
      case EventType.quota:
        return l10n.eventTypeQuota;
      case EventType.invoiceWriteoff:
      case EventType.invoiceReminder:
      case EventType.priceNegotiation:
      case EventType.reservationDelete:
      case EventType.roleChange:
      case EventType.memberJoin:
      case EventType.reservation:
      case EventType.spaceReservation:
      case EventType.invoicePayment:
      case EventType.invoiceIssue:
      case EventType.invoiceVoid:
      case EventType.refund:
      case EventType.memberStatusChange:
      case EventType.subscriptionChange:
      case EventType.matrixChange || EventType.leaseChange:
      case EventType.adjustment:
      // #1088 — never an open position; the fallback keeps it exhaustive.
      case EventType.unknown:
        return l10n.eventTypeAdjustment;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final pendingColor = Colors.amber.shade800;
    return Card(
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: pendingColor),
        borderRadius: AppRadius.lgAll,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.billOpenPositions,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: pendingColor),
                  ),
                ),
                Chip(
                  label: Text(
                    l10n.billPendingBadge,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: pendingColor),
                  ),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: pendingColor),
                  backgroundColor: scheme.surface,
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (final position in positions) ...[
              _BillLine(
                label: _label(l10n, position.event),
                value: position.isCredit
                    ? '+${money(position.amountCents)}'
                    : '−${money(position.amountCents)}',
              ),
              // #841 — a member waiting on their own payment can see who
              // has already decided and how many are still owed, instead
              // of only that it is "pending".
              EventValidationTrail(
                eventId: position.event.id,
                showTitle: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CreditsCard extends StatelessWidget {
  const _CreditsCard({required this.entries, required this.money});

  final List<LedgerEntry> entries;
  final String Function(int cents) money;

  String _label(AppLocalizations l10n, LedgerEntry entry) {
    return switch (entry.category) {
      LedgerCategory.expense =>
        l10n.ledgerCategoryExpense,
      LedgerCategory.adjustment =>
        l10n.ledgerCategoryAdjustment,
      _ => l10n.ledgerCategoryPayment,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.billPaymentsCredits,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            for (final entry in entries)
              _BillLine(
                label: entry.description.isEmpty
                    ? _label(l10n, entry)
                    : entry.description,
                detail: DateFormat.yMMMd(
                  Localizations.maybeLocaleOf(context)?.toString(),
                ).format(entry.on.toLocal()),
                value: '+${money(entry.amountCents)}',
              ),
          ],
        ),
      ),
    );
  }
}

class _BalanceFooter extends StatelessWidget {
  const _BalanceFooter({
    required this.statement,
    required this.settlement,
    required this.money, this.prominent = false,
  });
  final Statement statement;
  /// When set, the invoice decides settled/outstanding and the amount
  /// shown is its remainder — not the month's ledger arithmetic (#510).
  final PeriodSettlement? settlement;
  final String Function(int cents) money;
  final bool prominent;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    // Sign convention stays the statement's: negative = the member
    // owes. An open credit note reads as a positive balance — money the
    // workspace owes back — and never as outstanding.
    final balanceCents = settlement != null
        ? -settlement!.remainingCents
        : statement.balanceCents;
    final isSettled = balanceCents >= 0;
    final color = isSettled ? scheme.primary : scheme.error;
    final style = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.bold, color: color);
    final content = <Widget>[
            Text(l10n.billBalance, style: prominent
                ? Theme.of(context).textTheme.titleMedium : style),
            Chip(
              label: Text(
                isSettled ? (l10n.billSettled)
                    : (l10n.billOutstanding),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
              ),
              visualDensity: VisualDensity.compact,
              side: BorderSide(color: color),
            ),
            Text(money(balanceCents), style: prominent
                ? Theme.of(context).textTheme.headlineSmall?.strong.copyWith(color: color)
                : style),
    ];
    return Card(
      key: prominent ? const ValueKey('money-month-balance') : null,
      color: prominent ? scheme.surfaceContainer : null,
      child: Padding(
        padding: prominent ? AppSpacing.xlAll : const EdgeInsets.all(16),
        child: prominent ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center, children: content.take(2).toList()),
          const SizedBox(height: AppSpacing.md),
          content.last,
        ]) : Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center, children: content),
      ),
    );
  }
}

class _BillLine extends StatelessWidget {
  const _BillLine({
    required this.label,
    required this.value,
    this.detail,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final String? detail;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final style = emphasized ? theme.titleSmall : theme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: style),
                if (detail != null)
                  Text(detail!, style: theme.bodySmall),
              ],
            ),
          ),
          Text(value, style: style),
        ],
      ),
    );
  }
}
