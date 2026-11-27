// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4479 -- a goods line of a quote or an invoice is sold in any unit its item converts from (a carton of 12 where the item is counted in
// pieces), at THAT unit's price. The line starts in the item's sale unit and, while its price is empty or still the one filled in for the
// unit before, takes the price of the unit chosen. The server converts the quantity to the item's inventory unit when it issues (0942);
// the units offered and their prices are the stock's (wired by the composition root: the money feature never imports the stock).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/amount_input.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/dropdown_field.dart';
import '../../domain/line_unit.dart';
import '../../providers/money_providers.dart' show invoicingBusinessProvider;
import '../../providers/pickable_units_provider.dart';
import 'line_unit_text.dart';
import 'standalone_line_form.dart';

/// Makes the line of [form] sell [itemId] in [unit] (null: the item's sale unit): the unit becomes the one chosen, and the price the unit's
/// while the price is empty or still the one set before. [locale] is the member's number format.
Future<void> startGoodsLine(
  ProviderContainer container,
  String workspaceId,
  StandaloneLineForm form,
  String itemId, {
  String? unit,
  required String locale,
  required String Function(LineUnit unit) labelOf,
  required VoidCallback done,
}) async {
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

/// The unit of a goods line: the item's own while it offers no other, else the units it converts from.
class GoodsUnitField extends ConsumerWidget {
  const GoodsUnitField({super.key, required this.index, required this.workspaceId, required this.form, required this.enabled, required this.onChanged, required this.locale});

  final int index;
  final String workspaceId;
  final StandaloneLineForm form;
  final bool enabled;
  final VoidCallback onChanged;
  final String locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final goods = form.goodsUnit!;
    final item = form.itemId;
    final offered = item == null ? null : ref.watch(itemOrderUnitsProvider((workspaceId: workspaceId, itemId: item, supplierId: null))).value?.units;
    if (offered == null || offered.length < 2 || !offered.any((u) => u.code == goods.code)) {
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
      items: [for (final u in offered) (u.code, lineUnitName(l, code: u.code, label: u.label))],
      onChanged: enabled && item != null
          ? (v) {
              if (v == null) return;
              final container = ProviderScope.containerOf(context);
              unawaited(startGoodsLine(container, workspaceId, form, item, unit: v, locale: locale, labelOf: (u) => lineUnitName(l, code: u.code, label: u.label), done: onChanged));
            }
          : null,
    );
  }
}
