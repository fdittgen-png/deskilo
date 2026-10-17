// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/supplier.dart';
import '../../providers/supplier_providers.dart';

/// Asks for a supplier's master data; null when cancelled.
Future<SupplierDraft?> showSupplierDialog(
  BuildContext context,
  Supplier? supplier,
) => showDialog<SupplierDraft>(
  context: context,
  builder: (_) => _SupplierDialog(supplier: supplier),
);

class _SupplierDialog extends StatefulWidget {
  const _SupplierDialog({required this.supplier});

  final Supplier? supplier;

  @override
  State<_SupplierDialog> createState() => _SupplierDialogState();
}

class _SupplierDialogState extends State<_SupplierDialog> {
  late final SupplierDraft _start = widget.supplier == null
      ? const SupplierDraft(name: '')
      : SupplierDraft.of(widget.supplier!);
  late final _name = TextEditingController(text: _start.name);
  late final _number = TextEditingController(text: _start.number);
  late final _taxId = TextEditingController(text: _start.taxId);
  late final _street = TextEditingController(text: _start.street);
  late final _postal = TextEditingController(text: _start.postalCode);
  late final _city = TextEditingController(text: _start.city);
  late final _country = TextEditingController(text: _start.countryCode);
  late final _contact = TextEditingController(text: _start.contact);
  late bool _group = _start.taxIdKind == SupplierIdKind.vatGroup;

  @override
  void dispose() {
    for (final c in [
      _name,
      _number,
      _taxId,
      _street,
      _postal,
      _city,
      _country,
      _contact,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  SupplierDraft _draft() => SupplierDraft(
    id: _start.id,
    name: _name.text,
    number: _number.text,
    taxId: _taxId.text,
    taxIdKind: _group ? SupplierIdKind.vatGroup : SupplierIdKind.vat,
    street: _street.text,
    postalCode: _postal.text,
    city: _city.text,
    countryCode: _country.text,
    contact: _contact.text,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(
        widget.supplier == null ? l10n.suppliersAdd : l10n.suppliersEdit,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              key: const ValueKey('supplier-name'),
              controller: _name,
              label: l10n.suppliersFieldName,
              autofocus: true,
              maxLength: 300,
            ),
            AppTextField(
              key: const ValueKey('supplier-number'),
              controller: _number,
              label: l10n.suppliersFieldNumber,
              helper: l10n.suppliersFieldNumberHelp,
              maxLength: 20,
            ),
            AppTextField(
              key: const ValueKey('supplier-tax-id'),
              controller: _taxId,
              label: l10n.suppliersFieldTaxId,
              maxLength: 60,
            ),
            CheckboxListTile(
              key: const ValueKey('supplier-group'),
              contentPadding: EdgeInsets.zero,
              value: _group,
              title: Text(l10n.suppliersFieldGroup),
              onChanged: (v) => setState(() => _group = v ?? false),
            ),
            AppTextField(
              key: const ValueKey('supplier-street'),
              controller: _street,
              label: l10n.suppliersFieldStreet,
              maxLength: 200,
            ),
            AppTextField(
              key: const ValueKey('supplier-postal'),
              controller: _postal,
              label: l10n.suppliersFieldPostalCode,
              maxLength: 20,
            ),
            AppTextField(
              key: const ValueKey('supplier-city'),
              controller: _city,
              label: l10n.suppliersFieldCity,
              maxLength: 100,
            ),
            AppTextField(
              key: const ValueKey('supplier-country'),
              controller: _country,
              label: l10n.suppliersFieldCountry,
              maxLength: 2,
            ),
            AppTextField(
              key: const ValueKey('supplier-contact'),
              controller: _contact,
              label: l10n.suppliersFieldContact,
              maxLength: 300,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('supplier-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('supplier-save'),
          onPressed: () => Navigator.of(context).pop(_draft()),
          child: Text(MaterialLocalizations.of(context).saveButtonLabel),
        ),
      ],
    );
  }
}

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
  const _SupplierBankDialog({required this.workspaceId, required this.supplier});

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
