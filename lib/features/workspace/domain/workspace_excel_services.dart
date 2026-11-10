// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3552 — the workbook's Service catalog sheet: each service with its price
// in the workspace's currency, and what it says about itself (category,
// duration, description, whether it is public, its order).
import 'package:deskilo_xlsx/deskilo_xlsx.dart';

import '../../money/domain/service_item.dart';

/// The Service catalog sheet of [services]; [major] writes a price.
XlsxSheet serviceCatalogSheet(
  List<ServiceItem> services, {
  required String currency,
  required XlsxAmount Function(int cents) major,
}) => XlsxSheet(
  name: 'Service catalog',
  rows: [
    [
      'id', 'name', 'price', 'currency', 'active', //
      'category', 'duration_minutes', 'description', 'is_public', 'sort_order',
    ],
    for (final s in services)
      [
        s.id, s.name, major(s.priceCents), currency, s.active, //
        if (s.category.isEmpty) null else s.category,
        s.durationMinutes,
        if (s.description.isEmpty) null else s.description,
        s.isPublic,
        s.sortOrder,
      ],
  ],
);
