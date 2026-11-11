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
import '../../application/credit_move_commands.dart';
import '../../application/payment_candidates.dart';
import '../../application/receivables.dart';
import '../../domain/ledger_entry.dart';
import '../../providers/credit_move_providers.dart';
import '../../providers/money_providers.dart';
import '../invoice_followup_actions.dart' show matchInvoiceToPayment;

/// One payment waiting for an invoice, with what it could settle.
typedef PaymentToMatch = ({
  Receivable customer,
  LedgerEntry payment,
  List<MatchCandidate> candidates,
});

class PaymentsToMatchScreen extends ConsumerStatefulWidget {
  const PaymentsToMatchScreen({
    super.key,
    required this.receivables,
    required this.currency,
    required this.workspaceId,
    this.loader,
  });

  /// Every invoice the home reads: the customers with a payment to match and
  /// the open invoices a payment could settle.
  final List<Receivable> receivables;

  /// The business's currency: a payment settles an invoice of this currency.
  final String currency;
  final String workspaceId;

  /// Reads the payments; a test hands in plain ones.
  final Future<List<PaymentToMatch>> Function()? loader;

  @override
  ConsumerState<PaymentsToMatchScreen> createState() =>
      _PaymentsToMatchScreenState();
}

class _PaymentsToMatchScreenState extends ConsumerState<PaymentsToMatchScreen> {
  late Future<List<PaymentToMatch>> _rows = _read();

  Future<List<PaymentToMatch>> _read() async {
    final custom = widget.loader;
    if (custom != null) return custom();
    final customers = {
      for (final r in widget.receivables)
        if (r.paymentToMatch) r.customerId: r,
    };
    if (customers.isEmpty) return const [];
    final queries = ref.read(invoiceQueriesProvider);
    final matches = ref.read(invoiceMatchesProvider).value ?? const {};
    // The junction knows EVERY consumed payment (#506); a credit moved to
    // another member is no longer this member's money (#3349).
    final consumed = {
      for (final m in matches.values) ?m.paymentLedgerId,
      ...await queries.fetchConsumedPaymentIds(widget.workspaceId),
      ...await ref
          .read(creditMoveCommandsProvider)
          .movedCreditIds(widget.workspaceId),
    };
    final invoices = await ref.read(invoicesProvider.future);
    final rows = <PaymentToMatch>[];
    for (final customer in customers.values) {
      final ledger = await ref
          .read(memberAccountQueriesProvider)
          .fetchLedger(customer.customerId);
      final theirs = widget.receivables
          .where((r) => r.customerId == customer.customerId)
          .toList();
      for (final payment in unmatchedPaymentsOf(
        memberId: customer.customerId,
        ledger: ledger,
        consumed: consumed,
        invoices: invoices,
      )) {
        final candidates = candidatesFor(
          paymentMinor: payment.amountCents,
          currency: widget.currency,
          customerInvoices: theirs,
        );
        // Money with no open invoice to pay is the customer's credit (shown
        // on their page), not something to do here.
        if (candidates.isEmpty) continue;
        rows.add((
          customer: customer,
          payment: payment,
          candidates: candidates,
        ));
      }
    }
    return rows;
  }

  void _reload() => setState(() {
    _rows = _read();
  });

  Future<void> _match(PaymentToMatch row, MatchCandidate c) async {
    final l10n = context.l10n;
    if (c.fit == MatchFit.needsDecision) {
      // The dialog that asks how to settle a difference, as ever.
      final invoice = (await ref.read(invoicesProvider.future))
          .where((i) => i.id == c.invoice.invoiceId)
          .firstOrNull;
      if (invoice == null || !mounted) return;
      await matchInvoiceToPayment(context, ref, invoice);
      if (mounted) _reload();
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
    ref
      ..invalidate(invoiceMatchesProvider)
      ..invalidate(invoicesProvider);
    if (!mounted) return;
    AppSnack.success(context, l10n.invoiceMatched);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.paymentMatchTitle)),
      body: FutureBuilder<List<PaymentToMatch>>(
        future: _rows,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
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
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: _reload,
                    child: Text(l10n.commonRetry),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return const LoadingView();
          }
          return _list(context, [
            for (final r in snapshot.data!)
              if (r.candidates.isNotEmpty) r,
          ]);
        },
      ),
    );
  }

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
          _PaymentCard(row: row, onMatch: (c) => _match(row, c)),
        ],
      ],
    );
  }
}

class _PaymentCard extends ConsumerWidget {
  const _PaymentCard({required this.row, required this.onMatch});

  final PaymentToMatch row;
  final void Function(MatchCandidate candidate) onMatch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final format = ref.watch(appFormatProvider);
    final money = format.moneyIn(row.customer.currency);
    final payment = row.payment;
    return KitCard(
      key: ValueKey('payment-match-${payment.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(row.customer.customerName, style: theme.textTheme.titleSmall),
          Text(
            l10n.paymentMatchHeader(
              money.formatMinor(payment.amountCents),
              format.date(payment.on),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
                onPressed: () => onMatch(c),
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
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const size = Size.fromHeight(48);
    return exact
        ? FilledButton.tonal(
            style: FilledButton.styleFrom(minimumSize: size),
            onPressed: onPressed,
            child: child,
          )
        : OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: size),
            onPressed: onPressed,
            child: child,
          );
  }
}
