// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/links/link_launcher.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/domain/workspace_event.dart';
import '../../../events/presentation/widgets/event_validation_trail.dart';
import '../../../workspace/domain/overage_policy.dart';
import '../../../workspace/domain/payment_instructions.dart';
import '../../domain/bill_sections.dart';
import '../../domain/invoice_line_text.dart';
import '../../domain/ledger_entry.dart';
import '../../domain/money_face.dart';
import '../../domain/statement.dart';
import '../invoice_status.dart';
import '../period_label.dart';
import '../report_strings_l10n.dart';
import 'how_to_pay_tiles.dart';

part 'bill_view_part1.dart';


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
    required this.nowPeriod,
    this.paymentInstructions = const PaymentInstructions(),
    this.onlinePaymentsEnabled = false,
    this.face,
    this.onPayOnline,
    this.settlement,
    // #870 — an association collects a participation.
    this.association = false,
  });


  final Statement statement;
  final List<LedgerEntry> ledger;
  final List<WorkspaceEvent> pendingMoneyEvents;
  final String currencyCode;
  final String memberId;

  /// The running month, read from `clockProvider` by the caller. Open
  /// positions only ever show on the CURRENT period, so letting this
  /// default to the wall clock made the section appear or vanish
  /// depending on the date the test ran.
  final String nowPeriod;

  /// #155 — the workspace's how-to-pay details; rendered below the
  /// balance footer only while the statement is outstanding.
  final PaymentInstructions paymentInstructions;

  /// Whether the workspace enabled online payments (0043 scaffolding). When
  /// true and the statement is outstanding, the how-to-pay card shows a
  /// "Pay online" button that calls [onPayOnline] with the owed amount.
  final bool onlinePaymentsEnabled;

  /// Called with the outstanding amount in cents when the member taps the
  /// online-payment button. Owned by the Money screen (it has the ref to
  /// start the provider order and open the approval URL).
  final void Function(int amountCents)? onPayOnline;

  /// #510 — the invoice covering this month, when one exists. From then
  /// on the DOCUMENT decides whether the month is settled: the payment
  /// that clears it is usually recorded in a later month, so the raw
  /// ledger balance of an invoiced-and-paid month would read
  /// outstanding forever.
  final PeriodSettlement? settlement;

  final bool association;

  /// #720 — render only the cards of one face; null keeps the whole bill
  /// (the flag-off column and the PDF export, which prints everything).
  final MoneyFace? face;


  @override
  Widget build(BuildContext context) {
    final currency = moneyFormat(currencyCode);

    final sections = buildBillSections(
      period: statement.period,
      memberId: memberId,
      ledger: ledger,
      pendingEvents: pendingMoneyEvents,
      nowPeriod: nowPeriod,
    );

    // #720 — the STATEMENT face is the whole bill as it stands; the
    // PAYMENTS face carries the balance and how to settle it. The
    // whole bill (face null) is both, for the classic column and the PDF.
    final showStatement = face == null || face == MoneyFace.statement;
    final showPayments = face == null || face == MoneyFace.payments;
    final balance = _BalanceFooter(statement: statement, settlement: settlement,
        money: currency.formatMinor, prominent: face != null);
    final cards = <Widget>[
      if (face != null && (showStatement || showPayments)) balance,
      if (showStatement) ...[
        // At-a-glance usage for the current month (days included, used and
        // left) — the member's answer to "how much can I still book?".
        _EntitlementCard(statement: statement, money: currency.formatMinor),
        _SubscriptionCard(
            statement: statement,
            money: currency.formatMinor,
            association: association),
        if (sections.serviceEntries.isNotEmpty)
          _ServicesCard(sections: sections, money: currency.formatMinor),
        if (sections.packageEntries.isNotEmpty)
          _PackagesCard(entries: sections.packageEntries, money: currency.formatMinor),
        if (sections.openPositions.isNotEmpty)
          _OpenPositionsCard(positions: sections.openPositions, money: currency.formatMinor),
        if (sections.creditEntries.isNotEmpty)
          _CreditsCard(entries: sections.creditEntries, money: currency.formatMinor),
        if (settlement != null)
          _InvoiceCard(settlement: settlement!, money: currency.formatMinor),
      ],
      if (face == null) balance,
      if (showPayments &&
          // #155 — how to pay, only while something is owed (spec §7:
          // "shown on unpaid statements") and only when the owner configured
          // manual instructions or enabled online payments. An invoiced
          // month owes its invoice REMAINDER, not its ledger balance (#510).
          _owedCents > 0 &&
          (!paymentInstructions.isEmpty ||
              (onlinePaymentsEnabled && onPayOnline != null)))
        HowToPayCard(
          instructions: paymentInstructions,
          onPayOnline: onlinePaymentsEnabled && onPayOnline != null
              ? () => onPayOnline!(_owedCents)
              : null,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          cards[i],
        ],
      ],
    );
  }

  /// What the member still has to pay for this month: the invoice
  /// remainder once a document covers it, the ledger deficit before.
  int get _owedCents => settlement != null
      ? (settlement!.remainingCents > 0 ? settlement!.remainingCents : 0)
      : (statement.isSettled ? 0 : -statement.balanceCents);
}

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
