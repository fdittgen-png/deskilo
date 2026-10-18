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
import '../../domain/supplier.dart';
import '../../providers/premises_lease_providers.dart';
import '../../providers/supplier_providers.dart';

/// A date to pick, shown under its label; [onPicked] hears the choice.
class LeaseDateButton extends StatelessWidget {
  const LeaseDateButton({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.onPicked,
    required this.first,
    required this.last,
    super.key,
  });

  /// The key of the button, for the person recording the screen.
  final String fieldKey;
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPicked;
  final DateTime first;
  final DateTime last;

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    return OutlinedButton(
      key: ValueKey(fieldKey),
      onPressed: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? first,
          firstDate: first,
          lastDate: last,
        );
        if (d != null) onPicked(d);
      },
      child: Text(
        '$label: ${value == null ? '–' : material.formatMediumDate(value!)}',
      ),
    );
  }
}

/// Records a new lease, or amends [lease] while it is a draft or running.
/// True once the server has it; a refusal keeps the dialog and every entry,
/// and a retry of the same entries sends the same request id.
Future<bool?> showLeaseDialog(
  BuildContext context,
  String workspaceId, {
  PremisesLease? lease,
}) => showDialog<bool>(
  context: context,
  builder: (_) => _LeaseDialog(workspaceId: workspaceId, lease: lease),
);

class _LeaseDialog extends ConsumerStatefulWidget {
  const _LeaseDialog({required this.workspaceId, this.lease});

  final String workspaceId;
  final PremisesLease? lease;

  @override
  ConsumerState<_LeaseDialog> createState() => _LeaseDialogState();
}

class _LeaseDialogState extends ConsumerState<_LeaseDialog> {
  late final _premises = TextEditingController(text: widget.lease?.premises);
  late final _months = TextEditingController(
    text: '${widget.lease?.noticeMonths ?? 3}',
  );
  late final _deposit = TextEditingController(
    text: centsToMajor(widget.lease?.depositCents ?? 0),
  );
  late final _indexation = TextEditingController(
    text: widget.lease?.indexationNote,
  );
  late String? _supplierId = widget.lease?.supplierId;
  late DateTime? _starts = widget.lease?.startsOn;
  late DateTime? _until = widget.lease?.fixedUntil;
  var _invalid = false;
  var _requestId = newRequestId();
  LeaseDraft? _attempted;

  @override
  void dispose() {
    _premises.dispose();
    _months.dispose();
    _deposit.dispose();
    _indexation.dispose();
    super.dispose();
  }

  LeaseDraft? _draft() {
    final deposit = parseCentsInput(
      _deposit.text.isEmpty ? '0' : _deposit.text,
    );
    final months = int.tryParse(_months.text.trim());
    final starts = _starts;
    final supplier = _supplierId;
    if (deposit == null ||
        months == null ||
        starts == null ||
        supplier == null ||
        _premises.text.trim().isEmpty) {
      return null;
    }
    return LeaseDraft(
      leaseId: widget.lease?.id,
      revision: widget.lease?.revision ?? 0,
      supplierId: supplier,
      premises: _premises.text.trim(),
      startsOn: starts,
      fixedUntil: _until,
      noticeMonths: months,
      depositCents: deposit,
      indexationNote: _indexation.text.trim(),
      requestId: _requestId,
    );
  }

  Future<void> _save() async {
    final draft = _draft();
    if (draft == null) {
      setState(() => _invalid = true);
      return;
    }
    // Same entries: same id (a lost answer is replayed, not doubled).
    if (_attempted != null &&
        _attempted!.toPayload().toString() != draft.toPayload().toString()) {
      _requestId = newRequestId();
    }
    final sent = LeaseDraft(
      leaseId: draft.leaseId,
      revision: draft.revision,
      supplierId: draft.supplierId,
      premises: draft.premises,
      startsOn: draft.startsOn,
      fixedUntil: draft.fixedUntil,
      noticeMonths: draft.noticeMonths,
      depositCents: draft.depositCents,
      indexationNote: draft.indexationNote,
      requestId: _requestId,
    );
    _attempted = sent;
    final navigator = Navigator.of(context);
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'lease save failed',
      errorText: context.l10n.leaseRefused,
      action: () async {
        await ref.read(leaseCommandProvider).save(widget.workspaceId, sent);
      },
    );
    if (ok && mounted) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    final suppliers = ref.watch(suppliersProvider(widget.workspaceId));
    final locked =
        widget.lease != null && widget.lease!.status != LeaseStatus.draft;
    final now = ref.read(clockProvider).now();
    return AlertDialog(
      title: Text(l10n.leaseFormTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              key: const ValueKey('lease-lessor'),
              initialValue: _supplierId,
              decoration: InputDecoration(labelText: l10n.leaseFieldLessor),
              items: [
                for (final s in suppliers.value ?? const <Supplier>[])
                  if (s.isActive || s.id == _supplierId)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: locked ? null : (v) => setState(() => _supplierId = v),
            ),
            if ((suppliers.value ?? const <Supplier>[]).isEmpty)
              Text(
                l10n.leaseNeedSupplier,
                key: const ValueKey('lease-need-supplier'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            AppTextField(
              key: const ValueKey('lease-premises'),
              controller: _premises,
              label: l10n.leaseFieldPremises,
              maxLength: 300,
            ),
            const SizedBox(height: AppSpacing.sm),
            LeaseDateButton(
              fieldKey: 'lease-starts',
              label: l10n.leaseFieldStarts,
              value: _starts,
              first: DateTime(now.year - 30),
              last: DateTime(now.year + 30),
              onPicked: locked ? (_) {} : (d) => setState(() => _starts = d),
            ),
            LeaseDateButton(
              fieldKey: 'lease-until',
              label: l10n.leaseFieldFixedUntil,
              value: _until,
              first: _starts ?? DateTime(now.year - 30),
              last: DateTime(now.year + 40),
              onPicked: (d) => setState(() => _until = d),
            ),
            AppTextField(
              key: const ValueKey('lease-notice-months'),
              controller: _months,
              label: l10n.leaseFieldNoticeMonths,
              keyboardType: TextInputType.number,
            ),
            AppTextField(
              key: const ValueKey('lease-deposit'),
              controller: _deposit,
              label: l10n.leaseFieldDeposit,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            AppTextField(
              key: const ValueKey('lease-indexation'),
              controller: _indexation,
              label: l10n.leaseFieldIndexation,
              maxLength: 500,
            ),
            if (_invalid)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  l10n.leaseInvalid,
                  key: const ValueKey('lease-invalid'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('lease-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(material.cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('lease-save'),
          onPressed: _save,
          child: Text(l10n.leaseSave),
        ),
      ],
    );
  }
}
