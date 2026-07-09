// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/domain/workspace_event.dart';
import '../../domain/bill_sections.dart';
import '../../domain/ledger_entry.dart';
import '../../domain/statement.dart';

/// The structured monthly bill (#132, ADR 0008): subscription, consumed
/// services, open positions awaiting validation, payments & credits, and
/// the balance footer. Grouping lives in [buildBillSections] so the PDF
/// export renders the exact same sections.
class BillView extends StatelessWidget {
  const BillView({
    super.key,
    required this.statement,
    required this.ledger,
    required this.pendingMoneyEvents,
    required this.currencyCode,
    required this.memberId,
  });

  final Statement statement;
  final List<LedgerEntry> ledger;
  final List<WorkspaceEvent> pendingMoneyEvents;
  final String currencyCode;
  final String memberId;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(name: currencyCode);
    String money(int cents) => currency.format(cents / 100);

    final sections = buildBillSections(
      period: statement.period,
      memberId: memberId,
      ledger: ledger,
      pendingEvents: pendingMoneyEvents,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SubscriptionCard(statement: statement, money: money),
        if (sections.serviceEntries.isNotEmpty) ...[
          const SizedBox(height: 8),
          _ServicesCard(sections: sections, money: money),
        ],
        if (sections.openPositions.isNotEmpty) ...[
          const SizedBox(height: 8),
          _OpenPositionsCard(positions: sections.openPositions, money: money),
        ],
        if (sections.creditEntries.isNotEmpty) ...[
          const SizedBox(height: 8),
          _CreditsCard(entries: sections.creditEntries, money: money),
        ],
        const SizedBox(height: 8),
        _BalanceFooter(statement: statement, money: money),
      ],
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.statement, required this.money});

  final Statement statement;
  final String Function(int cents) money;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BillLine(
              label: l10n?.billSubscription(statement.subscriptionPct) ??
                  'Subscription ${statement.subscriptionPct}%',
              value: '−${money(statement.feeCents)}',
              emphasized: true,
            ),
            _BillLine(
              label: l10n?.billEntitlement(
                    statement.usedHalfDays,
                    statement.includedHalfDays,
                    statement.openDays,
                  ) ??
                  '${statement.usedHalfDays} of '
                      '${statement.includedHalfDays} half-days used '
                      '(${statement.openDays} open days)',
              value: '',
            ),
            if (statement.extraHalfDays > 0)
              _BillLine(
                label: l10n?.billOverage(statement.extraHalfDays) ??
                    '${statement.extraHalfDays} extra half-days',
                value: '−${money(statement.overageCents)}',
              ),
          ],
        ),
      ),
    );
  }
}

class _ServicesCard extends StatelessWidget {
  const _ServicesCard({required this.sections, required this.money});

  final BillSections sections;
  final String Function(int cents) money;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.billServices ?? 'Consumed services',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            for (final entry in sections.serviceEntries)
              _BillLine(
                label: entry.description.isEmpty
                    ? (l10n?.ledgerCategoryService ?? 'Service')
                    : entry.description,
                value: '−${money(entry.amountCents)}',
              ),
            const Divider(),
            _BillLine(
              label: l10n?.billServicesTotal ?? 'Services total',
              value: '−${money(sections.servicesTotalCents)}',
              emphasized: true,
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

  String _label(AppLocalizations? l10n, WorkspaceEvent event) {
    switch (event.type) {
      case EventType.serviceCharge:
        final name = event.payload['name'] as String? ?? '';
        final quantity = (event.payload['quantity'] as num?)?.toInt() ?? 0;
        return '$name ×$quantity';
      case EventType.payment:
        return l10n?.eventTypePayment ?? 'Payment';
      case EventType.expense:
        return l10n?.eventTypeExpense ?? 'Expense';
      case EventType.reservation:
      case EventType.adjustment:
        return l10n?.eventTypeAdjustment ?? 'Adjustment';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                    l10n?.billOpenPositions ?? 'Open positions',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: pendingColor),
                  ),
                ),
                Chip(
                  label: Text(
                    l10n?.billPendingBadge ?? 'pending validation',
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
            for (final position in positions)
              _BillLine(
                label: _label(l10n, position.event),
                value: position.isCredit
                    ? '+${money(position.amountCents)}'
                    : '−${money(position.amountCents)}',
              ),
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

  String _label(AppLocalizations? l10n, LedgerEntry entry) {
    return switch (entry.category) {
      LedgerCategory.expense =>
        l10n?.ledgerCategoryExpense ?? 'Expense reimbursement',
      LedgerCategory.adjustment =>
        l10n?.ledgerCategoryAdjustment ?? 'Adjustment',
      _ => l10n?.ledgerCategoryPayment ?? 'Payment',
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.billPaymentsCredits ?? 'Payments & credits',
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
                ).format(entry.createdAt.toLocal()),
                value: '+${money(entry.amountCents)}',
              ),
          ],
        ),
      ),
    );
  }
}

class _BalanceFooter extends StatelessWidget {
  const _BalanceFooter({required this.statement, required this.money});

  final Statement statement;
  final String Function(int cents) money;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final color = statement.isSettled ? scheme.primary : scheme.error;
    final style = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.bold, color: color);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(l10n?.billBalance ?? 'Balance', style: style),
            ),
            Chip(
              label: Text(
                statement.isSettled
                    ? (l10n?.billSettled ?? 'Settled')
                    : (l10n?.billOutstanding ?? 'Outstanding'),
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: color),
              ),
              visualDensity: VisualDensity.compact,
              side: BorderSide(color: color),
            ),
            const SizedBox(width: 12),
            Text(money(statement.balanceCents), style: style),
          ],
        ),
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
