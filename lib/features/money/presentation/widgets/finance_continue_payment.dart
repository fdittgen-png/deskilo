// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/session/session_source.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../application/finance_selection_commands.dart';
import '../../domain/finance_overview.dart';
import '../../domain/payment_claims.dart';
import '../../providers/finance_overview_provider.dart';
import '../../providers/finance_selection_provider.dart';
import '../../providers/payment_approval_providers.dart';
import '../claim_refusal_text.dart';
import '../finance_host_unavailable.dart';

/// Reopens the displayed payment on its captured host, without a new request.
class FinanceContinuePayment extends ConsumerStatefulWidget {
  const FinanceContinuePayment(this.invoice, {super.key});
  final FinanceInvoice invoice;

  @override
  ConsumerState<FinanceContinuePayment> createState() =>
      _ContinuePaymentState();
}

class _ContinuePaymentState extends ConsumerState<FinanceContinuePayment> {
  bool _busy = false;

  Future<void> _continue() async {
    if (_busy) return;
    final invoice = widget.invoice;
    final entry = ref.read(financeWorkspaceEntryProvider);
    final principal = ref.read(sessionSourceProvider).currentUserId;
    final l10n = context.l10n;
    bool current() =>
        mounted &&
        principal != null &&
        ref.read(sessionSourceProvider).currentUserId == principal;
    FinanceCommandTarget? captured;
    setState(() => _busy = true);
    try {
      await runGuarded(
        context,
        domain: 'payments',
        message: 'continue payment failed',
        errorText: l10n.financesContinueFailed,
        action: () async {
          captured = await entry(invoice.target!);
          if (!mounted || !current()) return;
          final target = captured;
          if (target == null || !target.isCurrent()) {
            showFinanceHostUnavailable(
              context,
              invoice.workspaceName,
              retry: () {
                if (mounted) unawaited(_continue());
              },
            );
            return;
          }
          try {
            await _open(target, invoice, current);
          } on ClaimRefused catch (refused, st) {
            TraceLogger.instance.warn(
              'payments',
              'continue payment refused: ${refused.reason.code}',
              error: refused,
              stackTrace: st,
            );
            if (mounted && current() && target.isCurrent()) {
              AppSnack.error(context, claimRefusalText(l10n, refused.reason));
            }
          }
        },
      );
      if (current()) await refreshMyFinances(ref);
    } finally {
      captured?.release();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(
    FinanceCommandTarget target,
    FinanceInvoice invoice,
    bool Function() current,
  ) async {
    final l10n = context.l10n;
    final config = await target.gateway.fetchPaymentConfig(
      target.target.workspaceId,
    );
    if (!mounted || !current() || !target.isCurrent()) return;
    if (!config.continuations) {
      AppSnack.error(context, l10n.payOnlineClaimsUnsupported);
      return;
    }
    final order = await target.gateway.resumeClaimOrder(
      workspaceId: target.target.workspaceId,
      memberId: target.memberId,
      paymentId: invoice.claimPaymentId!,
    );
    if (!mounted || !current() || !target.isCurrent() || order.alreadyPaid) {
      return;
    }
    if (!order.started) {
      AppSnack.error(context, l10n.payOnlineClaimsUnsupported);
      return;
    }
    if (order.claimed == null || order.claimed! <= 0) {
      AppSnack.error(context, l10n.payOnlineClaimNotTaken);
      return;
    }
    await ref.read(paymentApprovalProvider)(context, order.approveUrl!);
  }

  @override
  Widget build(BuildContext context) => TextButton(
    key: ValueKey('finances-continue-${widget.invoice.id}'),
    onPressed:
        _busy ||
            widget.invoice.target == null ||
            widget.invoice.claimPaymentId == null
        ? null
        : _continue,
    child: Text(context.l10n.financesContinuePayment),
  );
}
