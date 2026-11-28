// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4485 — the kinds of master data a business keeps, as one registry: every
// list a picker reads or the business configures has a card on the Master
// data page (/settings/master-data), and its editor is reached from there
// (docs/AGENT_RULES.md "Master data lives on the Master data page"). A kind
// names the existing screen that edits it and the features that screen's
// route asks; the permission is the one the route table asks
// (route_access.dart), so a card is shown exactly to whom its screen opens.
import 'package:flutter/material.dart';

import '../../core/help/help_anchors.dart';
import '../../core/navigation/routes.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import '../../l10n/app_localizations.dart';
import '../route_access.dart';

/// The groups of the page, in the order it shows them.
enum MasterDataGroup {
  measures,
  catalogue,
  placesAndStock,
  partners,
  organisation;

  /// The group's title.
  String title(AppLocalizations l10n) => switch (this) {
    measures => l10n.masterDataGroupMeasures,
    catalogue => l10n.masterDataGroupCatalogue,
    placesAndStock => l10n.masterDataGroupPlaces,
    partners => l10n.masterDataGroupPartners,
    organisation => l10n.organisationTitle,
  };

  /// The guide section the group's help symbol opens.
  String get anchor => switch (this) {
    measures => HelpAnchor.masterDataMeasures,
    catalogue => HelpAnchor.masterDataCatalogue,
    placesAndStock => HelpAnchor.masterDataPlaces,
    partners => HelpAnchor.masterDataPartners,
    organisation => HelpAnchor.masterDataOrganisation,
  };
}

/// One kind of master data: its group, the screen that edits it and the
/// features that screen's route asks. In the order the page shows them.
enum MasterDataKind {
  // #4485 — the units are always reachable: the pickers read them whether
  // or not the units feature is on (it governs the advanced uses only).
  units(MasterDataGroup.measures, Routes.settingsUnits, Icons.straighten, []),
  vatRates(MasterDataGroup.measures, Routes.vat, Icons.percent_outlined, [
    WorkspaceFeature.vatManagement,
  ]),
  items(MasterDataGroup.catalogue, Routes.stockItems, Icons.category_outlined, [
    WorkspaceFeature.stockManagement,
  ]),
  itemGroups(
    MasterDataGroup.catalogue,
    Routes.stockGroups,
    Icons.folder_copy_outlined,
    [WorkspaceFeature.stockManagement, WorkspaceFeature.stockItemGroups],
  ),
  services(
    MasterDataGroup.catalogue,
    Routes.services,
    Icons.room_service_outlined,
    [WorkspaceFeature.services],
  ),
  places(
    MasterDataGroup.placesAndStock,
    Routes.stockPlaces,
    Icons.place_outlined,
    [WorkspaceFeature.stockManagement],
  ),
  // the till drawer adds and edits the tills and opens each till's layout
  tills(
    MasterDataGroup.placesAndStock,
    Routes.tillDrawer,
    Icons.point_of_sale_outlined,
    [WorkspaceFeature.counterTillSessions],
  ),
  // #4514 — the reasons of cash in and out and of a count's difference
  cashReasons(
    MasterDataGroup.placesAndStock,
    Routes.tillCashReasons,
    Icons.label_outline,
    [WorkspaceFeature.counterTillSessions, WorkspaceFeature.counterCashReasons],
  ),
  // #4466 — the till boards: one connected by its QR code or its typed code
  devices(
    MasterDataGroup.placesAndStock,
    Routes.settingsDevices,
    Icons.developer_board_outlined,
    [WorkspaceFeature.counterEmbeddedTerminal],
  ),
  suppliers(
    MasterDataGroup.partners,
    Routes.moneySuppliers,
    Icons.storefront_outlined,
    [WorkspaceFeature.supplyExpenses],
  ),
  customers(
    MasterDataGroup.partners,
    Routes.moneyCustomers,
    Icons.people_outline,
    [WorkspaceFeature.billingCustomers],
  ),
  bankAccounts(
    MasterDataGroup.organisation,
    Routes.moneyBankAccounts,
    Icons.account_balance_outlined,
    [WorkspaceFeature.bankImport],
  ),
  sites(
    MasterDataGroup.organisation,
    Routes.settingsSites,
    Icons.business_outlined,
    [WorkspaceFeature.multiSite],
  );

  const MasterDataKind(this.group, this.route, this.icon, this.features);

  final MasterDataGroup group;

  /// The existing screen that edits this kind.
  final String route;
  final IconData icon;

  /// Every feature the route's guard asks.
  final List<WorkspaceFeature> features;

  /// The kind's name, as its screen is titled.
  String title(AppLocalizations l10n) => switch (this) {
    units => l10n.featureUnitsOfMeasureTitle,
    vatRates => l10n.vatRatesTile,
    items => l10n.stockItemsTitle,
    itemGroups => l10n.itemGroupsTitle,
    services => l10n.servicesTitle,
    places => l10n.stockPlacesTitle,
    tills => l10n.masterDataTills,
    cashReasons => l10n.cashReasonsTitle,
    devices => l10n.devicePairingTitle,
    suppliers => l10n.bookRoleSuppliers,
    customers => l10n.billingCustomersTitle,
    bankAccounts => l10n.bankAccountsTitle,
    sites => l10n.featureMultiSite,
  };

  /// One line of what the kind is.
  String description(AppLocalizations l10n) => switch (this) {
    units => l10n.measureUnitsSubtitle,
    vatRates => l10n.masterDataVatDesc,
    items => l10n.masterDataItemsDesc,
    itemGroups => l10n.masterDataItemGroupsDesc,
    services => l10n.masterDataServicesDesc,
    places => l10n.masterDataPlacesDesc,
    tills => l10n.masterDataTillsDesc,
    cashReasons => l10n.cashReasonsSubtitle,
    devices => l10n.devicePairingSubtitle,
    suppliers => l10n.masterDataSuppliersDesc,
    customers => l10n.masterDataCustomersDesc,
    bankAccounts => l10n.bankAccountsSubtitle,
    sites => l10n.masterDataSitesDesc,
  };

  /// Whether this kind's screen opens for someone holding [held] where
  /// [featureOn] answers the business's features: what its route asks.
  bool opensFor(
    bool Function(WorkspaceFeature) featureOn,
    Set<WorkspacePermission> held,
  ) => features.every(featureOn) && mayOpen(route, held);
}

/// The kinds whose screens open for this person in this business, in order.
List<MasterDataKind> masterDataKindsFor(
  bool Function(WorkspaceFeature) featureOn,
  Set<WorkspacePermission> held,
) => [
  for (final k in MasterDataKind.values)
    if (k.opensFor(featureOn, held)) k,
];
