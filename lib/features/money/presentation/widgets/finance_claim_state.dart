// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3556 (1b) — where an invoice's payment stands on My finances: in a
// payment I may withdraw (online), in a declared one that waits for the
// business, or received and being matched by the business. Withdrawing is
// confirmed first, with what becomes of money that still arrives.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../domain/finance_overview.dart';
import '../../domain/payment_claims.dart';
import '../../providers/finance_overview_provider.dart';
import '../../providers/finance_selection_provider.dart';
import '../claim_refusal_text.dart';

class FinanceClaimState extends ConsumerWidget {
  const FinanceClaimState(this.invoice, {super.key});

  final FinanceInvoice invoice;

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('finances-withdraw-confirm'),
        title: Text(l10n.financesWithdrawTitle),
        // two sentences, two paragraphs: a payment just handed may still
        // be confirmed at the provider
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              if (invoice.claimSettling) Text(l10n.financesWithdrawSettling),
              Text(l10n.financesWithdrawBody),
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
            child: Text(l10n.financesWithdraw),
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
      message: 'withdraw payment claim failed',
      errorText: l10n.financesWithdrawFailed,
      action: () async {
        // the invoices this payment named, as read before the withdrawal
        final named = [
          for (final i
              in ref.read(financeOverviewProvider).value?.invoices ??
                  const <FinanceInvoice>[]) // empty-ok: an overview not read names no other invoice; this one is added below
            if (i.claimPaymentId == invoice.claimPaymentId) i.id,
          invoice.id,
        ];
        try {
          done = await ref
              .read(financeSelectionCommandsProvider)
              .withdraw(invoice);
          // a payment of them again is a new one: its request id goes
          if (done == true) {
            ref.read(paymentRequestIdsProvider).forgetClaim(named.toSet());
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
    if (!context.mounted) return;
    if (refused case final r?) {
      AppSnack.error(context, claimRefusalText(l10n, r));
    } else if (done == false) {
      AppSnack.error(
        context,
        l10n.financesBusinessUnavailable(invoice.workspaceName),
      );
    } else if (done == true) {
      AppSnack.success(context, l10n.financesWithdrawn);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (invoice.paymentReceived) {
      return _Chip(l10n.financesPaymentReceived(invoice.workspaceName));
    }
    if (!invoice.inPayment) return const SizedBox.shrink();
    if (invoice.claimPaymentId == null) {
      return _Chip(l10n.financesWaitsForBusiness(invoice.workspaceName));
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
        TextButton(
          key: ValueKey('finances-withdraw-${invoice.id}'),
          onPressed: () => _withdraw(context, ref),
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
