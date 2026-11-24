// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4293 (G7, cut B) -- the home place of an item or a variant: one choice among the places of the
// business, or none. It is advice for put-away, counting and picking; saving it moves no stock.
import 'package:flutter/material.dart';

import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/dropdown_field.dart';
import '../../../core/ui/form_kit.dart';
import '../domain/stock_config.dart';
import '../domain/stock_registry.dart';
import 'stock_config_text.dart';

/// Opens the home-place choice of [row]; true when a home place was saved.
Future<bool> showStockHomeSheet(
  BuildContext context,
  StockRegistry registry, {
  required String workspaceId,
  required StockRegistryRow row,
  required List<StockPlaceConfig> places,
  required String separator,
}) {
  final l10n = context.l10n;
  final choices = [
    for (final p in places)
      if (p.isAddressable && p.active) p,
  ]..sort((a, b) => a.addressPath.compareTo(b.addressPath));
  var home = row.homeLocationId;
  final requestId = newRequestId();
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.stockRegistryHomeTitle(row.label),
      submitLabel: l10n.stockEditSave,
      submitKey: const ValueKey('stock-home-save'),
      onSubmit: () async {
        return guardSave(
          domain: 'stock',
          message: 'a home place was not saved',
          action: () async {
            await registry.setHome(
              workspaceId,
              itemId: row.itemId,
              variantId: row.variantId,
              placeId: home,
              requestId: requestId,
            );
          },
          problem: (e) => stockProblemText(l10n, e),
        );
      },
      builder: (context, refresh) => [
        Text(l10n.stockRegistryHomeHelp),
        const FormGap(),
        AppDropdownField<String?>(
          key: const ValueKey('stock-home-place'),
          label: l10n.stockRegistryHomePlace,
          value: home,
          items: [
            (null, l10n.stockRegistryHomeNone),
            for (final p in choices) (p.id, p.addressPath.split(stockAddressJoint).join(separator)),
          ],
          onChanged: (v) {
            home = v;
            refresh();
          },
        ),
      ],
    ),
  );
}
