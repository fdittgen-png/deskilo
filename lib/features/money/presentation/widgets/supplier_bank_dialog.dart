// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/supplier.dart';
import '../../providers/supplier_providers.dart';

/// What a person typed as bank details.
class SupplierBankInput {
  const SupplierBankInput({
    required this.accountHolder,
    required this.iban,
    required this.bic,
  });

  final String accountHolder;
  final String iban;
  final String bic;
}

/// The bank-detail revisions of [supplier] and the form for the next one;
/// null when cancelled.
Future<SupplierBankInput?> showSupplierBankDialog(
  BuildContext context,
  String workspaceId,
  Supplier supplier,
) => showDialog<SupplierBankInput>(
  context: context,
  builder: (_) =>
      _SupplierBankDialog(workspaceId: workspaceId, supplier: supplier),
);

class _SupplierBankDialog extends ConsumerStatefulWidget {
  const _SupplierBankDialog({
    required this.workspaceId,
    required this.supplier,
  });

  final String workspaceId;
  final Supplier supplier;

  @override
  ConsumerState<_SupplierBankDialog> createState() =>
      _SupplierBankDialogState();
}

class _SupplierBankDialogState extends ConsumerState<_SupplierBankDialog> {
  final _holder = TextEditingController();
  final _iban = TextEditingController();
  final _bic = TextEditingController();

  @override
  void dispose() {
    _holder.dispose();
    _iban.dispose();
    _bic.dispose();
    super.dispose();
  }

  String _outcome(BuildContext context, BankValidation v) {
    final l10n = context.l10n;
    return switch (v) {
      BankValidation.valid => l10n.suppliersBankValid,
      BankValidation.invalid => l10n.suppliersBankInvalid,
      BankValidation.cleared => l10n.suppliersBankCleared,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final history =
        ref
            .watch(
              supplierBankHistoryProvider((
                workspaceId: widget.workspaceId,
                supplierId: widget.supplier.id,
              )),
            )
            .value ??
        const <SupplierBankRevision>[];
    return AlertDialog(
      title: Text('${l10n.suppliersBank} · ${widget.supplier.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.suppliersBankHistory),
            if (history.isEmpty) Text(l10n.suppliersBankNone),
            for (final r in history)
              Text(
                key: ValueKey('supplier-bank-rev-${r.revision}'),
                '${l10n.suppliersBankRevision(r.revision.toString(), _outcome(context, r.validation))}'
                '${r.iban.isEmpty ? '' : ' · ${r.iban}'}',
              ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              key: const ValueKey('supplier-bank-holder'),
              controller: _holder,
              label: l10n.suppliersBankHolder,
              maxLength: 200,
            ),
            AppTextField(
              key: const ValueKey('supplier-bank-iban'),
              controller: _iban,
              label: l10n.suppliersBankIban,
              maxLength: 40,
            ),
            AppTextField(
              key: const ValueKey('supplier-bank-bic'),
              controller: _bic,
              label: l10n.suppliersBankBic,
              maxLength: 20,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('supplier-bank-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('supplier-bank-save'),
          onPressed: () => Navigator.of(context).pop(
            SupplierBankInput(
              accountHolder: _holder.text,
              iban: _iban.text,
              bic: _bic.text,
            ),
          ),
          child: Text(MaterialLocalizations.of(context).saveButtonLabel),
        ),
      ],
    );
  }
}
