// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3556 (1b) — where an invoice's payment stands on My finances: in a
// payment I may withdraw (online), in a declared one that waits for the
// business (#4140: which I may take back while it is not decided), or
// received and being matched by the business. Withdrawing or taking back is
// confirmed first, with what becomes of money that still arrives, or which
// invoices a declaration named.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/finance_overview.dart';
import '../../domain/payment_claims.dart';
import '../../providers/finance_overview_provider.dart';
import '../../providers/finance_selection_provider.dart';
import '../claim_refusal_text.dart';
import '../finance_host_unavailable.dart';
import 'finance_continue_payment.dart';

class FinanceClaimState extends ConsumerWidget {
  const FinanceClaimState(this.invoice, {super.key});

  final FinanceInvoice invoice;

  /// The invoices the payment holding [invoice] names, as read before it is
  /// withdrawn or taken back.
  List<FinanceInvoice> _named(WidgetRef ref) {
    final declared = invoice.claimPaymentId == null;
    return [
      for (final i
          in ref.read(financeOverviewProvider).value?.invoices ??
              const <FinanceInvoice>[]) // empty-ok: an overview not read names no other invoice; this one is added below
        if (i.networkId == invoice.networkId && i.id != invoice.id &&
            (declared
                ? i.claimEventId == invoice.claimEventId
                : i.claimPaymentId == invoice.claimPaymentId))
          i,
      invoice,
    ];
  }

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final commands = ref.read(financeSelectionCommandsProvider);
    final requests = ref.read(paymentRequestIdsProvider);
    final declared = invoice.claimPaymentId == null;
    final named = _named(ref);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('finances-withdraw-confirm'),
        title: Text(
          declared ? l10n.financesTakeBackTitle : l10n.financesWithdrawTitle,
        ),
        // two sentences, two paragraphs: a payment just handed may still
        // be confirmed at the provider
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              if (declared)
                Text(
                  l10n.financesTakeBackBody(
                    named.map((i) => i.number).join(', '),
                  ),
                )
              else ...[
                if (invoice.claimSettling) Text(l10n.financesWithdrawSettling),
                Text(l10n.financesWithdrawBody),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('finances-withdraw-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('finances-withdraw-yes'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              declared ? l10n.financesTakeBack : l10n.financesWithdraw,
            ),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    ClaimRefusal? refused;
    bool? done;
    await runGuarded(
      context,
      domain: 'money',
      message: declared
          ? 'take back payment declaration failed'
          : 'withdraw payment claim failed',
      errorText: declared
          ? l10n.financesTakeBackFailed
          : l10n.financesWithdrawFailed,
      action: () async {
        try {
          done = await commands.withdraw(invoice);
          // a payment of them again is a new one: its request id goes
          // (keyed by the one identity of the host: installation and workspace)
          final key = invoice.target?.financeKey;
          if (done == true && key != null) {
            requests.forgetClaim({for (final i in named) i.id}, networkId: key);
          }
        } on ClaimRefused catch (r, st) {
          // the refusal is said in its own words below
          TraceLogger.instance.warn(
            'money',
            'payment claim refused: ${r.reason.code}',
            error: r,
            stackTrace: st,
          );
          refused = r.reason;
        }
      },
    );
    await refreshMyFinances(ref);
    if (context.mounted) _say(context, ref, refused: refused, done: done);
  }

  /// What a withdrawal or a take-back came to: refused in the server's words,
  /// a business that could not be reached or verified (with a way to try
  /// again), or done.
  void _say(
    BuildContext context,
    WidgetRef ref, {
    required ClaimRefusal? refused,
    required bool? done,
  }) {
    final l10n = context.l10n;
    if (refused != null) {
      AppSnack.error(context, claimRefusalText(l10n, refused));
    } else if (done == false &&
        (invoice.target == null ||
            (invoice.claimPaymentId == null && invoice.claimEventId == null))) {
      // nothing to withdraw or take back here (no host, no payment): not a
      // host that cannot be reached, and nothing to try again
      AppSnack.error(
        context,
        invoice.claimPaymentId == null
            ? l10n.financesTakeBackFailed
            : l10n.financesWithdrawFailed,
      );
    } else if (done == false) {
      showFinanceHostUnavailable(
        context,
        invoice.workspaceName,
        retry: () {
          if (context.mounted) unawaited(_withdraw(context, ref));
        },
      );
    } else if (done == true) {
      AppSnack.success(
        context,
        invoice.claimPaymentId == null
            ? l10n.financesTakenBack
            : l10n.financesWithdrawn,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (invoice.paymentReceived) {
      return _Chip(l10n.financesPaymentReceived(invoice.workspaceName));
    }
    final ended = claimEndedText(l10n, invoice.claimState);
    if (!invoice.inPayment) return ended == null ? const SizedBox.shrink() : _Chip(ended);
    if (invoice.claimPaymentId == null) {
      final waits = _Chip(l10n.financesWaitsForBusiness(invoice.workspaceName));
      if (invoice.claimEventId == null) return waits;
      return Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          waits,
          TextButton(
            key: ValueKey('finances-take-back-${invoice.id}'),
            onPressed: invoice.target == null ? null : () => _withdraw(context, ref),
            child: Text(l10n.financesTakeBack),
          ),
        ],
      );
    }
    final since = invoice.claimHandedAt;
    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Chip(
          since == null
              ? l10n.financesInPayment
              : l10n.financesInPaymentSince(
                  personalFormatOf(context)
                      .dates(DateShape.date)
                      .format(personalFormatOf(context).wall(since)),
                ),
        ),
        if (ended != null) _Chip(ended),
        if (invoice.claimCanContinue == true) FinanceContinuePayment(invoice),
        if (invoice.claimCanContinue == null || invoice.claimState == PaymentClaimState.unavailable)
          Text(l10n.payOnlineClaimsUnsupported, style: Theme.of(context).textTheme.bodySmall),
        TextButton(
          key: ValueKey('finances-withdraw-${invoice.id}'),
          onPressed: invoice.target == null ? null : () => _withdraw(context, ref),
          child: Text(l10n.financesWithdraw),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      Chip(label: Text(label), visualDensity: VisualDensity.compact);
}

/// #4418 -- the word for how the payment of an open claim ended; none for
/// a payment still running, and none for a state this app does not know.
@visibleForTesting
String? claimEndedText(AppLocalizations l10n, PaymentClaimState? state) =>
    switch (state) {
      PaymentClaimState.failed => l10n.financesPaymentFailed,
      PaymentClaimState.expired => l10n.financesPaymentExpired,
      PaymentClaimState.changed => l10n.financesPaymentChanged,
      PaymentClaimState.awaitingProvider => l10n.financesPaymentAwaitingProvider,
      PaymentClaimState.withdrawn => l10n.financesPaymentWithdrawn,
      PaymentClaimState.reversed => l10n.financesPaymentReversed,
      PaymentClaimState.ready ||
      PaymentClaimState.unavailable ||
      PaymentClaimState.unknown ||
      null => null,
    };
