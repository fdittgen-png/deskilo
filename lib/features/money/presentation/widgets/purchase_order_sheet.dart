// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — the purchase order form: the supplier, the expected delivery, a
// note, where it is e-mailed, and its lines (a catalogue item or free text,
// the quantity, the unit, the unit price before VAT and the VAT rate). The
// draft is checked first (`PurchaseOrderDraft.problems`), each problem
// under its field; the server decides the rest, and a refusal keeps the
// sheet open with every entry. A retry of the same entries sends the same
// request id, so it never saves twice.
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/format/decimal_input.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/purchase_order_commands.dart';
import '../../domain/purchase_order.dart';
import '../../domain/service_item.dart';
import '../../providers/money_providers.dart';
import '../../providers/supplier_providers.dart';

/// The purchase order form, opened from the orders screen.
class PurchaseOrderSheet {
  const PurchaseOrderSheet(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  /// Opens the form for a new order, or for the draft [order]. True once
  /// the server has it.
  Future<bool> open({required String workspaceId, PurchaseOrder? order}) async {
    final l10n = context.l10n;
    final suppliers = [
      for (final s in await ref.read(suppliersProvider(workspaceId).future))
        if (s.isActive) s,
    ];
    final items = await ref.read(servicesProvider.future);
    if (!context.mounted) return false;
    final form = _OrderForm(order, items);
    return showAppFormSheet(
      context,
      AppFormSheet(
        title: order == null ? l10n.purchaseOrderNew : l10n.purchaseOrderEdit,
        submitLabel: l10n.purchaseOrderSave,
        submitKey: const ValueKey('purchase-order-save'),
        onDispose: form.fields.dispose,
        validate: () => form.errors(l10n, appFormatOf(context).locale),
        onSubmit: () async {
          final draft = form.draft(appFormatOf(context).locale);
          final requestId = form.requestFor(draft);
          final ok = await runGuarded(
            context,
            domain: 'money',
            message: 'purchase order save failed',
            errorText: l10n.purchaseOrderRefused,
            action: () async {
              await ref
                  .read(purchaseOrderCommandsProvider)
                  .save(workspaceId, requestId, draft);
            },
          );
          return ok ? null : l10n.purchaseOrderRefused;
        },
        builder: (context, refresh) =>
            form.build(context, ref, l10n, suppliers, refresh),
      ),
    );
  }
}

/// The form's state: its controllers, the chosen supplier, date and items,
/// and the request id the current entries go under.
class _OrderForm {
  _OrderForm(this.order, this.items)
    : supplierId = order?.supplierId,
      expectedOn = order?.expectedOn,
      lines = order == null ? 1 : order.lines.length,
      itemIds = [
        if (order == null) null,
        for (final l in order?.lines ?? const <PurchaseOrderLine>[])
          l.serviceId,
      ],
      fields = FormControllers({
        'note': order?.note ?? '',
        'email': order?.recipientEmail ?? '',
        for (final (i, l)
            in (order?.lines ?? const <PurchaseOrderLine>[]).indexed) ...{
          'desc-$i': l.description,
          'qty-$i': _qtyText(l.quantity),
          'unit-$i': l.unit,
          'price-$i': centsToMajor(l.unitPriceCents),
          'vat-$i': l.vatRatePercent == null ? '' : _qtyText(l.vatRatePercent!),
        },
      });

  final PurchaseOrder? order;
  final List<ServiceItem> items;
  final FormControllers fields;
  String? supplierId;
  DateTime? expectedOn;
  int lines;
  final List<String?> itemIds;

  /// The last check's problems, for the fields that are not text fields
  /// (the supplier picker reads its own here).
  FieldErrors shown = const {};

  PurchaseOrderDraft? _attempted;
  String _requestId = newRequestId();

  static String _qtyText(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  static double? _number(String text) =>
      parseDecimalInput(text, grouping: false)?.toDouble();

  PurchaseOrderDraft draft(String locale) => PurchaseOrderDraft(
    orderId: order?.id,
    expectedRevision: order?.revision ?? 0,
    supplierId: supplierId,
    expectedOn: expectedOn,
    note: fields.values['note'] ?? '',
    recipientEmail: fields.values['email'] ?? '',
    lines: [
      for (var i = 0; i < lines; i++)
        PurchaseOrderLineDraft(
          serviceId: itemIds[i],
          description: fields['desc-$i'].text,
          quantity: _number(fields['qty-$i'].text) ?? 0,
          unit: fields['unit-$i'].text,
          unitPriceCents: parseMinorInput(fields['price-$i'].text, locale: locale) ?? -1,
          vatRatePercent: fields['vat-$i'].text.trim().isEmpty
              ? null
              : (_number(fields['vat-$i'].text) ?? -1),
        ),
    ],
  );

  /// Same entries: same id (a lost answer is replayed, not doubled).
  String requestFor(PurchaseOrderDraft d) {
    final key = d.toPayload().toString();
    if (_attempted == null || _attempted!.toPayload().toString() != key) {
      _requestId = newRequestId();
    }
    _attempted = d;
    return _requestId;
  }

  /// Each problem of the draft under its field.
  FieldErrors errors(AppLocalizations l10n, String locale) {
    final d = draft(locale);
    final out = <String, String>{};
    if (d.problems.contains(PurchaseOrderProblem.noSupplier)) {
      out['supplier'] = l10n.purchaseOrderNeedsSupplier;
    }
    if (d.problems.contains(PurchaseOrderProblem.recipientEmail)) {
      out['email'] = l10n.purchaseOrderBadEmail;
    }
    for (final (i, l) in d.lines.indexed) {
      final one = PurchaseOrderDraft(supplierId: 'x', lines: [l]).problems;
      if (one.contains(PurchaseOrderProblem.lineDescription)) {
        out['desc-$i'] = l10n.purchaseOrderNeedsDescription;
      }
      if (one.contains(PurchaseOrderProblem.lineQuantity)) {
        out['qty-$i'] = l10n.purchaseOrderNeedsQuantity;
      }
      if (one.contains(PurchaseOrderProblem.linePrice)) {
        out['price-$i'] = l10n.purchaseOrderNeedsPrice;
      }
      if (one.contains(PurchaseOrderProblem.lineVatRate)) {
        out['vat-$i'] = l10n.purchaseOrderBadVatRate;
      }
    }
    shown = out;
    return out;
  }

  List<Widget> build(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    List<Supplier> suppliers,
    VoidCallback refresh,
  ) {
    final material = MaterialLocalizations.of(context);
    return [
      DropdownButtonFormField<String?>(
        key: const ValueKey('purchase-order-supplier'),
        initialValue: supplierId,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: l10n.purchaseOrderSupplier,
          errorText: supplierId == null ? shown['supplier'] : null,
        ),
        items: [
          for (final s in suppliers)
            DropdownMenuItem<String?>(
              value: s.id,
              child: Text('${s.number} · ${s.name}'),
            ),
        ],
        onChanged: (v) {
          supplierId = v;
          refresh();
        },
      ),
      const FormGap(),
      OutlinedButton(
        key: const ValueKey('purchase-order-expected'),
        onPressed: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: expectedOn ?? ref.read(clockProvider).now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            helpText: l10n.purchaseOrderPickDate,
          );
          if (picked != null) {
            expectedOn = picked;
            refresh();
          }
        },
        child: Text(
          expectedOn == null
              ? l10n.purchaseOrderExpected
              : '${l10n.purchaseOrderExpected}: '
                    '${material.formatMediumDate(expectedOn!)}',
        ),
      ),
      const FormGap(),
      AppTextField(
        key: const ValueKey('purchase-order-email'),
        controller: fields['email'],
        fieldKey: 'email',
        label: l10n.purchaseOrderEmail,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        maxLength: 254,
      ),
      AppTextField(
        key: const ValueKey('purchase-order-note'),
        controller: fields['note'],
        label: l10n.purchaseOrderNote,
        maxLength: 1000,
      ),
      for (var i = 0; i < lines; i++) ..._line(context, l10n, i, refresh),
      const FormGap(),
      TextButton.icon(
        key: const ValueKey('purchase-order-add-line'),
        onPressed: lines >= 200
            ? null
            : () {
                lines++;
                itemIds.add(null);
                refresh();
              },
        icon: const Icon(Icons.add),
        label: Text(l10n.purchaseOrderAddLine),
      ),
    ];
  }

  List<Widget> _line(
    BuildContext context,
    AppLocalizations l10n,
    int i,
    VoidCallback refresh,
  ) => [
    const FormGap.large(),
    Row(
      children: [
        Expanded(
          child: Text(
            l10n.purchaseOrderLine('${i + 1}'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        if (lines > 1)
          IconButton(
            key: ValueKey('purchase-order-remove-$i'),
            tooltip: l10n.purchaseOrderRemoveLine,
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              // Shift the later lines up, then drop the last one.
              for (var j = i; j < lines - 1; j++) {
                for (final k in ['desc', 'qty', 'unit', 'price', 'vat']) {
                  fields['$k-$j'].text = fields['$k-${j + 1}'].text;
                }
                itemIds[j] = itemIds[j + 1];
              }
              lines--;
              itemIds.removeLast();
              refresh();
            },
          ),
      ],
    ),
    DropdownButtonFormField<String?>(
      key: ValueKey('purchase-order-item-$i'),
      initialValue: itemIds[i],
      isExpanded: true,
      decoration: InputDecoration(labelText: l10n.purchaseOrderItem),
      items: [
        DropdownMenuItem<String?>(child: Text(l10n.purchaseOrderFreeText)),
        for (final item in items)
          DropdownMenuItem<String?>(value: item.id, child: Text(item.name)),
      ],
      onChanged: (v) {
        itemIds[i] = v;
        refresh();
      },
    ),
    AppTextField(
      key: ValueKey('purchase-order-desc-$i'),
      controller: fields['desc-$i'],
      fieldKey: 'desc-$i',
      label: l10n.purchaseOrderDescription,
      maxLength: 500,
    ),
    AppTextField(
      key: ValueKey('purchase-order-qty-$i'),
      controller: fields['qty-$i'],
      fieldKey: 'qty-$i',
      label: l10n.purchasesQuantity,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    ),
    AppTextField(
      key: ValueKey('purchase-order-unit-$i'),
      controller: fields['unit-$i'],
      label: l10n.purchaseOrderUnit,
      maxLength: 20,
    ),
    AppTextField(
      key: ValueKey('purchase-order-price-$i'),
      controller: fields['price-$i'],
      fieldKey: 'price-$i',
      label: l10n.purchaseOrderUnitPrice,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    ),
    AppTextField(
      key: ValueKey('purchase-order-vat-$i'),
      controller: fields['vat-$i'],
      fieldKey: 'vat-$i',
      label: l10n.purchaseOrderVatRate,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    ),
  ];
}
