// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — e-mailing one order from its card: the send button on a draft
// that names its recipient while the space's mail is configured, and, for
// an attempt nobody could confirm, the question a person answers (did it
// arrive?). A new attempt id is drawn per press; the server never sends an
// order twice blindly, whatever the app does.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../application/purchase_order_commands.dart';
import '../../domain/purchase_order.dart';
import '../../providers/purchase_order_providers.dart';
import '../mail_refusal_text.dart';
import '../purchase_order_print.dart';

class PurchaseOrderSendActions extends ConsumerWidget {
  const PurchaseOrderSendActions({
    super.key,
    required this.order,
    required this.workspaceId,
    required this.canWrite,
    required this.letterhead,
  });

  final PurchaseOrder order;
  final String workspaceId;
  final bool canWrite;
  final ({String name, String address}) letterhead;

  Future<void> _send(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final mail = await PurchaseOrderPrint(
      context,
      ref,
    ).mail(workspaceId: workspaceId, order: order, letterhead: letterhead);
    if (mail == null || !context.mounted) return;
    PurchaseOrderSend? sent;
    var undecided = false;
    await runGuarded(
      context,
      domain: 'money',
      message: 'purchase order e-mail failed',
      errorText: l10n.purchaseOrderRefused,
      action: () async {
        try {
          sent = await ref
              .read(purchaseOrderCommandsProvider)
              .sendByEmail(workspaceId, order, newRequestId(), mail);
        } on PurchaseOrderSendUndecided catch (e, st) {
          // #3774 — nothing was sent: the earlier e-mail is decided first.
          TraceLogger.instance.error(
            'money',
            'purchase order e-mail waits for a decision',
            error: e,
            stackTrace: st,
          );
          undecided = true;
        }
      },
    );
    if (!context.mounted) return;
    if (undecided) {
      ref.invalidate(purchaseOrderSendsProvider(workspaceId));
      AppSnack.error(context, l10n.purchaseOrderSendDecideFirst);
      return;
    }
    switch (sent) {
      case PurchaseOrderSend(state: PurchaseOrderSendState.accepted):
        AppSnack.info(context, l10n.purchaseOrderSentTo(sent!.recipient));
      case PurchaseOrderSend(state: PurchaseOrderSendState.refused):
        AppSnack.error(
          context,
          l10n.purchaseOrderSendRefused(mailRefusalText(l10n, sent!.reason)),
        );
      case PurchaseOrderSend():
        AppSnack.error(context, l10n.purchaseOrderSendUnconfirmed);
      case null:
        break;
    }
  }

  Future<void> _resolve(
    BuildContext context,
    WidgetRef ref,
    PurchaseOrderSend send, {
    required bool delivered,
  }) => runGuarded(
    context,
    domain: 'money',
    message: 'purchase order send decision failed',
    errorText: context.l10n.purchaseOrderRefused,
    action: () => ref
        .read(purchaseOrderCommandsProvider)
        .resolveSend(workspaceId, send.id, delivered: delivered),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!canWrite || order.state != PurchaseOrderState.draft) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final mail = ref
        .watch(purchaseOrderMailSettingsProvider(workspaceId))
        .value;
    final waiting = [
      for (final s
          in ref.watch(purchaseOrderSendsProvider(workspaceId)).value ??
              const <PurchaseOrderSend>[])
        // #3774 — a pending one listed here has no outcome recorded either.
        if (s.orderId == order.id &&
            (s.awaitsDecision || s.state == PurchaseOrderSendState.pending))
          s,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in waiting) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.purchaseOrderSendAwaits(s.recipient),
            key: ValueKey('purchase-order-awaits-${order.reference}'),
          ),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              OutlinedButton(
                key: ValueKey('purchase-order-arrived-${order.reference}'),
                onPressed: () => _resolve(context, ref, s, delivered: true),
                child: Text(l10n.purchaseOrderSendArrived),
              ),
              OutlinedButton(
                key: ValueKey('purchase-order-lost-${order.reference}'),
                onPressed: () => _resolve(context, ref, s, delivered: false),
                child: Text(l10n.purchaseOrderSendLost),
              ),
            ],
          ),
        ],
        if (waiting.isEmpty && order.emailable && (mail?.hasApiKey ?? false))
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: FilledButton.icon(
              key: ValueKey('purchase-order-email-${order.reference}'),
              onPressed: () => _send(context, ref),
              icon: const Icon(Icons.send_outlined),
              label: Text(l10n.purchaseOrderSendEmail),
            ),
          ),
      ],
    );
  }
}
