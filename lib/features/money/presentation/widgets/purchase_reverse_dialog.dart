// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/purchase.dart';
import '../../providers/purchase_providers.dart';

/// Reverses one recorded payment of [claim]. True once the server has it.
Future<bool?> showReverseDialog(
  BuildContext context,
  String workspaceId,
  PurchaseObligation claim,
  SettlementAllocation payment,
) => showDialog<bool>(
  context: context,
  builder: (_) =>
      _ReverseDialog(workspaceId: workspaceId, claim: claim, payment: payment),
);

class _ReverseDialog extends ConsumerStatefulWidget {
  const _ReverseDialog({
    required this.workspaceId,
    required this.claim,
    required this.payment,
  });

  final String workspaceId;
  final PurchaseObligation claim;
  final SettlementAllocation payment;

  @override
  ConsumerState<_ReverseDialog> createState() => _ReverseDialogState();
}

class _ReverseDialogState extends ConsumerState<_ReverseDialog> {
  final _reason = TextEditingController();
  var _invalid = false;
  String? _attemptedReason;
  var _requestId = newRequestId();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _invalid = true);
      return;
    }
    setState(() => _invalid = false);
    if (_attemptedReason != reason) _requestId = newRequestId();
    _attemptedReason = reason;
    final navigator = Navigator.of(context);
    final id = _requestId;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'reimbursement reversal failed',
      errorText: context.l10n.purchasesReverseRefused,
      action: () async {
        await ref
            .read(purchaseCommandProvider)
            .reverse(
              widget.workspaceId,
              widget.claim,
              widget.payment,
              reason: reason,
              requestId: id,
            );
      },
    );
    if (ok && mounted) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.purchasesReverseTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            key: const ValueKey('reverse-reason'),
            controller: _reason,
            label: l10n.purchasesReverseReason,
            maxLength: 300,
          ),
          if (_invalid)
            Text(
              l10n.purchasesReverseReasonNeeded,
              key: const ValueKey('reverse-invalid'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('reverse-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('reverse-save'),
          onPressed: _save,
          child: Text(l10n.purchasesReverseAction),
        ),
      ],
    );
  }
}
