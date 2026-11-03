// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:deskilo/features/money/providers/company_lookup_providers.dart';
import 'package:deskilo/features/money/providers/purchase_approval_provider.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/money/providers/supplier_balance_provider.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/features/workspace/providers/settings_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'data/company_lookup_repository.dart';
import 'data/purchase_approval_reads.dart';
import 'data/supplier_balance_repository.dart';
import 'seed/demo_london_seed.dart';
import 'seed/demo_new_york_seed.dart';
import 'seed/demo_purchase_seed.dart';

/// Keep the supplier and purchase readers inside the same Demo fixture.
List<Override> demoPurchasingOverrides(
  DemoPurchasing purchasing, {
  DemoPurchasing? london,
  DemoPurchasing? newYork,
}) => [
  supplierRepositoryProvider.overrideWith(
    (ref) => switch (ref.watch(currentWorkspaceProvider).value?.id) {
      demoLondonSpaceId => (london ?? purchasing).suppliers,
      demoNewYorkSpaceId => (newYork ?? purchasing).suppliers,
      _ => purchasing.suppliers,
    },
  ),
  companyLookupRepositoryProvider.overrideWithValue(
    FakeCompanyLookupRepository(),
  ),
  purchaseRepositoryProvider.overrideWith((ref) {
    final current = switch (ref.watch(currentWorkspaceProvider).value?.id) {
      demoLondonSpaceId => london ?? purchasing,
      demoNewYorkSpaceId => newYork ?? purchasing,
      _ => purchasing,
    };
    final purchases = current.purchases
      ..mayDecide = (workspaceId) =>
          ref.read(purchaseApprovalAccessProvider(workspaceId));
    return purchases;
  }),
  purchaseApprovalReadsProvider.overrideWith(
    (ref) => FakePurchaseApprovalReads(
      switch (ref.watch(currentWorkspaceProvider).value?.id) {
        demoLondonSpaceId => (london ?? purchasing).purchases,
        demoNewYorkSpaceId => (newYork ?? purchasing).purchases,
        _ => purchasing.purchases,
      },
      thresholdUnits: (workspaceId) async {
        final settings = await ref
            .read(settingsRepositoryProvider)
            .load(workspaceId);
        return (settings.effective['purchase.single_approval_below_units']
                as num)
            .toInt();
      },
    ),
  ),
  supplierBalanceRepositoryProvider.overrideWith((ref) {
    final id = ref.watch(currentWorkspaceProvider).value?.id;
    final current = switch (id) {
      demoLondonSpaceId => london ?? purchasing,
      demoNewYorkSpaceId => newYork ?? purchasing,
      _ => purchasing,
    };
    return FakeSupplierBalanceRepository(
      workspaceId: id ?? 'ws-1',
      purchases: current.purchases,
    );
  }),
];
