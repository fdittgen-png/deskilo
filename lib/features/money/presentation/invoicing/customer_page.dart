// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-g -- one customer: what they owe per currency (never summed), their
// credit (the payments no invoice has taken), their invoices in the words of the
// home's lines, and their story; the customer's one next action sits in the
// bottom bar. Everything comes in as data, and nothing here is decided by a
// window width: the same page is a screen on a phone and, later, a panel beside
// the list.
import 'package:flutter/material.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/personal_theme.dart';
import '../../../../core/ui/kit/bottom_action_bar.dart';
import '../../../../core/ui/kit/kit_card.dart';
import '../../../../core/ui/kit/split_bar.dart';
import '../../../../core/ui/kit/status_chip.dart';
import '../../../../core/ui/kit/story.dart';
import '../../../../core/ui/kit/two_line_row.dart';
import '../../application/payment_candidates.dart';
import '../../application/receivables.dart';
import '../../application/receivables_answers.dart';
import 'invoicing_dates.dart';
import 'invoicing_words.dart';

class CustomerPage extends StatelessWidget {
  const CustomerPage({
    super.key,
    required this.customerId,
    required this.receivables,
    required this.today,
    required this.mode,
    required this.onOpenInvoice,
    required this.onAction,
    this.credit,
  });

  final String customerId;

  /// Every invoice the home reads; the page keeps this customer's.
  final List<Receivable> receivables;
  final DateTime today;
  final ReminderMode mode;
  final ValueChanged<String> onOpenInvoice;

  /// The customer's one next action (Share reminder, Confirm, Match).
  final ValueChanged<InvoiceAction> onAction;

  /// The credit per currency in minor units; null while it was not read: no
  /// figure is shown that was not read.
  final Map<String, int>? credit;

  List<Receivable> get _mine => [
    for (final r in receivables)
      if (r.customerId == customerId && r.stage != ReceivableStage.draft) r,
  ]..sort((a, b) => b.issuedOn.compareTo(a.issuedOn));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final mine = _mine;
    final name = mine.isEmpty ? '' : mine.first.customerName;
    final row = customerRowsOf(
      mine,
      today: today,
      mode: mode,
    ).where((r) => r.customerId == customerId).firstOrNull;
    // We do not chase a customer whose money we hold unassigned: while they
    // do (in a currency they have an open invoice in), the page's action is to
    // match it; Remind stays on the invoice's own page.
    final holds =
        credit != null &&
        holdsUnassignedMoney(credit: credit!, customerInvoices: mine);
    final action = holds
        ? InvoiceAction.match
        // Not read yet: who holds money is unknown, so nobody is reminded.
        : credit == null && row?.action == InvoiceAction.shareReminder
        ? null
        : row?.action;
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: AppSpacing.mdAll,
              children: [
                _owed(context, mine),
                if (credit case final held? when held.values.any((v) => v > 0))
                  ..._credit(context, held, holds: holds),
                const SizedBox(height: AppSpacing.md),
                KitLabel(l.customerPageInvoices),
                const SizedBox(height: AppSpacing.sm),
                RowList(rows: [for (final r in mine) _line(context, r)]),
                const SizedBox(height: AppSpacing.md),
                KitLabel(l.customerPageStory),
                const SizedBox(height: AppSpacing.sm),
                _story(context, mine, row),
              ],
            ),
          ),
          if (action != null)
            BottomActionBar(
              actions: [
                FilledButton(
                  key: const ValueKey('customer-page-action'),
                  onPressed: () => onAction(action),
                  child: Text(switch (action) {
                    InvoiceAction.shareReminder => l.invoicingActionRemind,
                    InvoiceAction.confirmPayment => l.invoicingActionConfirm,
                    _ when holds => l.customerPageMatch,
                    _ => l.invoicingActionMatch,
                  }),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// One block per currency: its total, the bar of its three parts and its
  /// legend lines. Nothing owed says so.
  Widget _owed(BuildContext context, List<Receivable> mine) {
    final l = context.l10n;
    final format = appFormatOf(context);
    final theme = Theme.of(context);
    final t = PersonalTheme.of(context);
    final colours = {
      OwedBucket.notYetDue: t.interactiveBorder,
      OwedBucket.toConfirm: statusColorsOf(
        t,
        StatusTone.info,
        scheme: theme.colorScheme,
      ).$2,
      OwedBucket.overdue: statusColorsOf(
        t,
        StatusTone.due,
        scheme: theme.colorScheme,
      ).$2,
    };
    final labels = {
      OwedBucket.notYetDue: l.invoicingOwedNotYetDue,
      OwedBucket.toConfirm: l.journeyStageConfirm,
      OwedBucket.overdue: l.invoicingOwedOverdue,
    };
    final owed = owedOf(mine, today);
    return KitCard(
      key: const ValueKey('customer-page-owed'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.sm,
        children: [
          KitLabel(l.customerPageOwes),
          if (owed.isEmpty)
            Text(
              l.customerPageNothingOwed,
              key: const ValueKey('customer-page-nothing-owed'),
              style: theme.textTheme.titleMedium,
            ),
          for (final o in owed) ...[
            Text(
              format.moneyIn(o.currency).formatMinor(o.totalMinor),
              key: ValueKey('customer-page-owed-${o.currency}'),
              style: theme.textTheme.headlineMedium?.emphasised.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            SplitBar(
              parts: [
                for (final b in OwedBucket.values)
                  (weight: o.buckets[b]?.minor ?? 0, color: colours[b]!),
              ],
            ),
            for (final b in OwedBucket.values)
              if (o.buckets[b] case final share?)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${labels[b]} · ${l.invoicingInvoiceCount(share.count)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Text(format.moneyIn(o.currency).formatMinor(share.minor)),
                  ],
                ),
          ],
        ],
      ),
    );
  }

  /// "Credit: …" per currency, with what it is.
  List<Widget> _credit(
    BuildContext context,
    Map<String, int> held, {
    required bool holds,
  }) {
    final l = context.l10n;
    final format = appFormatOf(context);
    final theme = Theme.of(context);
    return [
      const SizedBox(height: AppSpacing.md),
      KitCard(
        key: const ValueKey('customer-page-credit'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in held.entries)
              if (e.value > 0)
                Text(
                  l.customerPageCredit(
                    format.moneyIn(e.key).formatMinor(e.value),
                  ),
                  style: theme.textTheme.titleSmall,
                ),
            Text(
              l.customerPageCreditHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (holds)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: const ValueKey('customer-page-credit-match'),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => onAction(InvoiceAction.match),
                  child: Text(l.customerPageMatch),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  /// One invoice, in the words the home's lines say.
  Widget _line(BuildContext context, Receivable r) {
    final l = context.l10n;
    final format = appFormatOf(context);
    final status = invoiceStatusOf(r, today);
    return TwoLineRow(
      key: ValueKey('customer-page-invoice-${r.invoiceId}'),
      title: r.number,
      caption: Text(
        r.dueOn == null
            ? ''
            : l.invoicingDueOn(invoicingDay(format, r.dueOn!, today)),
      ),
      amount: format
          .moneyIn(r.currency)
          .formatMinor(
            r.stage == ReceivableStage.paid ? r.totalMinor : r.openMinor,
          ),
      trailing: StatusChip(
        label: statusWordsOf(l, format, r, status, today),
        tone: statusToneOf(status.kind),
      ),
      onTap: () => onOpenInvoice(r.invoiceId),
    );
  }

  /// Dated lines of what happened, the latest first, and where it stands now.
  Widget _story(
    BuildContext context,
    List<Receivable> mine,
    CustomerLine? row,
  ) {
    final l = context.l10n;
    final format = appFormatOf(context);
    String day(DateTime d) => invoicingDay(format, d, today);
    final events = <(DateTime, StoryLine)>[
      for (final r in mine) ...[
        (
          r.issuedOn,
          (text: l.customerStoryIssued(r.number), when: day(r.issuedOn)),
        ),
        if (r.remindersSent > 0)
          (
            r.dueOn ?? r.issuedOn,
            (
              text: l.customerStoryReminders(r.remindersSent, r.number),
              when: '',
            ),
          ),
        if (r.paymentDeclared && r.declaredOn != null)
          (
            r.declaredOn!,
            (text: l.customerStoryDeclared(r.number), when: day(r.declaredOn!)),
          ),
        if (r.paidOn != null)
          (
            r.paidOn!,
            (text: l.customerStoryPaid(r.number), when: day(r.paidOn!)),
          ),
      ],
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final String standing;
    if (row == null) {
      standing = l.customerPageNothingOwed;
    } else if (row.daysLate case final days?) {
      standing = l.invoicingDaysLate(days);
    } else {
      standing = statusWordsOf(
        l,
        format,
        row.invoices.first,
        invoiceStatusOf(row.invoices.first, today),
        today,
      );
    }
    return KitCard(
      key: const ValueKey('customer-page-story'),
      child: Story(
        lines: [for (final e in events) e.$2],
        now: (text: l.customerStoryNow(standing), when: ''),
      ),
    );
  }
}
