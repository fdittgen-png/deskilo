// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4516 -- the unit is always a picker over the business's units: the ones the item converts from first, then the others (picking one asks
// "1 box = [n] pieces" and saves it as the item's conversion), then "New unit…" (the Master data units editor, and back to the draft).
// #4479 -- a goods line of a quote or an invoice is sold in any unit its item converts from (a carton of 12 where the item is counted in
// pieces), at THAT unit's price. The line starts in the item's sale unit and, while its price is empty or still the one filled in for the
// unit before, takes the price of the unit chosen. The server converts the quantity to the item's inventory unit when it issues (0942);
// the units offered and their prices are the stock's (wired by the composition root: the money feature never imports the stock).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/amount_input.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/dropdown_field.dart';
import '../../domain/line_unit.dart';
import '../../providers/money_providers.dart' show invoicingBusinessProvider;
import '../../providers/pickable_units_provider.dart';
import 'goods_conversion_dialog.dart';
import 'line_unit_text.dart';
import 'standalone_line_form.dart';

/// What a goods line needs to word its unit and its price: the business, the member's number format and how a unit is named.
typedef GoodsLineWords = ({String workspaceId, String locale, String Function(LineUnit unit) labelOf});

/// Makes the line of [form] sell [itemId] in [unit] (null: the item's sale unit): the unit becomes the one chosen, and the price the unit's
/// while the price is empty or still the one set before. [locale] is the member's number format.
Future<void> startGoodsLine(
  ProviderContainer container,
  StandaloneLineForm form,
  String itemId,
  GoodsLineWords words, {
  String? unit,
  required VoidCallback done,
}) async {
  final (:workspaceId, :locale, :labelOf) = words;
  final units = await container.read(itemOrderUnitsProvider((workspaceId: workspaceId, itemId: itemId, supplierId: null)).future);
  if (form.itemId != itemId) return;
  final chosen = unit ?? units?.saleUnit;
  if (units != null && chosen != null) {
    final u = units.units.where((x) => x.code == chosen).firstOrNull;
    // the label and the UN/ECE code of the unit are the workspace unit's own (its master data)
    if (u != null) form.goodsUnit = (code: u.code, label: labelOf(u), un: u.unEceCode ?? '');
  }
  final code = form.goodsUnit?.code;
  if (code == null) {
    done();
    return;
  }
  final cents = await container.read(itemUnitPriceProvider((workspaceId: workspaceId, itemId: itemId, unit: code)).future);
  if (form.itemId != itemId || form.goodsUnit?.code != code) return;
  final typed = form.price.text.trim();
  if (cents != null && (typed.isEmpty || typed == form.autoPrice)) {
    final text = amountInputText(cents, currency: container.read(invoicingBusinessProvider).currency, locale: locale);
    form.price.text = text;
    form.autoPrice = text;
  }
  done();
}

/// What the picker answers for the entry that opens the units editor.
const _newUnit = '#new-unit';

/// The unit of a goods line: a picker over the business's units, the ones the item converts from first.
class GoodsUnitField extends ConsumerWidget {
  const GoodsUnitField({super.key, required this.index, required this.workspaceId, required this.form, required this.enabled, required this.onChanged, required this.locale});

  final int index;
  final String workspaceId;
  final StandaloneLineForm form;
  final bool enabled;
  final VoidCallback onChanged;
  final String locale;

  /// The unit [code] by the name the business gave it.
  String _name(BuildContext context, List<LineUnit> all, String code) {
    final u = all.where((x) => x.code == code).firstOrNull;
    return lineUnitName(context.l10n, code: code, label: u?.label);
  }

  /// Opens the units editor and, back on the draft, reads the units again.
  Future<void> _addUnit(BuildContext context, WidgetRef ref, Future<void> Function(BuildContext, String) open, String item) async {
    await open(context, workspaceId);
    ref
      ..invalidate(pickableUnitsProvider(workspaceId))
      ..invalidate(itemOrderUnitsProvider((workspaceId: workspaceId, itemId: item, supplierId: null)));
  }

  /// Asks how many of the item's own unit one [unit] holds, saves it as the item's conversion, and gives the line the unit.
  Future<void> _define(BuildContext context, WidgetRef ref, ItemConversionSaver save, List<LineUnit> all, String item, String base, String unit) async {
    final l = context.l10n;
    final container = ProviderScope.containerOf(context);
    final read = await askConversion(context, unit: _name(context, all, unit), base: _name(context, all, base));
    if (read == null || !context.mounted) return;
    var saved = false;
    final problem = await guardSave(
      domain: 'money',
      message: 'save item conversion failed',
      action: () async => saved = await save(workspaceId: workspaceId, itemId: item, unit: unit, factorNum: read.num, factorDen: read.den),
      problem: (_) => l.standaloneInvoiceLineConversionFailed,
    );
    if (!context.mounted) return;
    if (problem != null || !saved) {
      AppSnack.error(context, problem ?? l.standaloneInvoiceLineConversionFailed);
      return;
    }
    ref.invalidate(itemOrderUnitsProvider((workspaceId: workspaceId, itemId: item, supplierId: null)));
    final words = (workspaceId: workspaceId, locale: locale, labelOf: (LineUnit u) => lineUnitName(l, code: u.code, label: u.label));
    unawaited(startGoodsLine(container, form, item, words, unit: unit, done: onChanged));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final goods = form.goodsUnit!;
    final item = form.itemId;
    final order = item == null ? null : ref.watch(itemOrderUnitsProvider((workspaceId: workspaceId, itemId: item, supplierId: null))).value;
    final converts = order?.units;
    final all = ref.watch(pickableUnitsProvider(workspaceId));
    final save = ref.watch(itemConversionSaverProvider);
    final open = ref.watch(newUnitOpenerProvider);
    final base = order?.inventoryUnit;
    final convertCodes = {for (final u in converts ?? const <LineUnit>[]) u.code};
    // a unit the item cannot convert to is offered only where the conversion can be written and its base is known
    final others = save == null || base == null || converts == null
        ? const <LineUnit>[]
        : [
            for (final u in all)
              if (!convertCodes.contains(u.code)) u,
          ];
    if (converts == null || !convertCodes.contains(goods.code) || (converts.length < 2 && others.isEmpty && open == null)) {
      return InputDecorator(
        key: ValueKey('standalone-line-$index-goods-unit'),
        decoration: InputDecoration(labelText: l.standaloneInvoiceLineUnit, enabled: false),
        child: Text(goods.label),
      );
    }
    return AppDropdownField<String>(
      key: ValueKey('standalone-line-$index-goods-unit-pick'),
      label: l.standaloneInvoiceLineUnit,
      value: goods.code,
      items: [
        for (final u in converts) (u.code, lineUnitName(l, code: u.code, label: u.label)),
        for (final u in others) (u.code, l.standaloneInvoiceLineUnitDefine(lineUnitName(l, code: u.code, label: u.label))),
        if (open != null) (_newUnit, l.standaloneInvoiceLineNewUnit),
      ],
      onChanged: enabled && item != null
          ? (v) {
              if (v == null || v == goods.code) return;
              if (v == _newUnit) {
                if (open != null) unawaited(_addUnit(context, ref, open, item));
              } else if (convertCodes.contains(v)) {
                final container = ProviderScope.containerOf(context);
                unawaited(startGoodsLine(container, form, item, (workspaceId: workspaceId, locale: locale, labelOf: (u) => lineUnitName(l, code: u.code, label: u.label)), unit: v, done: onChanged));
              } else if (save != null && base != null) {
                unawaited(_define(context, ref, save, all, item, base, v));
              }
            }
          : null,
    );
  }
}
