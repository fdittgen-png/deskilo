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
import '../../domain/purchase.dart';
import '../../domain/supplier.dart';
import '../../providers/purchase_providers.dart';
import '../../providers/supplier_providers.dart';

/// Captures a supplier bill as a draft and saves it. True once the server
/// has it; a refusal keeps the dialog and every entry, and a retry of the
/// same entries sends the same request id, so it never saves twice.
Future<bool?> showPurchaseBillDialog(
  BuildContext context,
  String workspaceId,
) => showDialog<bool>(
  context: context,
  builder: (_) => _BillDialog(workspaceId: workspaceId),
);

class _BillDialog extends ConsumerStatefulWidget {
  const _BillDialog({required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<_BillDialog> createState() => _BillDialogState();
}

class _BillDialogState extends ConsumerState<_BillDialog> {
  final _reference = TextEditingController();
  final _description = TextEditingController();
  final _gross = TextEditingController();
  final _tax = TextEditingController();
  String? _supplierId;
  var _purpose = 'unresolved';
  DateTime? _invoiceDate;
  DateTime? _dueDate;
  bool _invalid = false;

  // The entries of the last attempt and the id they were sent under.
  PurchaseBillDraft? _attempted;
  String _requestId = newRequestId();

  @override
  void dispose() {
    for (final c in [_reference, _description, _gross, _tax]) {
      c.dispose();
    }
    super.dispose();
  }

  PurchaseBillDraft? _draft() {
    final gross = parseCentsInput(_gross.text);
    final taxText = _tax.text.trim();
    final tax = taxText.isEmpty ? null : parseCentsInput(taxText);
    if (gross == null || gross <= 0) return null;
    if (taxText.isNotEmpty && (tax == null || tax > gross)) return null;
    return PurchaseBillDraft(
      grossCents: gross,
      supplierId: _supplierId,
      reference: _reference.text.trim(),
      description: _description.text.trim(),
      originalDate: _invoiceDate,
      dueOn: _dueDate,
      taxCents: tax,
      recognitionKind: _purpose,
    );
  }

  Future<void> _save() async {
    final draft = _draft();
    if (draft == null) {
      setState(() => _invalid = true);
      return;
    }
    setState(() => _invalid = false);
    // Same entries: same id (a lost answer is replayed, not doubled).
    // Changed entries: a new request.
    if (_attempted == null || !_same(_attempted!, draft)) {
      _requestId = newRequestId();
    }
    _attempted = draft;
    final navigator = Navigator.of(context);
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'purchase draft save failed',
      errorText: context.l10n.purchasesRefused,
      action: () async {
        await ref
            .read(purchaseCommandProvider)
            .saveBill(widget.workspaceId, _requestId, draft);
      },
    );
    if (ok && mounted) navigator.pop(true);
  }

  static bool _same(PurchaseBillDraft a, PurchaseBillDraft b) =>
      a.grossCents == b.grossCents &&
      a.taxCents == b.taxCents &&
      a.supplierId == b.supplierId &&
      a.reference == b.reference &&
      a.description == b.description &&
      a.originalDate == b.originalDate &&
      a.recognitionKind == b.recognitionKind &&
      a.dueOn == b.dueOn;

  Future<DateTime?> _pick(DateTime? current) => showDatePicker(
    context: context,
    initialDate: current ?? ref.read(clockProvider).now(),
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
    helpText: context.l10n.purchasesPickDate,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    final suppliers = [
      for (final s
          in ref.watch(suppliersProvider(widget.workspaceId)).value ??
              const <Supplier>[])
        if (s.isActive) s,
    ];
    return AlertDialog(
      title: Text(l10n.purchasesAddBill),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String?>(
              key: const ValueKey('purchase-supplier'),
              initialValue: _supplierId,
              decoration: InputDecoration(labelText: l10n.purchasesSupplier),
              items: [
                DropdownMenuItem<String?>(
                  child: Text(l10n.purchasesNoSupplier),
                ),
                for (final s in suppliers)
                  DropdownMenuItem<String?>(
                    value: s.id,
                    child: Text('${s.number} · ${s.name}'),
                  ),
              ],
              onChanged: (v) => setState(() => _supplierId = v),
            ),
            // #2576 — what it is for, in plain words; no tax class or useful
            // life is asked of whoever submits.
            DropdownButtonFormField<String>(
              key: const ValueKey('purchase-purpose'),
              initialValue: _purpose,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.purchasesPurpose),
              items: [
                DropdownMenuItem(value: 'operating', child: Text(l10n.purchasesPurposeOperating)),
                DropdownMenuItem(value: 'stock', child: Text(l10n.purchasesPurposeStock)),
                DropdownMenuItem(value: 'asset', child: Text(l10n.purchasesPurposeAsset)),
                DropdownMenuItem(value: 'prepayment', child: Text(l10n.purchasesPurposePrepayment)),
                DropdownMenuItem(value: 'deposit', child: Text(l10n.purchasesPurposeDeposit)),
                DropdownMenuItem(value: 'unresolved', child: Text(l10n.purchasesPurposeReview)),
              ],
              onChanged: (v) => _purpose = v ?? _purpose,
            ),
            AppTextField(
              key: const ValueKey('purchase-reference'),
              controller: _reference,
              label: l10n.purchasesReference,
              maxLength: 200,
            ),
            AppTextField(
              key: const ValueKey('purchase-description'),
              controller: _description,
              label: l10n.purchasesDescription,
              maxLength: 500,
            ),
            AppTextField(
              key: const ValueKey('purchase-gross'),
              controller: _gross,
              label: l10n.purchasesGross,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            AppTextField(
              key: const ValueKey('purchase-tax'),
              controller: _tax,
              label: l10n.purchasesTaxField,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                OutlinedButton(
                  key: const ValueKey('purchase-invoice-date'),
                  onPressed: () async {
                    final d = await _pick(_invoiceDate);
                    if (d != null) setState(() => _invoiceDate = d);
                  },
                  child: Text(
                    _invoiceDate == null
                        ? l10n.purchasesInvoiceDate
                        : '${l10n.purchasesInvoiceDate}: '
                              '${material.formatMediumDate(_invoiceDate!)}',
                  ),
                ),
                OutlinedButton(
                  key: const ValueKey('purchase-due-date'),
                  onPressed: () async {
                    final d = await _pick(_dueDate);
                    if (d != null) setState(() => _dueDate = d);
                  },
                  child: Text(
                    _dueDate == null
                        ? l10n.purchasesDueDate
                        : '${l10n.purchasesDueDate}: '
                              '${material.formatMediumDate(_dueDate!)}',
                  ),
                ),
              ],
            ),
            if (_invalid)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  l10n.purchasesInvalid,
                  key: const ValueKey('purchase-invalid'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('purchase-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('purchase-save'),
          onPressed: _save,
          child: Text(l10n.purchasesSave),
        ),
      ],
    );
  }
}
