// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — the purchase order form's state and fields: the supplier, the
// expected delivery, a note, where it is e-mailed, and its lines (a
// catalogue item or free text, the quantity, the unit, the unit price before
// VAT and the VAT rate). The draft is checked first
// (`PurchaseOrderDraft.problems`), each problem under its field; a retry of
// the same entries sends the same request id, so it never saves twice.
// #3608 — the order is a long task (purchase_order_page.dart); the summary
// beside its form follows what is typed ([PurchaseOrderForm.changes]).
import 'dart:async';

import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart' show VatRate;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/amount_input.dart';
import '../../../../core/format/decimal_input.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/line_unit.dart';
import '../../domain/purchase_order.dart';
import '../../domain/service_item.dart';
import '../../providers/money_providers.dart' show vatRatesProvider;
import '../../providers/pickable_units_provider.dart';
import 'master_data_pickers.dart';

/// The form's state: its controllers, the chosen supplier, date and items,
/// and the request id the current entries go under.
class PurchaseOrderForm {
  PurchaseOrderForm(this.order, this.items, this.currency, String locale, {required this.workspaceId})
    : supplierId = order?.supplierId,
      expectedOn = order?.expectedOn,
      lines = order == null ? 1 : order.lines.length,
      itemIds = [
        if (order == null) null,
        for (final l in order?.lines ?? const <PurchaseOrderLine>[])
          l.serviceId,
      ],
      vatPercents = [
        if (order == null) null,
        for (final l in order?.lines ?? const <PurchaseOrderLine>[])
          l.vatRatePercent,
      ],
      fields = FormControllers({
        'note': order?.note ?? '',
        'email': order?.recipientEmail ?? '',
        for (final (i, l)
            in (order?.lines ?? const <PurchaseOrderLine>[]).indexed) ...{
          'desc-$i': l.description,
          'qty-$i': _qtyText(l.quantity),
          'unit-$i': l.unit,
          'price-$i': amountInputText(
            l.unitPriceCents,
            currency: currency,
            locale: locale,
          ),
        },
      });

  final PurchaseOrder? order;
  final List<ServiceItem> items;

  /// The business whose units and VAT rates the lines are picked from (#4471).
  final String workspaceId;

  /// The order's currency (a new order's is the space's).
  final String currency;
  final FormControllers fields;
  String? supplierId;
  DateTime? expectedOn;
  DateInputProblem? expectedProblem;
  int lines;
  final List<String?> itemIds;

  /// The VAT percent of each line: none, or the percent of the rate that was picked (#4471).
  final List<double?> vatPercents;

  /// What the pickers offered the last time the form was drawn: a unit or a percent outside them cannot be saved (#4471).
  List<LineUnit> _unitsOffered = const [];
  List<VatRate>? _ratesOffered;

  /// The last check's problems, for the fields that are not text fields
  /// (the supplier picker reads its own here).
  FieldErrors shown = const {};

  /// Bumped when an entry that the summary shows changes: a quantity, a
  /// price, a rate, or the number of lines.
  final ValueNotifier<int> changes = ValueNotifier(0);
  final Set<TextEditingController> _watched = {};

  void _bump() => changes.value++;

  /// Watches the entries of every line the form shows, once each.
  void _watchLines() {
    for (var i = 0; i < lines; i++) {
      for (final k in const ['qty', 'price']) {
        final c = fields['$k-$i'];
        if (_watched.add(c)) c.addListener(_bump);
      }
    }
  }

  /// Disposes what the form holds; once, with the page.
  void dispose() {
    fields.dispose();
    changes.dispose();
  }

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
          unitPriceCents:
              readAmountInput(
                fields['price-$i'].text,
                locale: locale,
                currency: currency,
                allowNegative: false,
              ).minor ??
              -1,
          vatRatePercent: vatPercents[i],
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
    if (expectedProblem case final problem?) {
      out['expected'] = dateInputProblemText(l10n, problem);
    }
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
      } else if (_ratesOffered case final rates? when !vatPercentIsListed(rates, l.vatRatePercent)) {
        out['vat-$i'] = l10n.masterDataUnlisted;
      }
      if (!unitIsListed(_unitsOffered, l.unit)) out['unit-$i'] = l10n.masterDataUnlisted;
    }
    shown = out;
    return out;
  }

  /// What the order comes to as it is typed: the lines, the total before
  /// VAT, the VAT and the total. Beside the form on a wide page, after the
  /// fields on a narrow one.
  Widget summary(AppLocalizations l10n) => ValueListenableBuilder<int>(
    valueListenable: changes,
    builder: (context, _, _) {
      final format = appFormatOf(context);
      final money = format.moneyIn(currency);
      final d = draft(format.locale);
      final theme = Theme.of(context);
      Widget row(String label, int cents, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              money.formatMinor(cents),
              style: strong
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.bodyLarge,
            ),
          ],
        ),
      );
      return Column(
        key: const ValueKey('purchase-order-summary'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.purchaseOrderSummaryTitle,
            style: theme.textTheme.titleMedium,
          ),
          const FormGap.small(),
          Text(l10n.purchaseOrderSummaryLines(d.lines.length)),
          const FormGap.small(),
          row(l10n.purchaseOrderSummaryNet, d.netCents),
          row(l10n.purchaseOrderSummaryVat, d.vatCents),
          const Divider(),
          row(l10n.purchasesTotal, d.totalCents, strong: true),
        ],
      );
    },
  );

  List<Widget> build(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    List<Supplier> suppliers,
    VoidCallback refresh,
  ) {
    _watchLines();
    _unitsOffered = ref.watch(pickableUnitsProvider(workspaceId));
    _ratesOffered = switch (ref.watch(vatRatesProvider)) {
      AsyncData(:final value) => [
        for (final r in value) if (r.active) r,
      ],
      _ => null,
    };
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
      AppDateField(
        key: const ValueKey('purchase-order-expected'),
        fieldKey: 'expected',
        label: l10n.purchaseOrderExpected,
        value: expectedOn,
        first: DateTime(2000),
        last: DateTime(2100),
        pickerHelpText: l10n.purchaseOrderPickDate,
        onChanged: (read) {
          expectedOn = read.date;
          expectedProblem = read.problem;
        },
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
                vatPercents.add(null);
                _bump();
                refresh();
              },
        icon: const Icon(Icons.add),
        label: Text(l10n.purchaseOrderAddLine),
      ),
    ];
  }

  /// #4479 -- a line that names a stocked item starts in the unit the supplier sells it in, else its default purchase unit, else its own;
  /// a unit already chosen that the item converts from is kept.
  Future<void> _startUnit(BuildContext context, int i, String itemId, VoidCallback refresh) async {
    final container = ProviderScope.containerOf(context);
    final found = await container.read(itemOrderUnitsProvider((workspaceId: workspaceId, itemId: itemId, supplierId: supplierId)).future);
    final current = fields['unit-$i'].text;
    final start = found?.defaultUnit;
    if (itemIds[i] != itemId || start == null || (current.isNotEmpty && found!.units.any((u) => u.code == current))) return;
    fields['unit-$i'].text = start;
    refresh();
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
                for (final k in ['desc', 'qty', 'unit', 'price']) {
                  fields['$k-$j'].text = fields['$k-${j + 1}'].text;
                }
                itemIds[j] = itemIds[j + 1];
                vatPercents[j] = vatPercents[j + 1];
              }
              lines--;
              itemIds.removeLast();
              vatPercents.removeLast();
              _bump();
              refresh();
            },
          ),
      ],
    ),
    // #4078 — the label stands above its field, never against it.
    const FormGap.small(),
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
        if (v != null) unawaited(_startUnit(context, i, v, refresh));
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
    UnitPickerField(
      key: ValueKey('purchase-order-unit-$i'),
      workspaceId: workspaceId,
      itemId: itemIds[i],
      supplierId: supplierId,
      value: fields['unit-$i'].text,
      label: l10n.purchaseOrderUnit,
      errorText: shown['unit-$i'],
      onChanged: (code) {
        fields['unit-$i'].text = code;
        shown = {...shown}..remove('unit-$i');
        refresh();
      },
    ),
    AppAmountField(
      key: ValueKey('purchase-order-price-$i'),
      controller: fields['price-$i'],
      fieldKey: 'price-$i',
      label: l10n.purchaseOrderUnitPrice,
      currency: currency,
      allowNegative: false,
    ),
    VatPercentPicker(
      key: ValueKey('purchase-order-vat-$i'),
      value: vatPercents[i],
      label: l10n.purchaseOrderVatRate,
      onChanged: (percent) {
        vatPercents[i] = percent;
        _bump();
        refresh();
      },
    ),
  ];
}
