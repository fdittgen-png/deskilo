// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/purchase.dart';
import '../../providers/purchase_providers.dart';

String paymentMethodLabel(AppLocalizations l10n, String wire) => switch (wire) {
  'bank_transfer' => l10n.purchasesMethodBank,
  'cash' => l10n.purchasesMethodCash,
  'card' => l10n.purchasesMethodCard,
  _ => l10n.purchasesMethodOther,
};

/// Records cash paid against [claim]. True once the server has it; a refusal
/// keeps the dialog and every entry, and a retry of the same entries sends
/// the same request id, so it never pays twice. The claim's revision travels
/// with the payment: if anything moved meanwhile, the server refuses.
Future<bool?> showReimbursementDialog(
  BuildContext context,
  String workspaceId,
  PurchaseObligation claim,
) => showDialog<bool>(
  context: context,
  builder: (_) => _PayDialog(workspaceId: workspaceId, claim: claim),
);

class _PayDialog extends ConsumerStatefulWidget {
  const _PayDialog({required this.workspaceId, required this.claim});

  final String workspaceId;
  final PurchaseObligation claim;

  @override
  ConsumerState<_PayDialog> createState() => _PayDialogState();
}

class _PayDialogState extends ConsumerState<_PayDialog> {
  late final _amount = TextEditingController(
    text: centsToMajor(widget.claim.remainingCents),
  );
  final _reference = TextEditingController();
  DateTime? _paidOn;
  var _method = PaymentMethod.bankTransfer;
  var _invalid = false;

  ReimbursementCommand? _attempted;
  var _requestId = newRequestId();

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  DateTime get _today {
    final now = ref.read(clockProvider).now();
    return DateTime(now.year, now.month, now.day);
  }

  ReimbursementCommand? _command() {
    final cents = parseCentsInput(_amount.text);
    if (cents == null ||
        cents <= 0 ||
        cents > widget.claim.remainingCents) {
      return null;
    }
    return ReimbursementCommand(
      obligationId: widget.claim.id,
      amountCents: cents,
      revision: widget.claim.revision,
      requestId: _requestId,
      paidOn: _paidOn ?? _today,
      method: _method,
      reference: _reference.text.trim(),
    );
  }

  Future<void> _save() async {
    final command = _command();
    if (command == null) {
      setState(() => _invalid = true);
      return;
    }
    setState(() => _invalid = false);
    // Same entries: same id (a lost answer is replayed, not doubled).
    // Changed entries: a new request, against the same revision.
    if (_attempted == null || !_attempted!.sameEntriesAs(command)) {
      _requestId = newRequestId();
    }
    final sent = ReimbursementCommand(
      obligationId: command.obligationId,
      amountCents: command.amountCents,
      revision: command.revision,
      requestId: _requestId,
      paidOn: command.paidOn,
      method: command.method,
      reference: command.reference,
    );
    _attempted = sent;
    final navigator = Navigator.of(context);
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'reimbursement record failed',
      errorText: context.l10n.purchasesPayRefused,
      action: () async {
        await ref
            .read(purchaseCommandProvider)
            .reimburse(widget.workspaceId, widget.claim, sent);
      },
    );
    if (ok && mounted) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    final money = moneyFormat(widget.claim.currency);
    return AlertDialog(
      title: Text(l10n.purchasesPayTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.purchasesPayHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              key: const ValueKey('pay-amount'),
              controller: _amount,
              label: l10n.purchasesPayAmount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            DropdownButtonFormField<PaymentMethod>(
              key: const ValueKey('pay-method'),
              initialValue: _method,
              decoration: InputDecoration(labelText: l10n.purchasesPayMethod),
              items: [
                for (final m in PaymentMethod.values)
                  DropdownMenuItem(
                    value: m,
                    child: Text(paymentMethodLabel(l10n, m.wire)),
                  ),
              ],
              onChanged: (v) => setState(() => _method = v ?? _method),
            ),
            AppTextField(
              key: const ValueKey('pay-reference'),
              controller: _reference,
              label: l10n.purchasesPayReference,
              maxLength: 200,
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              key: const ValueKey('pay-date'),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _paidOn ?? _today,
                  firstDate: DateTime(2000),
                  lastDate: _today,
                  helpText: l10n.purchasesPickDate,
                );
                if (d != null) setState(() => _paidOn = d);
              },
              child: Text(
                '${l10n.purchasesPayDate}: '
                '${material.formatMediumDate(_paidOn ?? _today)}',
              ),
            ),
            if (_invalid)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  l10n.purchasesPayInvalid(
                    money.formatMinor(widget.claim.remainingCents),
                  ),
                  key: const ValueKey('pay-invalid'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('pay-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(material.cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('pay-save'),
          onPressed: _save,
          child: Text(l10n.purchasesPayAction),
        ),
      ],
    );
  }
}
