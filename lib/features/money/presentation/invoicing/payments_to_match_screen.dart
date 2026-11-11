// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-f -- "Payments to match": a list of PAYMENTS (each one a received
// payment no invoice has taken), and under each the invoices of the same
// customer it could settle, the one of the same amount first. One tap matches
// when the amount is the open amount; any other amount opens the match dialog
// that has always asked how to settle the difference. "None of these" leaves
// the payment as it is. Matching uses the existing `matchInvoice` call; the
// server stays the authority (a validation quorum may keep it waiting).
import 'dart:async';

import 'package:deskilo_invoice_model/deskilo_invoice_model.dart' show Invoice;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/kit/kit_card.dart';
import '../../../../core/ui/kit/status_chip.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/credit_move_commands.dart';
import '../../application/payment_candidates.dart';
import '../../application/unassigned_money.dart';
import '../../providers/money_providers.dart';
import '../invoice_followup_actions.dart' show matchInvoiceToPayment;
import 'assign_payment_sheet.dart';
import 'invoicing_reads.dart';

class PaymentsToMatchScreen extends ConsumerStatefulWidget {
  const PaymentsToMatchScreen({
    super.key,
    required this.currency,
    this.customerId,
  });

  /// The business's currency: the ledger's, so the payment's, and the only
  /// one of the invoices a payment is offered to settle.
  final String currency;

  /// Only this customer's payments; null: every customer's.
  final String? customerId;

  @override
  ConsumerState<PaymentsToMatchScreen> createState() =>
      _PaymentsToMatchScreenState();
}

class _PaymentsToMatchScreenState extends ConsumerState<PaymentsToMatchScreen> {
  /// A match is running: every candidate waits, so a double tap or a second
  /// card never matches twice.
  final ValueNotifier<bool> _working = ValueNotifier(false);

  @override
  void dispose() {
    _working.dispose();
    super.dispose();
  }

  Future<void> _match(PaymentToMatch row, MatchCandidate c) async {
    if (_working.value) return;
    _working.value = true;
    try {
      await _matchOnce(row, c);
    } finally {
      if (mounted) _working.value = false;
    }
  }

  Future<void> _matchOnce(PaymentToMatch row, MatchCandidate c) async {
    final l10n = context.l10n;
    if (c.fit == MatchFit.needsDecision) {
      // The dialog that asks how to settle a difference, opened on the
      // payment of the card that was tapped. #3285: the invoices are read
      // under the same guard as the match; a failed read is said with Try
      // again, which keeps this payment and this invoice.
      final Invoice? invoice;
      try {
        invoice = (await ref.read(invoicesProvider.future))
            .where((i) => i.id == c.invoice.invoiceId)
            .firstOrNull;
      } on Object catch (e, st) {
        TraceLogger.instance.error(
          'money',
          'invoices read failed before a match',
          error: e,
          stackTrace: st,
        );
        if (!mounted) return;
        AppSnack.error(
          context,
          l10n.assignPaymentReadFailedInvoices,
          action: SnackBarAction(
            key: const ValueKey('payment-match-read-retry'),
            label: l10n.commonRetry,
            onPressed: () {
              ref.invalidate(invoicesProvider);
              unawaited(_match(row, c));
            },
          ),
        );
        return;
      }
      if (!mounted) return;
      if (invoice == null) {
        ref
          ..invalidate(invoiceMatchesProvider)
          ..invalidate(invoicesProvider);
        AppSnack.error(context, l10n.paymentMatchInvoiceGone);
        return;
      }
      await matchInvoiceToPayment(
        context,
        ref,
        invoice,
        paymentId: row.payment.id,
      );
      return;
    }
    try {
      await ref
          .read(invoiceCommandsProvider)
          .matchInvoice(
            invoiceId: c.invoice.invoiceId,
            paymentLedgerId: row.payment.id,
            resolution: 'exact',
          );
    } on Object catch (e, st) {
      TraceLogger.instance.error(
        'money',
        'payment match refused',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      AppSnack.error(
        context,
        CreditMoveCommands.refusedAsMoved(e)
            ? l10n.invoiceMatchCreditMoved
            : l10n.paymentMatchRefused,
      );
      return;
    }
    // The invoices and the money are read again: the next payment is offered
    // only what is still open.
    ref
      ..invalidate(invoiceMatchesProvider)
      ..invalidate(invoicesProvider);
    if (!mounted) return;
    AppSnack.success(context, l10n.invoiceMatched);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // The current invoices and the one answer of who holds what: after a
    // match both are read again, never a list frozen before it.
    final money = ref.watch(unassignedMoneyProvider);
    final known = unassignedMoneyKnown(money);
    final receivables = ref.watch(invoicingReceivablesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.paymentMatchTitle)),
      body: money.hasError && !money.isLoading
          ? _failed(l10n)
          : known == null || receivables == null
          ? const LoadingView()
          : _list(
              context,
              known.toMatch(receivables, customerId: widget.customerId),
            ),
    );
  }

  Widget _failed(AppLocalizations l10n) => Padding(
    padding: AppSpacing.mdAll,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.paymentMatchFailed,
          key: const ValueKey('payment-match-failed'),
        ),
        TextButton(
          key: const ValueKey('payment-match-retry'),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => ref.invalidate(unassignedMoneyProvider),
          child: Text(l10n.commonRetry),
        ),
      ],
    ),
  );

  Widget _list(BuildContext context, List<PaymentToMatch> rows) {
    final l10n = context.l10n;
    if (rows.isEmpty) {
      return Padding(
        padding: AppSpacing.mdAll,
        child: QuietLine(
          l10n.paymentMatchEmpty,
          key: const ValueKey('payment-match-empty'),
        ),
      );
    }
    return ListView(
      padding: AppSpacing.mdAll,
      children: [
        QuietLine(l10n.paymentMatchIntro, icon: Icons.info_outline),
        for (final row in rows) ...[
          const SizedBox(height: AppSpacing.md),
          ValueListenableBuilder(
            valueListenable: _working,
            builder: (context, working, _) => _PaymentCard(
              row: row,
              currency: widget.currency,
              onMatch: working ? null : (c) => _match(row, c),
              onAssign: working
                  ? null
                  : () => showAssignPayment(
                      context,
                      paymentId: row.payment.id,
                      customerId: row.customerId,
                      customerName: row.customerName,
                      currency: widget.currency,
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PaymentCard extends ConsumerWidget {
  const _PaymentCard({
    required this.row,
    required this.currency,
    required this.onMatch,
    required this.onAssign,
  });

  final PaymentToMatch row;

  /// The business's currency, the payment's and its candidates'.
  final String currency;

  /// Null while a match runs: every candidate waits.
  final void Function(MatchCandidate candidate)? onMatch;

  /// Opens "Assign to invoices" for this payment (#3671); null while a match
  /// runs.
  final VoidCallback? onAssign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final format = ref.watch(appFormatProvider);
    final money = format.moneyIn(currency);
    final payment = row.payment;
    return KitCard(
      key: ValueKey('payment-match-${payment.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(row.customerName, style: theme.textTheme.titleSmall),
          Text(
            l10n.paymentMatchHeader(
              money.formatMinor(payment.leftCents),
              format.date(payment.entry.on),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (payment.isPartlyUsed)
            Text(
              l10n.assignPaymentUsedHead(
                money.formatMinor(payment.receivedCents),
                money.formatMinor(payment.assignedCents),
                money.formatMinor(payment.leftCents),
              ),
              key: ValueKey('payment-match-used-${payment.id}'),
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: AppSpacing.sm),
          for (final c in row.candidates)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _CandidateButton(
                exact: c.fit == MatchFit.exact,
                key: ValueKey(
                  'payment-match-${payment.id}-${c.invoice.invoiceId}',
                ),
                onPressed: switch (onMatch) {
                  final match? => () => match(c),
                  null => null,
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.paymentMatchCandidate(
                          c.invoice.number,
                          money.formatMinor(c.invoice.openMinor),
                        ),
                      ),
                    ),
                    if (c.fit == MatchFit.exact)
                      StatusChip(
                        label: l10n.paymentMatchSame,
                        tone: StatusTone.ok,
                      ),
                  ],
                ),
              ),
            ),
          if (row.candidates.any((c) => c.fit == MatchFit.needsDecision))
            Text(
              l10n.paymentMatchDecide,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: ValueKey('payment-match-assign-${payment.id}'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: onAssign,
              child: Text(l10n.assignPaymentAction),
            ),
          ),
        ],
      ),
    );
  }
}

/// The invoice a payment could settle: the one of the same amount stands out
/// (tonal), the others are outlined.
class _CandidateButton extends StatelessWidget {
  const _CandidateButton({
    super.key,
    required this.exact,
    required this.onPressed,
    required this.child,
  });

  final bool exact;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const size = Size.fromHeight(48);
    return exact
        ? FilledButton.tonal(
            style: FilledButton.styleFrom(minimumSize: size),
            // recorder-key-exempt: keyed by its caller (the widget's own key).
            onPressed: onPressed,
            child: child,
          )
        : OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: size),
            // recorder-key-exempt: keyed by its caller (the widget's own key).
            onPressed: onPressed,
            child: child,
          );
  }
}
