// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2495 — the owners of the sheets in core/navigation/feature_sheets.dart,
// composed here where every feature is visible: money, profile and the
// workspace's messenger open them without importing the calendar, money
// or members feature.
import 'package:flutter_riverpod/misc.dart' show Override;

import '../core/navigation/feature_sheets.dart'
    show FeatureSheet, featureSheetsProvider, memberProfileOpenerProvider;
import '../features/calendar/presentation/widgets/access_sheet.dart';
import '../features/events/providers/event_providers.dart';
import '../features/members/presentation/member_profile_link.dart';
import '../features/money/domain/line_unit.dart';
import '../features/money/presentation/purchase_order_stock_seam.dart';
import '../features/money/presentation/screens/tax_reference_screen.dart';
import '../features/money/providers/line_units_provider.dart';
import '../features/money/providers/pickable_units_provider.dart';
import '../features/stock/domain/unit_conversions.dart';
import '../features/stock/domain/workspace_units.dart';
import '../features/stock/presentation/purchase_order_stock_seam_impl.dart';
import '../features/stock/presentation/stock_event_names.dart';
import '../features/stock/providers/stock_providers.dart';
import '../features/stock/providers/workspace_units_providers.dart' as stock_units;
import '../features/workspace/domain/workspace_feature.dart';
import '../features/workspace/providers/workspace_providers.dart';
import 'stock_expiry_print.dart';
import 'stock_service_creator.dart';

/// Puts the openers in a scope's overrides (main.dart, the demonstration,
/// the widget tests' standard scope).
final List<Override> featureSheetsFromApp = [
  featureSheetsProvider.overrideWithValue({
    FeatureSheet.dataAccess: showAccessSheet,
    FeatureSheet.taxReferenceEditor: (context, ref) =>
        showTaxReferenceScreen(context, canEdit: true),
  }),
  memberProfileOpenerProvider.overrideWithValue(openMemberProfile),
  // #4171 — what the stock adds to the order pane (money never imports it).
  purchaseOrderStockSeamProvider.overrideWithValue(const StockPurchaseOrderSeam()),
  // #4350 — a new item is made as a service, by the money feature's command (the stock never imports it).
  stockServiceCreatorProvider.overrideWith(MoneyStockServiceCreator.new),
  // #4431 — the expiry report is printed by the report engine (the stock never imports it).
  stockExpiryPrinterProvider.overrideWithValue(const MoneyStockExpiryPrinter()),
  // #4442 — the units of the business a free line may be sold in (money never imports the stock).
  lineUnitsProvider.overrideWith(
    (ref, workspaceId) => [
      for (final u in ref.watch(stock_units.lineUnitsProvider(workspaceId)).value ?? const <WorkspaceUnit>[]) // empty-ok: the units only offer a choice
        LineUnit(code: u.code, label: u.label, unEceCode: u.unEceCode),
    ],
  ),
  // #4471 — the units a form picks from: the business's own, or the six of before (money never imports the stock).
  pickableUnitsProvider.overrideWith((ref, workspaceId) {
    final on = ref.watch(enabledFeaturesSyncProvider).contains(WorkspaceFeature.unitsOfMeasure);
    final all = ref.watch(stock_units.workspaceUnitListProvider(workspaceId)).value ?? builtInUnits;
    return [
      for (final u in pickableUnits(all, unitsOn: on)) LineUnit(code: u.code, label: u.label, unEceCode: u.unEceCode),
    ];
  }),
  // #4479 — an order line of a stocked item is in a unit that converts to its inventory unit (money never imports the stock).
  itemOrderUnitsProvider.overrideWith((ref, key) async {
    final config = await ref.watch(stockConfigCommandsProvider).item(key.workspaceId, key.itemId);
    if (config == null || !config.stockable) return null;
    final units = await ref.watch(stock_units.workspaceUnitListProvider(key.workspaceId).future);
    final general = await ref.watch(stock_units.unitConversionListProvider(key.workspaceId).future);
    final codes = convertibleUnitCodes(inventoryUnit: config.inventoryUnit, itemUnits: config.units, units: units, general: general);
    return [
      for (final u in units)
        if (codes.contains(u.code)) LineUnit(code: u.code, label: u.label, unEceCode: u.unEceCode),
    ];
  }),
  // #4294 — the names the low-stock notice of the inbox reads (events never import the stock).
  eventNameSourcesProvider.overrideWithValue(const [stockEventNames]),
];
