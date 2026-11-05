// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 steps 2-4 — the analytics modules of what the space buys, sells and
// keeps: the vendor figures (0673), the sales figures (0674) and the item
// figures (0675), split out of bi_modules.dart at its length budget.
library;

import 'bi_modules.dart';
import 'workspace_feature.dart';
import 'workspace_permission.dart';

/// The vendor, sales and item modules, in registry order.
const purchasingBiModules = <BiModule>[
  // #3294 step 2 — what the space buys and from whom, how punctually it
  // pays its suppliers and how late their bills reach it (0673); each
  // drills to the suppliers or the purchase documents behind it.
  BiModule(
    id: 'vendors.spend',
    area: BiArea.finance,
    feature: WorkspaceFeature.purchaseAnalytics,
    permissions: {
      WorkspacePermission.viewAnalytics,
      WorkspacePermission.viewFinances,
    },
    drill: _vendorSuppliers,
  ),
  BiModule(
    id: 'vendors.category_spend',
    area: BiArea.finance,
    feature: WorkspaceFeature.purchaseAnalytics,
    permissions: {
      WorkspacePermission.viewAnalytics,
      WorkspacePermission.viewFinances,
    },
    drill: _vendorPurchases,
  ),
  BiModule(
    id: 'vendors.payment_punctuality',
    area: BiArea.finance,
    feature: WorkspaceFeature.purchaseAnalytics,
    permissions: {
      WorkspacePermission.viewAnalytics,
      WorkspacePermission.viewFinances,
    },
    drill: _vendorPurchases,
  ),
  BiModule(
    id: 'vendors.billing_lag',
    area: BiArea.finance,
    feature: WorkspaceFeature.purchaseAnalytics,
    permissions: {
      WorkspacePermission.viewAnalytics,
      WorkspacePermission.viewFinances,
    },
    drill: _vendorSuppliers,
  ),
  // #3294 step 3 — what the space sells, by kind of line and by service,
  // and the margin each room it rents leaves (0674); each drills to the
  // invoices of its months.
  BiModule(
    id: 'sales.revenue_by_kind',
    area: BiArea.finance,
    feature: WorkspaceFeature.workspaceStatus,
    permissions: {
      WorkspacePermission.viewAnalytics,
      WorkspacePermission.viewFinances,
    },
    drill: _invoices,
  ),
  BiModule(
    id: 'sales.revenue_by_service',
    area: BiArea.finance,
    feature: WorkspaceFeature.workspaceStatus,
    permissions: {
      WorkspacePermission.viewAnalytics,
      WorkspacePermission.viewFinances,
    },
    drill: _invoices,
  ),
  BiModule(
    id: 'sales.room_margin',
    area: BiArea.finance,
    feature: WorkspaceFeature.workspaceStatus,
    alsoRequires: {WorkspaceFeature.externalRooms},
    permissions: {
      WorkspacePermission.viewAnalytics,
      WorkspacePermission.viewFinances,
    },
    drill: _invoices,
  ),
  // #3294 step 4 — what an item costs from each supplier, the margin each
  // product leaves and the margin each supplier's prices leave (0675).
  BiModule(
    id: 'items.unit_prices',
    area: BiArea.finance,
    feature: WorkspaceFeature.purchaseAnalytics,
    permissions: {
      WorkspacePermission.viewAnalytics,
      WorkspacePermission.viewFinances,
    },
    drill: _vendorPurchases,
  ),
  BiModule(
    id: 'items.product_margin',
    area: BiArea.finance,
    feature: WorkspaceFeature.purchaseAnalytics,
    permissions: {
      WorkspacePermission.viewAnalytics,
      WorkspacePermission.viewFinances,
    },
    drill: _invoices,
  ),
  BiModule(
    id: 'items.vendor_margin',
    area: BiArea.finance,
    feature: WorkspaceFeature.purchaseAnalytics,
    permissions: {
      WorkspacePermission.viewAnalytics,
      WorkspacePermission.viewFinances,
    },
    drill: _vendorSuppliers,
  ),
];

/// #3294 step 2 — the suppliers behind a vendor figure.
const _vendorSuppliers = BiDrill(
  route: '/money/suppliers',
  permission: WorkspacePermission.viewFinances,
);

/// #3294 step 2 — the purchase documents behind a vendor figure.
const _vendorPurchases = BiDrill(
  route: '/money/purchases',
  permission: WorkspacePermission.viewFinances,
);

/// #3294 — the invoices behind a sales or item figure, for its months.
const _invoices = BiDrill(
  route: '/invoice-register',
  permission: WorkspacePermission.viewFinances,
  carriesPeriod: true,
);
