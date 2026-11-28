// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4165 (A2) -- one itemised line of the composer: the fields a person types
// and chooses. Quantities and prices stay text; the server reads them exactly.
// #4433 -- a line may sell an item kept in stock: it is then counted in the
// item's own unit and, for an item tracked piece by piece, names its pieces.
import 'dart:async';

import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/decimal_input.dart';
import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/invoice_goods.dart';
import '../../domain/invoice_services.dart';
import '../../domain/line_unit.dart';
import '../../domain/standalone_invoice.dart';
import '../../providers/money_providers.dart' show invoicingBusinessProvider;
import 'goods_unit_field.dart';
import 'line_unit_text.dart';

/// The units the composer offers, by the UN/ECE code the structured invoice
/// needs: the registry of billing units belongs to the goods work (#4169).
const List<({String code, String un})> standaloneUnits = [
  (code: 'hour', un: 'HUR'),
  (code: 'day', un: 'DAY'),
  (code: 'piece', un: 'C62'),
  (code: 'job', un: 'LS'),
];

String _unitLabel(BuildContext context, String code) {
  final l = context.l10n;
  return switch (code) {
    'day' => l.roomOfferUnitDay,
    'piece' => l.standaloneUnitPiece,
    'job' => l.standaloneUnitJob,
    _ => l.standaloneUnitHour,
  };
}

/// What a new line starts from: an hour of general supply at base quantity one. The one default both the form's fields
/// and the line it saves begin with.
const _newLine = StandaloneLine(description: '', quantity: '', unitCode: 'hour', unitLabel: '', unitPrice: '');

/// The state of one line: its controllers and choices, and its stable identity
/// once the server has given one.
class StandaloneLineForm {
  StandaloneLineForm({StandaloneLine? from})
    : _from = from,
      lineId = from?.lineId,
      unit = (from ?? _newLine).unitCode,
      gross = (from ?? _newLine).grossPrice,
      rateId = from?.vatRateId,
      itemId = from?.itemId,
      serviceId = from?.serviceId,
      serviceSupply = from?.serviceId == null ? null : from?.supply,
      goodsUnit = from != null && from.isGoods ? (code: from.unitCode, label: from.unitLabel, un: from.unEceCode) : null,
      description = TextEditingController(text: from?.description),
      quantityField = TextEditingController(text: from?.quantity),
      price = TextEditingController(text: from?.unitPrice),
      tags = TextEditingController(text: from?.pieceTags.join(', '));

  /// The line this form was opened with: what it does not edit (the supply kind, the base quantity) is kept as it was.
  final StandaloneLine? _from;

  /// #4442 -- the business's own units the line may also be sold in (kilometres, a drum of cable): set by the editor that shows them.
  List<LineUnit> offered = const [];

  /// The units the business adds to the four of the composer (a piece and an hour are already there).
  List<LineUnit> get extraUnits => [
    for (final u in offered)
      if (u.code != 'piece' && u.code != 'h') u,
  ];

  /// A unit the composer does not list, shown by the label it was stored with and saved unchanged; null when listed.
  ({String code, String label})? get unlistedUnit {
    final from = _from;
    if (from == null || standaloneUnits.any((u) => u.code == from.unitCode) || extraUnits.any((u) => u.code == from.unitCode)) return null;
    return (code: from.unitCode, label: from.unitLabel);
  }

  String? lineId;
  String unit;
  bool gross;
  String? rateId;

  /// #4510 -- the catalogue service the line was picked from, and what it then supplies; null for an ad-hoc line.
  String? serviceId;
  String? serviceSupply;

  /// The service picked on this line before: while the description still holds its name, picking another replaces it.
  String? pickedName;

  /// Fills the line in from [service] (or frees it, for none): its name when the description is empty or still the previous
  /// service's, its price as the gross price in [locale], its VAT rate and what it supplies. Every field stays editable and is
  /// what the line saves: the catalogue is read to fill the line in, never to compute it.
  void pick(InvoiceService? service, {required String priceText}) {
    final typed = description.text.trim();
    serviceId = service?.id;
    serviceSupply = service?.supply;
    if (service == null) {
      pickedName = null;
      return;
    }
    if (typed.isEmpty || typed == pickedName) description.text = service.name;
    pickedName = service.name;
    price.text = priceText;
    autoPrice = priceText;
    gross = true;
    rateId = service.vatRateId;
  }

  /// #4433 -- the stock item the line sells, and the unit it is then counted in (the item's own); null for a service.
  String? itemId;
  ({String code, String label, String un})? goodsUnit;
  final TextEditingController description;
  final TextEditingController quantityField;
  final TextEditingController price;

  /// #4479 -- the price this form filled in for the unit of the goods it sells: while the field still holds it, a new unit replaces it.
  String? autoPrice;

  /// The tags of the pieces sold, for an item tracked piece by piece.
  final TextEditingController tags;

  /// Makes the line sell [item] (or nothing from the stock): its unit becomes the item's, and an empty description
  /// takes the item's name. The unit is first the item's code alone; its label and UN/ECE code are the workspace unit's, set once the
  /// units of the business are read (`startGoodsLine`), never a table of this file.
  void sell(InvoiceGoodsItem? item) {
    itemId = item?.id;
    if (item != null) serviceId = null;
    goodsUnit = item == null ? null : (code: item.unit, label: item.unit, un: '');
    if (item != null && description.text.trim().isEmpty) description.text = item.name;
    if (item == null) tags.clear();
  }

  void dispose() {
    description.dispose();
    quantityField.dispose();
    price.dispose();
    tags.dispose();
  }

  StandaloneLine toLine(BuildContext context) {
    final locale = appFormatOf(context).locale;
    final from = _from;
    final listed = standaloneUnits.where((u) => u.code == unit);
    final own = extraUnits.where((u) => u.code == unit).firstOrNull;
    // The unit the line was opened with, if it is still the chosen one, is saved as it was stored (its label in the
    // language it was written in, its UN/ECE code): only a unit the person changes is read from the table.
    final keep = from != null && from.unitCode == unit;
    final base = from ?? _newLine;
    return base.copyWith(
      description: description.text.trim(),
      quantity: decimalTextFromInput(quantityField.text, locale: locale, grouping: false) ?? quantityField.text.trim(),
      unit: goodsUnit ??
          (
            code: unit,
            label: keep ? from.unitLabel : (own == null ? _unitLabel(context, unit) : lineUnitName(context.l10n, code: own.code, label: own.label)),
            un: keep ? from.unEceCode : (own?.unEceCode ?? (listed.isEmpty ? '' : listed.first.un)),
          ),
      unitPrice: decimalTextFromInput(price.text, locale: locale) ?? price.text.trim(),
      grossPrice: gross,
      vatRateId: () => rateId,
    ).withGoods((itemId: itemId, tags: itemId == null ? const <String>[] : pieceTagsOf(tags.text))).withService(serviceId, supply: serviceSupply).withLineId(lineId);
  }
}

/// Gives the forms the identities the server gave the lines it kept. The server answers the lines in the order they were
/// sent (the save functions return them by ordinality), so an answer that has as many lines as there are forms is attached
/// by position; any other answer is not guessed at, and the forms keep what they had. Returns whether it attached.
bool attachLineIds(List<StandaloneLineForm> forms, List<StandaloneLine> answered) {
  if (answered.length != forms.length) return false;
  for (final (i, line) in answered.indexed) {
    forms[i].lineId = line.lineId;
  }
  return true;
}

/// The editor of one line.
class StandaloneLineEditor extends StatelessWidget {
  const StandaloneLineEditor({
    super.key,
    required this.index,
    required this.form,
    required this.rates,
    required this.onChanged,
    required this.onRemove,
    this.enabled = true,
    this.goods = const [],
    this.services = const [],
    this.pieces = false,
    this.units = const [],
    this.workspaceId = '',
  });

  final int index;
  final StandaloneLineForm form;
  final List<VatRate> rates;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;
  final bool enabled;

  /// #4433 -- the items kept in stock a line may sell; none offers no choice.
  final List<InvoiceGoodsItem> goods;

  /// #4510 -- the services of the catalogue a line may be picked from; none offers no choice.
  final List<InvoiceService> services;

  /// Whether a line may name the pieces it sells (a standalone invoice; a quote names none).
  final bool pieces;

  /// #4442 -- the business's own units a free line may also be sold in; none while the feature is off.
  final List<LineUnit> units;

  /// The business the line is sold by (the units and prices of an item are its stock's).
  final String workspaceId;

  /// What the line is counted in: the item's own unit on a goods line, else the units to pick from.
  Widget _unitField(BuildContext context) {
    final l = context.l10n;
    return switch (form.goodsUnit) {
      _? => GoodsUnitField(key: ValueKey('standalone-line-$index-goods-unit-field'), index: index, workspaceId: workspaceId, form: form, enabled: enabled, onChanged: onChanged, locale: appFormatOf(context).locale),
      null => DropdownButtonFormField<String>(
        key: ValueKey('standalone-line-$index-unit'),
        initialValue: form.unit,
        decoration: InputDecoration(labelText: l.standaloneInvoiceLineUnit),
        items: [
          if (form.unlistedUnit case final u?) DropdownMenuItem(value: u.code, child: Text(u.label)),
          for (final u in standaloneUnits) DropdownMenuItem(value: u.code, child: Text(_unitLabel(context, u.code))),
          for (final u in form.extraUnits) DropdownMenuItem(value: u.code, child: Text(lineUnitName(l, code: u.code, label: u.label))),
        ],
        onChanged: enabled
            ? (v) {
                form.unit = v ?? form.unit;
                onChanged();
              }
            : null,
      ),
    };
  }

  /// #4510 -- the catalogue service the line is picked from: its name, price, rate and supply fill the line in; "no service" keeps an ad-hoc one.
  Widget _serviceField(BuildContext context) {
    final l = context.l10n;
    final held = form.serviceId;
    final known = services.any((s) => s.id == held);
    return DropdownButtonFormField<String?>(
      key: ValueKey('standalone-line-$index-service'),
      isExpanded: true,
      initialValue: held,
      decoration: InputDecoration(
        labelText: l.standaloneInvoiceLineService,
        suffixIcon: HelpDot(l.standaloneInvoiceLineService, anchor: HelpAnchor.moneyLineService),
      ),
      items: [
        DropdownMenuItem<String?>(child: Text(l.standaloneInvoiceLineNoService)),
        // a service that is retired since stays shown on the line that holds it
        if (held != null && !known) DropdownMenuItem<String?>(value: held, child: Text(form.description.text)),
        for (final s in services) DropdownMenuItem<String?>(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: enabled
          ? (v) {
              final picked = services.where((s) => s.id == v).firstOrNull;
              final locale = appFormatOf(context).locale;
              final text = picked == null
                  ? ''
                  : amountInputText(picked.priceCents, currency: ProviderScope.containerOf(context).read(invoicingBusinessProvider).currency, locale: locale);
              if (v == held) return;
              form.pick(picked, priceText: text);
              onChanged();
            }
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sold = goods.where((g) => g.id == form.itemId).firstOrNull;
    form.offered = units;
    return Card(
      key: ValueKey('standalone-line-$index'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              key: ValueKey('standalone-line-$index-description'),
              controller: form.description,
              label: l.standaloneInvoiceLineDescription,
              enabled: enabled,
              onChanged: (_) => onChanged(),
            ),
            if (goods.isNotEmpty || form.itemId != null) ...[
              const FormGap(),
              DropdownButtonFormField<String?>(
                key: ValueKey('standalone-line-$index-goods'),
                isExpanded: true,
                initialValue: form.itemId,
                decoration: InputDecoration(labelText: l.standaloneInvoiceLineGoods),
                items: [
                  DropdownMenuItem<String?>(child: Text(l.standaloneInvoiceLineNoGoods)),
                  if (form.itemId != null && sold == null)
                    DropdownMenuItem<String?>(value: form.itemId, child: Text(form.description.text)),
                  for (final g in goods)
                    DropdownMenuItem<String?>(value: g.id, child: Text(g.name, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: enabled
                    ? (v) {
                        form.sell(goods.where((g) => g.id == v).firstOrNull);
                        onChanged();
                        if (v != null) unawaited(startGoodsLine(ProviderScope.containerOf(context), form, v, (workspaceId: workspaceId, locale: appFormatOf(context).locale, labelOf: (u) => lineUnitName(l, code: u.code, label: u.label)), done: onChanged));
                      }
                    : null,
              ),
            ],
            if ((services.isNotEmpty || form.serviceId != null) && form.itemId == null) ...[
              const FormGap(),
              _serviceField(context),
            ],
            const FormGap(),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    key: ValueKey('standalone-line-$index-quantity'),
                    controller: form.quantityField,
                    label: l.standaloneInvoiceLineQuantity,
                    enabled: enabled,
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _unitField(context)),
              ],
            ),
            if (pieces && (sold?.byPiece ?? form.tags.text.isNotEmpty)) ...[
              const FormGap(),
              AppTextField(
                key: ValueKey('standalone-line-$index-pieces'),
                controller: form.tags,
                label: l.standaloneInvoiceLinePieces,
                helper: l.standaloneInvoiceLinePiecesHint,
                enabled: enabled,
                onChanged: (_) => onChanged(),
              ),
            ],
            const FormGap(),
            AppTextField(
              key: ValueKey('standalone-line-$index-price'),
              controller: form.price,
              label: l.standaloneInvoiceLinePrice,
              enabled: enabled,
              onChanged: (_) => onChanged(),
            ),
            SwitchListTile(
              key: ValueKey('standalone-line-$index-gross'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.standaloneInvoiceLineGross),
              value: form.gross,
              onChanged: enabled
                  ? (v) {
                      form.gross = v;
                      onChanged();
                    }
                  : null,
            ),
            if (rates.length > 1)
              DropdownButtonFormField<String?>(
                key: ValueKey('standalone-line-$index-rate'),
                isExpanded: true,
                initialValue: form.rateId,
                decoration: InputDecoration(labelText: l.standaloneInvoiceLineRate),
                items: [
                  DropdownMenuItem<String?>(
                    child: Text(l.standaloneInvoiceLineRateDefault),
                  ),
                  for (final r in rates)
                    DropdownMenuItem<String?>(value: r.id, child: Text(r.label)),
                ],
                onChanged: enabled
                    ? (v) {
                        form.rateId = v;
                        onChanged();
                      }
                    : null,
              ),
            if (onRemove != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: IconButton(
                  key: ValueKey('standalone-line-$index-remove'),
                  tooltip: l.standaloneInvoiceRemoveLine,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: enabled ? onRemove : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
