// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The purchase side of the workspace data report: the space's purchase
// documents and suppliers as the report lists them, read only when the
// space keeps purchases.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../money/providers/purchase_providers.dart';
import '../../money/providers/supplier_providers.dart';
import '../domain/workspace_data_report.dart';
import '../domain/workspace_feature.dart';
import 'workspace_providers.dart';

/// The documents and suppliers of [workspaceId]; empty while the space
/// keeps no purchases.
Future<
  ({List<DataReportPurchase> purchases, List<DataReportSupplier> suppliers})
>
readDataReportPurchasing(WidgetRef ref, String workspaceId) async {
  if (!ref
      .read(enabledFeaturesSyncProvider)
      .contains(WorkspaceFeature.purchases)) {
    return (
      purchases: <DataReportPurchase>[],
      suppliers: <DataReportSupplier>[],
    );
  }
  final bought = await ref
      .read(purchaseRepositoryProvider)
      .fetchPurchases(workspaceId);
  final suppliers = await ref
      .read(supplierRepositoryProvider)
      .fetchSuppliers(workspaceId);
  return (
    purchases: <DataReportPurchase>[
      for (final p in bought)
        (
          date: p.originalDate ?? p.receivedOn,
          reference: p.reference,
          kind: p.kind.wire,
          state: p.state.name,
          category: p.category,
          grossCents: p.grossCents,
        ),
    ],
    suppliers: <DataReportSupplier>[
      for (final s in suppliers)
        (
          number: s.number,
          name: s.name,
          taxId: s.taxIdentifier.isEmpty ? s.taxIdEntered : s.taxIdentifier,
          city: s.city,
          country: s.countryCode,
          status: s.status.name,
        ),
    ],
  );
}
