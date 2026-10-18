// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/lease_commitment.dart';
import '../../domain/purchase.dart';
import '../../providers/premises_lease_providers.dart';
import '../../providers/purchase_providers.dart';

/// Matches a bill of the lessor to [occurrence]: the bill, its line and the
/// amount it covers. True once the server has it; a refusal keeps the dialog
/// and every entry, and a retry of the same entries sends the same request id.
Future<bool?> showLeaseMatchDialog(
  BuildContext context,
  String workspaceId,
  CommitmentOccurrence occurrence,
  String currencyCode,
) => showDialog<bool>(
  context: context,
  builder: (_) => _MatchDialog(
    workspaceId: workspaceId,
    occurrence: occurrence,
    currencyCode: currencyCode,
  ),
);

class _MatchDialog extends ConsumerStatefulWidget {
  const _MatchDialog({
    required this.workspaceId,
    required this.occurrence,
    required this.currencyCode,
  });

  final String workspaceId;
  final CommitmentOccurrence occurrence;
  final String currencyCode;

  @override
  ConsumerState<_MatchDialog> createState() => _MatchDialogState();
}

class _MatchDialogState extends ConsumerState<_MatchDialog> {
  final _amount = TextEditingController();
  String? _purchaseId;
  var _lineNo = 1;
  var _invalid = false;
  var _requestId = newRequestId();
  String? _attempted;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _pick(String? id) => setState(() {
    _purchaseId = id;
    _lineNo = 1;
    _amount.text = centsToMajor(widget.occurrence.remainingCents);
  });

  Future<void> _save(PurchaseDetail detail) async {
    final cents = parseCentsInput(_amount.text);
    if (cents == null || cents <= 0 || cents > widget.occurrence.remainingCents) {
      setState(() => _invalid = true);
      return;
    }
    final entries = '${detail.summary.id}|$_lineNo|$cents';
    if (_attempted != null && _attempted != entries) _requestId = newRequestId();
    _attempted = entries;
    final command = CommitmentMatchCommand(
      purchaseId: detail.summary.id,
      revision: detail.revision,
      allocations: [
        CommitmentAllocation(
          occurrenceId: widget.occurrence.id,
          lineNo: _lineNo,
          cents: cents,
        ),
      ],
      requestId: _requestId,
    );
    final navigator = Navigator.of(context);
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'commitment match failed',
      errorText: context.l10n.leaseMatchRefused,
      action: () async {
        await ref
            .read(commitmentCommandProvider)
            .match(widget.workspaceId, command);
      },
    );
    if (ok && mounted) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    final money = moneyFormat(widget.currencyCode);
    final bills = [
      for (final p in ref.watch(purchasesProvider(widget.workspaceId)).value ??
          const <PurchaseSummary>[])
        if (p.kind == PurchaseKind.bill &&
            (p.state == PurchaseState.pending ||
                p.state == PurchaseState.approved) &&
            p.currency == widget.currencyCode)
          p,
    ];
    final detail = _purchaseId == null
        ? null
        : ref
              .watch(
                purchaseDetailProvider((
                  workspaceId: widget.workspaceId,
                  purchaseId: _purchaseId!,
                )),
              )
              .value;
    return AlertDialog(
      title: Text(l10n.leaseMatchTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.leaseMatchHint(
                money.formatMinor(widget.occurrence.remainingCents),
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (bills.isEmpty)
              Text(
                l10n.leaseMatchNoBills,
                key: const ValueKey('match-no-bills'),
              )
            else
              DropdownButtonFormField<String>(
                key: const ValueKey('match-bill'),
                initialValue: _purchaseId,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.leaseMatchBill),
                items: [
                  for (final b in bills)
                    DropdownMenuItem(
                      value: b.id,
                      child: Text(
                        '${b.reference} · ${money.formatMinor(b.grossCents)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _pick,
              ),
            if (detail != null && detail.lines.length > 1)
              DropdownButtonFormField<int>(
                key: const ValueKey('match-line'),
                initialValue: _lineNo,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.leaseMatchLine),
                items: [
                  for (final line in detail.lines)
                    DropdownMenuItem(
                      value: line.lineNo,
                      child: Text(
                        '${line.lineNo} · ${line.description} · '
                        '${money.formatMinor(line.grossCents)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _lineNo = v ?? _lineNo),
              ),
            if (detail != null)
              AppTextField(
                key: const ValueKey('match-amount'),
                controller: _amount,
                label: l10n.leaseMatchAmount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            if (_invalid)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  l10n.leaseMatchInvalid(
                    money.formatMinor(widget.occurrence.remainingCents),
                  ),
                  key: const ValueKey('match-invalid'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('match-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(material.cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('match-save'),
          onPressed: detail == null ? null : () => _save(detail),
          child: Text(l10n.leaseMatchSave),
        ),
      ],
    );
  }
}
