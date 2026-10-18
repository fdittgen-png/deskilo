// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/premises_lease.dart';
import '../../providers/premises_lease_providers.dart';
import 'premises_lease_dialogs.dart';

/// #2569 C2a -- settles the service charges of a period that is over: what
/// the lessor billed against the advances paid. Final once recorded.
Future<bool?> showLeaseSettlementDialog(
  BuildContext context,
  String workspaceId,
  PremisesLease lease,
) => showDialog<bool>(
  context: context,
  builder: (_) => _SettlementDialog(workspaceId: workspaceId, lease: lease),
);

class _SettlementDialog extends ConsumerStatefulWidget {
  const _SettlementDialog({required this.workspaceId, required this.lease});

  final String workspaceId;
  final PremisesLease lease;

  @override
  ConsumerState<_SettlementDialog> createState() => _SettlementDialogState();
}

class _SettlementDialogState extends ConsumerState<_SettlementDialog> {
  final _billed = TextEditingController();
  DateTime? _from;
  DateTime? _to;
  DateTime? _due;
  var _invalid = false;
  var _requestId = newRequestId();
  String? _attempted;

  @override
  void dispose() {
    _billed.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final today = ref.read(clockProvider).now();
    final cents = parseCentsInput(_billed.text);
    final from = _from;
    final to = _to;
    final due = _due ?? to;
    if (cents == null || from == null || to == null || due == null) {
      setState(() => _invalid = true);
      return;
    }
    final entries = '$from|$to|$cents|$due';
    if (_attempted != null && _attempted != entries) {
      _requestId = newRequestId();
    }
    _attempted = entries;
    final sent = LeaseSettlementCommand(
      leaseId: widget.lease.id,
      revision: widget.lease.revision,
      periodStart: from,
      periodEnd: to,
      actualCents: cents,
      dueOn: due,
      requestId: _requestId,
    );
    final navigator = Navigator.of(context);
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'lease settlement failed',
      errorText: context.l10n.leaseSettleRefused,
      action: () async {
        final done = await ref
            .read(leaseCommandProvider)
            .settle(widget.workspaceId, widget.lease, sent, today);
        if (done == null) setState(() => _invalid = true);
      },
    );
    if (ok && !_invalid && mounted) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = ref.read(clockProvider).now();
    final first = widget.lease.startsOn;
    return AlertDialog(
      title: Text(l10n.leaseSettleTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.leaseSettleHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            LeaseDateButton(
              fieldKey: 'settle-from',
              label: l10n.leaseSettleFrom,
              value: _from,
              first: first,
              last: now,
              onPicked: (d) => setState(() => _from = d),
            ),
            LeaseDateButton(
              fieldKey: 'settle-to',
              label: l10n.leaseSettleTo,
              value: _to,
              first: first,
              last: now,
              onPicked: (d) => setState(() => _to = d),
            ),
            AppTextField(
              key: const ValueKey('settle-billed'),
              controller: _billed,
              label: l10n.leaseSettleBilled,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            LeaseDateButton(
              fieldKey: 'settle-due',
              label: l10n.leaseSettleDue,
              value: _due ?? _to,
              first: first,
              last: DateTime(now.year + 2),
              onPicked: (d) => setState(() => _due = d),
            ),
            if (_invalid)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  l10n.leaseSettleInvalid,
                  key: const ValueKey('settle-invalid'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('settle-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('settle-save'),
          onPressed: _save,
          child: Text(l10n.leaseSettleSave),
        ),
      ],
    );
  }
}
