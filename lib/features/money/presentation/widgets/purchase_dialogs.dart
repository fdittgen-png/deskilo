// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/format/decimal_input.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/adaptive/task_choice.dart';
import '../../../../core/ui/adaptive/task_surface.dart';
import '../../../../core/ui/form_error_summary.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/purchase_order_commands.dart';
import '../../domain/purchase.dart';
import '../../domain/purchase_order.dart';
import '../../providers/purchase_providers.dart';
import '../../providers/supplier_providers.dart';
import '../screens/money_view_data.dart';
import 'purchase_bill_order_field.dart';
import 'purchase_exchange_rate.dart';
import 'purchase_item_fields.dart';
import 'purchase_labels.dart';
import 'purchase_place_field.dart';
import 'supplier_order_defaults.dart';

/// Captures a supplier bill as a draft and saves it. True once the server
/// has it; a refusal keeps the dialog and every entry, and a retry of the
/// same entries sends the same request id, so it never saves twice.
Future<bool?> showPurchaseBillDialog(
  BuildContext context,
  String workspaceId,
) => showTask<bool>(
  // #3615 — a standard task: a side panel beside the purchases at the desk.
  context,
  size: TaskSize.standard,
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

  /// #3307 — the order the bill charges, when one is picked.
  String? _orderId;
  PurchaseItemEntry _item = (itemId: null, quantity: '', unit: '');
  var _purpose = 'unresolved';
  PurchasePlace? _place;
  PurchaseCurrencyChoice _money = (currency: null, rate: null);
  DateRead _invoiceDate = (date: null, problem: null);
  DateRead _dueDate = (date: null, problem: null);
  bool _invalid = false;

  /// Bumped when the due date is proposed, so its field shows it.
  int _dueProposed = 0;

  // The entries of the last attempt and the id they were sent under.
  PurchaseBillDraft? _attempted;
  String _requestId = newRequestId();

  /// #4065 — the focus of each field the summary names.
  final Map<String, FocusNode> _focus = {};

  FocusNode _nodeFor(String key) => _focus.putIfAbsent(key, FocusNode.new);

  @override
  void dispose() {
    for (final c in [_reference, _description, _gross, _tax]) {
      c.dispose();
    }
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  /// The bill's currency: the one picked for it, else the space's.
  String get _currency => _money.currency ?? appFormatOf(context).currencyCode;

  double? get _quantity =>
      parseDecimalInput(_item.quantity, grouping: false)?.toDouble();

  /// #4065 — the fields the bill is refused for, in the form's order: the
  /// summary names them, and nothing is saved while any remains.
  List<String> _problems() {
    final format = appFormatOf(context);
    final gross = format
        .readAmount(_gross.text, currency: _currency, allowNegative: false)
        .minor;
    final tax =
        format.readAmount(_tax.text, currency: _currency, allowNegative: false);
    final taxMinor = tax.minor;
    return [
      if (_invoiceDate.problem != null) 'invoiceDate',
      // Another currency than the space's is captured with its rate.
      if (_money.currency != null && _money.rate == null) 'fxRate',
      if (gross == null || gross <= 0) 'gross',
      if (tax.problem != null ||
          (taxMinor != null && gross != null && taxMinor > gross))
        'tax',
      if (_dueDate.problem != null) 'dueDate',
      // #3294 — an item is bought in a quantity above zero.
      if (_item.itemId != null && !((_quantity ?? 0) > 0)) 'quantity',
    ];
  }

  /// The label a problem is named by in the summary.
  String _problemLabel(AppLocalizations l10n, String key) => switch (key) {
    'invoiceDate' => l10n.purchasesInvoiceDate,
    'fxRate' => l10n.purchasesFxTitle,
    'gross' => l10n.purchasesGross,
    'tax' => l10n.purchasesTaxField,
    'dueDate' => l10n.purchasesDueDate,
    _ => l10n.purchasesQuantity,
  };

  PurchaseBillDraft? _draft() {
    if (_problems().isNotEmpty) return null;
    final format = appFormatOf(context);
    final gross = format
        .readAmount(_gross.text, currency: _currency, allowNegative: false)
        .minor!;
    final tax = format
        .readAmount(_tax.text, currency: _currency, allowNegative: false)
        .minor;
    final item = switch (_item.itemId) {
      final id? => PurchaseItem(
        serviceId: id,
        quantity: _quantity!,
        unit: _item.unit.trim(),
      ),
      null => null,
    };
    return PurchaseBillDraft(
      grossCents: gross,
      supplierId: _supplierId,
      reference: _reference.text.trim(),
      description: _description.text.trim(),
      originalDate: _invoiceDate.date,
      dueOn: _dueDate.date,
      taxCents: tax,
      recognitionKind: _purpose,
      place: _place,
      currency: _money.currency,
      exchangeRate: _money.rate,
      item: item,
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
        final id = await ref
            .read(purchaseCommandProvider)
            .saveBill(widget.workspaceId, _requestId, draft);
        if (id != null && _orderId != null) {
          await ref
              .read(purchaseOrderCommandsProvider)
              .linkBill(widget.workspaceId, id, _orderId);
        }
      },
    );
    if (ok && mounted) navigator.pop(true);
  }

  /// #3307 — takes the picked order's supplier and amounts; the bill's own
  /// figures stay editable, as the supplier wrote them.
  void _takeOrder(PurchaseOrder? order) {
    _orderId = order?.id;
    if (order == null) return;
    _gross.text = centsToMajor(order.totalCents);
    _tax.text = centsToMajor(order.vatCents);
    if (_description.text.trim().isEmpty) {
      _description.text = context.l10n.purchaseBillForOrder(order.reference);
    }
    _pickSupplier(order.supplierId);
  }

  void _pickSupplier(String? id) {
    setState(() => _supplierId = id);
    if (id != null) unawaited(_proposeDue(id));
  }

  /// #4518 -- the due date a supplier's agreed term gives; only where none was entered, and a failed read leaves the field as it was.
  Future<void> _proposeDue(String supplier) async {
    if (!MoneyViewData.gates(ref).supplierContactsOn || _dueDate.date != null) return;
    final DateTime? due;
    try {
      due = await SupplierOrderDefaults.dueOn(ref, widget.workspaceId, supplier, from: _invoiceDate.date);
    } on Object {
      return; // the person enters it as before
    }
    if (!mounted || due == null || _supplierId != supplier || _dueDate.date != null) return;
    setState(() {
      _dueDate = (date: due, problem: null);
      _dueProposed++;
    });
  }

  static bool _same(PurchaseBillDraft a, PurchaseBillDraft b) =>
      a.grossCents == b.grossCents &&
      a.taxCents == b.taxCents &&
      a.supplierId == b.supplierId &&
      a.reference == b.reference &&
      a.description == b.description &&
      a.originalDate == b.originalDate &&
      a.recognitionKind == b.recognitionKind &&
      a.place == b.place &&
      a.currency == b.currency &&
      a.exchangeRate == b.exchangeRate &&
      a.dueOn == b.dueOn &&
      a.item == b.item;

  // An order picked below sets the supplier: rebuilt with it.
  Widget _supplierField(AppLocalizations l10n, List<Supplier> suppliers) =>
    KeyedSubtree(
      key: ValueKey('purchase-supplier-of-${_supplierId ?? ''}'),
      child: DropdownButtonFormField<String?>(
        key: const ValueKey('purchase-supplier'),
        initialValue: _supplierId,
        // #4065 — as wide as its section; a long name is cut, not the field.
        isExpanded: true,
        decoration: InputDecoration(
          labelText: l10n.purchaseBillOptional(l10n.purchasesSupplier),
        ),
        items: [
          DropdownMenuItem<String?>(
            child: Text(l10n.purchasesNoSupplier),
          ),
          for (final s in suppliers)
            DropdownMenuItem<String?>(
              value: s.id,
              child: Text(
                '${s.number} · ${s.name}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: _pickSupplier,
      ),
    );

  /// #4065 — what is in error, at the top: each field named, a link to it.
  List<Widget> _summary(AppLocalizations l10n) {
    if (!_invalid) return const [];
    final problems = _problems();
    return [
      FormErrorSummary(
        count: problems.length,
        onGoToFirst: () => _nodeFor(problems.first).requestFocus(),
        problems: [
          for (final p in problems)
            (
              key: ValueKey('purchase-problem-$p'),
              label: _problemLabel(l10n, p),
              onGo: () => _nodeFor(p).requestFocus(),
            ),
        ],
      ),
      Text(
        l10n.purchasesInvalid,
        key: const ValueKey('purchase-invalid'),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ];
  }

  /// #4065 — what the bill is for and where its cost belongs.
  Widget _accounting(AppLocalizations l10n) => _section(l10n.purchaseBillSectionAccounting, [
    // #2576 — what it is for, in plain words; no tax class or
    // useful life is asked of whoever submits.
    DropdownButtonFormField<String>(
      key: const ValueKey('purchase-purpose'),
      initialValue: _purpose,
      isExpanded: true,
      decoration: InputDecoration(labelText: l10n.purchasesPurpose),
      items: [
        for (final p in purchasePurposes)
          DropdownMenuItem(value: p, child: Text(purchasePurposeLabel(l10n, p))),
      ],
      onChanged: (v) => _purpose = v ?? _purpose,
    ),
    // #2573 — where its cost belongs.
    PurchasePlaceField(
      fieldKey: 'purchase-place',
      workspaceId: widget.workspaceId,
      value: _place,
      onChanged: (p) => _place = p,
    ),
  ]);

  /// #4065 — one heading of the form and its fields, the kit's gap between.
  Widget _section(String title, List<Widget> fields) => FormSection(
    title: title,
    children: [
      for (final (i, field) in fields.indexed) ...[
        if (i > 0) const FormGap(),
        field,
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final suppliers = [
      for (final s
          in ref.watch(suppliersProvider(widget.workspaceId)).value ??
              const <Supplier>[])
        if (s.isActive) s,
    ];
    final optional = l10n.purchaseBillOptional;
    return TaskChoice(
      title: l10n.purchasesAddBill,
      content: FormErrorsScope(
        errors: const {},
        onEdit: (_) {},
        focusNodeFor: _nodeFor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ..._summary(l10n),
            _section(l10n.purchaseBillSectionSupplier, [
              _supplierField(l10n, suppliers),
              AppTextField(
                key: const ValueKey('purchase-reference'),
                controller: _reference,
                label: optional(l10n.purchasesReference),
                maxLength: 200,
              ),
              AppDateField(
                key: const ValueKey('purchase-invoice-date'),
                fieldKey: 'invoiceDate',
                label: optional(l10n.purchasesInvoiceDate),
                value: _invoiceDate.date,
                pickerHelpText: l10n.purchasesPickDate,
                showProblem: _invalid,
                textInputAction: TextInputAction.next,
                onChanged: (d) => _invoiceDate = d,
              ),
              PurchaseBillOrderField(
                workspaceId: widget.workspaceId,
                supplierId: _supplierId,
                orderId: _orderId,
                // recorder-key-exempt: a data callback; the dropdown is keyed.
                onChanged: _takeOrder,
              ),
            ]),
            _section(l10n.purchaseBillSectionAmount, [
              // A bill in another currency, with its rate (when switched on);
              // otherwise each amount names the space's currency.
              PurchaseCurrencyFields(
                // recorder-key-exempt: a data callback; the fields are keyed.
                onChanged: (m) => setState(() => _money = m),
              ),
              AppAmountField(
                key: const ValueKey('purchase-gross'),
                fieldKey: 'gross',
                controller: _gross,
                label: l10n.purchasesGross,
                currency: _currency,
                allowNegative: false,
                showProblem: _invalid,
                textInputAction: TextInputAction.next,
              ),
              AppAmountField(
                key: const ValueKey('purchase-tax'),
                fieldKey: 'tax',
                controller: _tax,
                label: optional(l10n.purchasesTaxField),
                helper: l10n.purchasesTaxFieldHelper,
                currency: _currency,
                allowNegative: false,
                showProblem: _invalid,
                textInputAction: TextInputAction.next,
              ),
            ]),
            _section(l10n.invoicePageMorePayment, [
              KeyedSubtree(
                key: ValueKey('purchase-due-proposed-$_dueProposed'),
                child: AppDateField(
                    key: const ValueKey('purchase-due-date'),
                    fieldKey: 'dueDate',
                    label: optional(l10n.purchasesDueDate),
                    value: _dueDate.date,
                    pickerHelpText: l10n.purchasesPickDate,
                    showProblem: _invalid,
                    onChanged: (d) => _dueDate = d,
                    onSubmitted: (_) => _save(),
                  ),
              ),
            ]),
            _accounting(l10n),
            _section(l10n.purchaseBillSectionDescription, [
              AppTextField(
                key: const ValueKey('purchase-description'),
                controller: _description,
                label: optional(l10n.purchasesDescription),
                maxLength: 500,
              ),
              // #3294 — the item the line bought, with the purchase figures on.
              PurchaseItemFields(
                workspaceId: widget.workspaceId,
                // recorder-key-exempt: a data callback; the fields are keyed.
                onChanged: (entry) => _item = entry,
              ),
            ]),
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
