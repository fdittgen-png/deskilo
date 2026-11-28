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
import '../features/money/providers/lease_site_names_provider.dart';
import '../features/money/providers/line_units_provider.dart';
import '../features/money/providers/money_providers.dart' show servicesProvider;
import '../features/money/providers/pickable_units_provider.dart';
import '../features/stock/domain/stock_config.dart' show stockAddressJoint;
import '../features/stock/domain/unit_conversions.dart';
import '../features/stock/domain/workspace_units.dart';
import '../features/stock/presentation/purchase_order_stock_seam_impl.dart';
import '../features/stock/presentation/stock_event_names.dart';
import '../features/stock/providers/stock_providers.dart';
import '../features/stock/providers/workspace_units_providers.dart' as stock_units;
import '../features/workspace/domain/setting_place.dart';
import '../features/workspace/domain/site.dart';
import '../features/workspace/domain/workspace_feature.dart';
import '../features/workspace/providers/setting_places_provider.dart';
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
    final offered = [
      for (final u in units)
        if (codes.contains(u.code)) LineUnit(code: u.code, label: u.label, unEceCode: u.unEceCode),
    ];
    final supplied = key.supplierId == null
        ? null
        : (await ref.watch(stockConfigCommandsProvider).mappings(key.workspaceId))
              .where((m) => m.active && m.supplierId == key.supplierId && m.itemId == key.itemId && (m.purchaseUnit ?? '').isNotEmpty)
              .map((m) => m.purchaseUnit!)
              .firstOrNull;
    final own = config.units.where((u) => u.defaultPurchase).map((u) => u.unit).firstOrNull;
    final start = [supplied, own, config.inventoryUnit].firstWhere((c) => c != null && codes.contains(c), orElse: () => null);
    final sold = config.units.where((u) => u.defaultSale).map((u) => u.unit).firstOrNull;
    final sale = [sold, config.inventoryUnit].firstWhere((c) => c != null && codes.contains(c), orElse: () => null);
    return ItemOrderUnits(units: offered, defaultUnit: start, saleUnit: sale);
  }),
  // #4479 — the price of one unit of an item sold on a quote or an invoice: its own, else the item's price times its factor.
  itemUnitPriceProvider.overrideWith((ref, key) async {
    final config = await ref.watch(stockConfigCommandsProvider).item(key.workspaceId, key.itemId);
    final item = (await ref.watch(servicesProvider.future)).where((s) => s.id == key.itemId).firstOrNull;
    if (config == null || item == null) return null;
    final general = await ref.watch(stock_units.unitConversionListProvider(key.workspaceId).future);
    return unitPriceCents(
      itemPriceCents: item.priceCents,
      unit: key.unit,
      inventoryUnit: config.inventoryUnit,
      itemUnits: config.units,
      general: general,
    );
  }),
  // #4495 — the places a setting may name, each with its full path as site › place (the workspace feature never imports the stock).
  settingPlacesProvider.overrideWith((ref, workspaceId) async {
    final places = await ref.watch(stockConfigCommandsProvider).places(workspaceId);
    return [
      for (final p in places)
        if (p.active && p.isAddressable) SettingPlace(id: p.id, code: p.code, path: p.addressPath.split(stockAddressJoint).join(' › ')),
    ];
  }),
  // #4498 — the names of the sites, for a lease form (the money feature reads no more of the workspace than it has to).
  leaseSiteNamesProvider.overrideWith((ref) => {for (final s in ref.watch(sitesProvider).value ?? const <Site>[]) s.id: s.name}),
  // #4294 — the names the low-stock notice of the inbox reads (events never import the stock).
  eventNameSourcesProvider.overrideWithValue(const [stockEventNames]),
];
