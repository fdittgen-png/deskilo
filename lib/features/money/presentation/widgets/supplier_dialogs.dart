// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The supplier form: the fields, Find company details beside them, and the
// save step (supplier_save_step.dart), which saves while the form is open.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/company_lookup.dart';
import '../../domain/supplier.dart';
import '../../domain/supplier_prefill.dart';
import 'supplier_lookup_dialog.dart';
import 'supplier_save_step.dart';

/// What the supplier form was closed with.
sealed class SupplierDialogResult {
  const SupplierDialogResult();
}

/// The supplier was saved under [id].
class SupplierDialogSaved extends SupplierDialogResult {
  const SupplierDialogSaved(this.id);

  final String id;
}

/// A supplier already there (by identifier, or chosen from the caution
/// about a same name): open that one instead.
class SupplierDialogOpenExisting extends SupplierDialogResult {
  const SupplierDialogOpenExisting(this.supplier);

  final Supplier supplier;
}

/// Asks for a supplier's master data and saves it with [onSave] (the id
/// saved, or null when nothing was sent); null when cancelled. With
/// [lookupWorkspaceId] the form offers Find company details, which fills
/// the fields from a registry for review; [existing] is what the duplicate
/// checks read.
Future<SupplierDialogResult?> showSupplierDialog(
  BuildContext context,
  Supplier? supplier, {
  required Future<String?> Function(SupplierDraft draft) onSave,
  String? lookupWorkspaceId,
  List<Supplier> existing = const [],
}) => showDialog<SupplierDialogResult>(
  context: context,
  builder: (_) => _SupplierDialog(
    supplier: supplier,
    onSave: onSave,
    lookupWorkspaceId: lookupWorkspaceId,
    existing: existing,
  ),
);

/// The form's field keys → the widget keys the recorder and the tests
/// drive, in the order the fields appear.
const _widgetKeys = {
  'name': 'supplier-name',
  'number': 'supplier-number',
  'taxId': 'supplier-tax-id',
  'street': 'supplier-street',
  'postalCode': 'supplier-postal',
  'city': 'supplier-city',
  'countryCode': 'supplier-country',
  'contact': 'supplier-contact',
};

class _SupplierDialog extends StatefulWidget {
  const _SupplierDialog({
    required this.supplier,
    required this.onSave,
    required this.lookupWorkspaceId,
    required this.existing,
  });

  final Supplier? supplier;
  final Future<String?> Function(SupplierDraft draft) onSave;
  final String? lookupWorkspaceId;
  final List<Supplier> existing;

  @override
  State<_SupplierDialog> createState() => _SupplierDialogState();
}

class _SupplierDialogState extends State<_SupplierDialog> {
  late final SupplierDraft _start = widget.supplier == null
      ? const SupplierDraft(name: '')
      : SupplierDraft.of(widget.supplier!);
  late final FormControllers _fields = FormControllers({
    'name': _start.name,
    'number': _start.number,
    'taxId': _start.taxId,
    'street': _start.street,
    'postalCode': _start.postalCode,
    'city': _start.city,
    'countryCode': _start.countryCode,
    'contact': _start.contact,
  });
  late bool _group = _start.taxIdKind == SupplierIdKind.vatGroup;

  /// The registry's answer under review, when the form was filled by one.
  SupplierPrefill? _prefill;

  /// Where each field's value came from; a field the person changes after
  /// the lookup moves to [FieldProvenance.userEdited] and back when the
  /// retrieved value is restored.
  Map<String, FieldProvenance> _provenance = const {};
  Map<String, String> _filled = const {};

  /// What the save step says, and whether it is under way.
  late final SupplierSaveStep _step = SupplierSaveStep(
    existing: widget.existing,
    onSave: widget.onSave,
  );

  /// Where the save step's words are, scrolled into view when they change.
  final _statusKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    for (final key in _widgetKeys.keys) {
      _fields[key].addListener(_onEdited);
    }
    _step.addListener(_onStep);
  }

  void _onStep() => setState(() {});

  @override
  void dispose() {
    _fields.dispose();
    _step.dispose();
    super.dispose();
  }

  void _onEdited() {
    _step.edited(_draft());
    final prefill = _prefill;
    if (prefill == null) return;
    final next = <String, FieldProvenance>{};
    for (final entry in prefill.provenance.entries) {
      final unchanged = _fields[entry.key].text == _filled[entry.key];
      next[entry.key] = unchanged ? entry.value : FieldProvenance.userEdited;
    }
    if (next.toString() != _provenance.toString()) {
      setState(() => _provenance = next);
    }
  }

  SupplierDraft _draft() => SupplierDraft(
    id: _start.id,
    name: _fields.text('name'),
    number: _fields.text('number'),
    taxId: _fields.text('taxId'),
    taxIdKind: _group ? SupplierIdKind.vatGroup : SupplierIdKind.vat,
    street: _fields.text('street'),
    postalCode: _fields.text('postalCode'),
    city: _fields.text('city'),
    countryCode: _fields.text('countryCode'),
    contact: _fields.text('contact'),
  );

  Future<void> _lookup() async {
    final outcome = await showSupplierLookupDialog(
      context,
      workspaceId: widget.lookupWorkspaceId!,
      existing: widget.existing,
      countryCode: _fields.text('countryCode'),
      identifier: _fields.text('taxId'),
      base: _draft(),
    );
    if (!mounted || outcome == null) return;
    switch (outcome) {
      case SupplierLookupExisting(:final supplier):
        Navigator.of(context).pop(SupplierDialogOpenExisting(supplier));
      case SupplierLookupManual(:final countryCode, :final identifier):
        _fields['countryCode'].text = countryCode;
        _fields['taxId'].text = identifier;
      case SupplierLookupReviewed(:final prefill):
        _apply(prefill);
    }
  }

  void _apply(SupplierPrefill prefill) {
    final d = prefill.draft;
    final values = {
      'name': d.name,
      'taxId': d.taxId,
      'street': d.street,
      'postalCode': d.postalCode,
      'city': d.city,
      'countryCode': d.countryCode,
    };
    setState(() {
      _prefill = prefill;
      _provenance = {...prefill.provenance};
      _filled = values;
    });
    // After the state holds the answer, so the listeners compare against it.
    values.forEach((key, value) => _fields[key].text = value);
  }

  String? _helper(AppLocalizations l10n, String key, {String? otherwise}) {
    final prefill = _prefill;
    if (prefill == null) return otherwise;
    final provider = supplierLookupProviderName(l10n, prefill.result.providerId);
    return switch (_provenance[key]) {
      null => otherwise,
      FieldProvenance.retrieved => l10n.supplierFieldRetrieved(provider),
      FieldProvenance.validated => l10n.supplierFieldValidated(provider),
      FieldProvenance.notReturned => l10n.supplierFieldNotReturned,
      FieldProvenance.userEdited => l10n.supplierFieldEdited,
    };
  }

  Widget _field(
    AppLocalizations l10n,
    String key,
    String label, {
    required int maxLength,
    String? helper,
    bool autofocus = false,
  }) => AppTextField(
    key: ValueKey(_widgetKeys[key]!),
    controller: _fields[key],
    label: label,
    helper: _helper(l10n, key, otherwise: helper),
    error: key == 'name' ? _step.value.nameError : null,
    autofocus: autofocus,
    enabled: !_step.value.busy,
    maxLength: maxLength,
  );

  /// Says [text] to a screen reader and brings the save step's words into
  /// view, which sit under the last field of a form that may be scrolled.
  void _announce(String text) {
    if (!mounted) return;
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        text,
        Directionality.of(context),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shown = _statusKey.currentContext;
      if (shown != null && shown.mounted) {
        unawaited(Scrollable.ensureVisible(shown));
      }
    });
  }

  Future<void> _submit() async {
    final id = await _step.submit(
      _draft(),
      context.l10n,
      announce: _announce,
    );
    if (!mounted || id == null) return;
    Navigator.of(context).pop(SupplierDialogSaved(id));
  }

  void _open(Supplier supplier) =>
      Navigator.of(context).pop(SupplierDialogOpenExisting(supplier));

  /// The lookup's verdict, source and time, read as one announcement.
  Widget _reviewHeader(BuildContext context, SupplierPrefill prefill) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final result = prefill.result;
    final at = result.lookedUpAt;
    final provider = supplierLookupProviderName(l10n, result.providerId);
    return Semantics(
      container: true,
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            key: const ValueKey('supplier-review-status'),
            supplierLookupStatusText(l10n, result),
            style: theme.textTheme.titleSmall,
          ),
          if (at != null)
            Text(
              key: const ValueKey('supplier-review-source'),
              l10n.supplierLookupSource(
                provider,
                appFormatOf(context).dateTime(at),
              ),
              style: theme.textTheme.bodySmall,
            ),
          Text(
            result.retrieval == LookupRetrieval.notReturned
                ? l10n.supplierLookupNothingReturned
                : l10n.supplierLookupReviewHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const FormGap(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final prefill = _prefill;
    return AlertDialog(
      title: Text(
        widget.supplier == null ? l10n.suppliersAdd : l10n.suppliersEdit,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.lookupWorkspaceId != null) ...[
              FilledButton.tonalIcon(
                key: const ValueKey('supplier-find-details'),
                onPressed: _lookup,
                icon: const Icon(Icons.travel_explore_outlined),
                label: Text(l10n.supplierLookupFind),
              ),
              const FormGap.small(),
              Text(
                l10n.supplierLookupManualHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const FormGap(),
            ],
            if (prefill != null) _reviewHeader(context, prefill),
            _field(
              l10n,
              'name',
              l10n.suppliersFieldName,
              maxLength: 300,
              autofocus: prefill == null,
            ),
            _field(
              l10n,
              'number',
              l10n.suppliersFieldNumber,
              helper: l10n.suppliersFieldNumberHelp,
              maxLength: 20,
            ),
            _field(l10n, 'taxId', l10n.suppliersFieldTaxId, maxLength: 60),
            CheckboxListTile(
              key: const ValueKey('supplier-group'),
              contentPadding: EdgeInsets.zero,
              value: _group,
              title: Text(l10n.suppliersFieldGroup),
              onChanged: (v) => setState(() => _group = v ?? false),
            ),
            _field(l10n, 'street', l10n.suppliersFieldStreet, maxLength: 200),
            _field(
              l10n,
              'postalCode',
              l10n.suppliersFieldPostalCode,
              maxLength: 20,
            ),
            _field(l10n, 'city', l10n.suppliersFieldCity, maxLength: 100),
            _field(
              l10n,
              'countryCode',
              l10n.suppliersFieldCountry,
              maxLength: 2,
            ),
            _field(l10n, 'contact', l10n.suppliersFieldContact, maxLength: 300),
            SupplierSaveStatus(
              key: _statusKey,
              state: _step.value,
              onOpen: _open,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('supplier-cancel'),
          onPressed: _step.value.busy
              ? null
              : () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('supplier-save'),
          onPressed: _step.value.busy ? null : _submit,
          child: Text(MaterialLocalizations.of(context).saveButtonLabel),
        ),
      ],
    );
  }
}
