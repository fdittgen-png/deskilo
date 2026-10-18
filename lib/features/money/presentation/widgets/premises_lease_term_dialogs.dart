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
import '../../../../l10n/app_localizations.dart';
import '../../domain/premises_lease.dart';
import '../../providers/premises_lease_providers.dart';
import 'premises_lease_dialogs.dart';

String leaseTermKindLabel(AppLocalizations l10n, LeaseTermKind kind) =>
    switch (kind) {
      LeaseTermKind.rent => l10n.leaseKindRent,
      LeaseTermKind.serviceChargeAdvance => l10n.leaseKindServiceCharge,
      LeaseTermKind.other => l10n.leaseKindOther,
    };

/// Adds an amount from a date to [lease]: it supersedes the term of the same
/// charge in force and never edits it.
Future<bool?> showLeaseTermDialog(
  BuildContext context,
  String workspaceId,
  PremisesLease lease,
) => showDialog<bool>(
  context: context,
  builder: (_) => _TermDialog(workspaceId: workspaceId, lease: lease),
);

class _TermDialog extends ConsumerStatefulWidget {
  const _TermDialog({required this.workspaceId, required this.lease});

  final String workspaceId;
  final PremisesLease lease;

  @override
  ConsumerState<_TermDialog> createState() => _TermDialogState();
}

class _TermDialogState extends ConsumerState<_TermDialog> {
  final _amount = TextEditingController();
  final _label = TextEditingController();
  var _kind = LeaseTermKind.rent;
  var _every = 1;
  DateTime? _from;
  var _invalid = false;
  var _requestId = newRequestId();
  String? _attempted;

  @override
  void dispose() {
    _amount.dispose();
    _label.dispose();
    super.dispose();
  }

  LeaseTermCommand? _command() {
    final cents = parseCentsInput(_amount.text);
    final from = _from;
    if (cents == null ||
        cents <= 0 ||
        from == null ||
        (_kind == LeaseTermKind.other && _label.text.trim().isEmpty)) {
      return null;
    }
    return LeaseTermCommand(
      leaseId: widget.lease.id,
      revision: widget.lease.revision,
      kind: _kind,
      label: _kind == LeaseTermKind.other ? _label.text.trim() : '',
      amountCents: cents,
      everyMonths: _every,
      effectiveFrom: from,
      requestId: _requestId,
    );
  }

  Future<void> _save() async {
    final command = _command();
    if (command == null) {
      setState(() => _invalid = true);
      return;
    }
    final entries =
        '${command.kind.wire}|${command.label}|${command.amountCents}|'
        '${command.everyMonths}|${command.effectiveFrom}';
    if (_attempted != null && _attempted != entries) {
      _requestId = newRequestId();
    }
    _attempted = entries;
    final sent = LeaseTermCommand(
      leaseId: command.leaseId,
      revision: command.revision,
      kind: command.kind,
      label: command.label,
      amountCents: command.amountCents,
      everyMonths: command.everyMonths,
      effectiveFrom: command.effectiveFrom,
      requestId: _requestId,
    );
    final navigator = Navigator.of(context);
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'lease term failed',
      errorText: context.l10n.leaseTermRefused,
      action: () async {
        await ref
            .read(leaseCommandProvider)
            .addTerm(widget.workspaceId, widget.lease, sent);
      },
    );
    if (ok && mounted) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    final now = ref.read(clockProvider).now();
    return AlertDialog(
      title: Text(l10n.leaseTermTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.leaseTermHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            DropdownButtonFormField<LeaseTermKind>(
              key: const ValueKey('term-kind'),
              initialValue: _kind,
              decoration: InputDecoration(labelText: l10n.leaseTermKind),
              items: [
                for (final k in LeaseTermKind.values)
                  DropdownMenuItem(
                    value: k,
                    child: Text(leaseTermKindLabel(l10n, k)),
                  ),
              ],
              onChanged: (v) => setState(() => _kind = v ?? _kind),
            ),
            if (_kind == LeaseTermKind.other)
              AppTextField(
                key: const ValueKey('term-label'),
                controller: _label,
                label: l10n.leaseTermLabel,
                maxLength: 60,
              ),
            AppTextField(
              key: const ValueKey('term-amount'),
              controller: _amount,
              label: l10n.leaseTermAmount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            DropdownButtonFormField<int>(
              key: const ValueKey('term-every'),
              initialValue: _every,
              decoration: InputDecoration(labelText: l10n.leaseTermEvery),
              items: [
                DropdownMenuItem(value: 1, child: Text(l10n.leaseEveryMonth)),
                DropdownMenuItem(value: 3, child: Text(l10n.leaseEveryQuarter)),
                DropdownMenuItem(
                  value: 6,
                  child: Text(l10n.leaseEveryHalfYear),
                ),
                DropdownMenuItem(value: 12, child: Text(l10n.leaseEveryYear)),
              ],
              onChanged: (v) => setState(() => _every = v ?? _every),
            ),
            const SizedBox(height: AppSpacing.sm),
            LeaseDateButton(
              fieldKey: 'term-from',
              label: l10n.leaseTermFrom,
              value: _from,
              first: widget.lease.startsOn,
              last: DateTime(now.year + 30),
              onPicked: (d) => setState(() => _from = d),
            ),
            if (_invalid)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  l10n.leaseTermInvalid,
                  key: const ValueKey('term-invalid'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('term-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(material.cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('term-save'),
          onPressed: _save,
          child: Text(l10n.leaseTermSave),
        ),
      ],
    );
  }
}
