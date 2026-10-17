// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/purchase.dart';
import '../../providers/purchase_providers.dart';

/// What can be done to a supplier bill from its detail: send a captured
/// draft for approval, or -- for another person holding approveExpenses --
/// approve or reject it. The server decides again on every write.
class PurchaseDecisionBar extends ConsumerWidget {
  const PurchaseDecisionBar({
    required this.workspaceId,
    required this.detail,
    required this.canCapture,
    required this.canDecide,
    super.key,
  });

  final String workspaceId;
  final PurchaseDetail detail;
  final bool canCapture;
  final bool canDecide;

  void _refresh(WidgetRef ref) {
    ref
      ..invalidate(purchaseDetailProvider)
      ..invalidate(purchasesProvider(workspaceId))
      ..invalidate(payablesProvider(workspaceId));
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'bill submit failed',
      errorText: context.l10n.purchasesSubmitRefused,
      action: () async {
        await ref
            .read(purchaseCommandProvider)
            .submit(workspaceId, detail, newRequestId());
      },
    );
    _refresh(ref);
    if (ok && context.mounted) {
      AppSnack.success(context, context.l10n.purchasesSubmitted);
    }
  }

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref, {
    required bool approve,
  }) async {
    final reason = approve ? '' : await _askReason(context);
    if (!approve && (reason == null || reason.trim().isEmpty)) return;
    if (!context.mounted) return;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'bill decision failed',
      errorText: context.l10n.purchasesDecisionRefused,
      action: () async {
        await ref
            .read(purchaseCommandProvider)
            .decide(
              workspaceId,
              detail,
              approve: approve,
              reason: reason ?? '',
              requestId: newRequestId(),
            );
      },
    );
    _refresh(ref);
    if (ok && context.mounted) {
      final l10n = context.l10n;
      AppSnack.success(
        context,
        approve ? l10n.purchasesApprovedDone : l10n.purchasesRejectedDone,
      );
    }
  }

  Future<String?> _askReason(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(dialog.l10n.purchasesRejectTitle),
        content: AppTextField(
          key: const ValueKey('purchase-reject-reason'),
          controller: controller,
          label: dialog.l10n.purchasesRejectReason,
          maxLength: 300,
        ),
        actions: [
          TextButton(
            key: const ValueKey('purchase-reject-cancel'),
            onPressed: () => Navigator.of(dialog).pop(),
            child: Text(MaterialLocalizations.of(dialog).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('purchase-reject-confirm'),
            onPressed: () => Navigator.of(dialog).pop(controller.text),
            child: Text(dialog.l10n.purchasesRejectAction),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = detail.summary;
    if (s.kind != PurchaseKind.bill) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        children: [
          if (canCapture && s.state == PurchaseState.draft)
            FilledButton(
              key: const ValueKey('purchase-submit'),
              onPressed: () => _submit(context, ref),
              child: Text(l10n.purchasesSubmitAction),
            ),
          if (canDecide && s.state == PurchaseState.pending) ...[
            FilledButton(
              key: const ValueKey('purchase-approve'),
              onPressed: () => _decide(context, ref, approve: true),
              child: Text(l10n.purchasesApproveAction),
            ),
            OutlinedButton(
              key: const ValueKey('purchase-reject'),
              onPressed: () => _decide(context, ref, approve: false),
              child: Text(l10n.purchasesRejectAction),
            ),
          ],
        ],
      ),
    );
  }
}
