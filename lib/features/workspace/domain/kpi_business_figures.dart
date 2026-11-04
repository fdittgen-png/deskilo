// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 — the figures of the business analytics, gathered for the KPI
// catalogue: who pays (0671), whom the space buys from (0673), what it
// sells (0674) and what its items earn (0675).
library;

import 'kpi_contract.dart';
import 'kpi_customers.dart';
import 'kpi_items.dart';
import 'kpi_sales.dart';
import 'kpi_vendors.dart';

/// The customer, vendor, sales and item figures, in catalogue order.
const businessFigureKpis = <KpiDefinition>[
  ...customerKpis,
  ...vendorKpis,
  ...salesKpis,
  ...itemKpis,
];
