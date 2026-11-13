// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:deskilo/features/money/providers/company_lookup_providers.dart';
import 'package:deskilo/features/money/providers/purchase_approval_provider.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/money/providers/supplier_balance_provider.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/features/workspace/providers/settings_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:flutter_riverpod/misc.dart' show Override;

import 'data/company_lookup_repository.dart';
import 'data/purchase_approval_reads.dart';
import 'data/supplier_balance_repository.dart';
import 'demo_space_pick.dart';
import 'seed/demo_commerce_country_seed.dart';
import 'seed/demo_london_seed.dart';
import 'seed/demo_new_york_seed.dart';
import 'seed/demo_purchase_seed.dart';
import 'seed/demo_second_space_seed.dart';
import 'seed/demo_twin_seed.dart';

String _approvalSpace(Ref ref) => switch (ref.watch(currentWorkspaceProvider).value?.id) {
  null || '' || 'ws-1' => 'ws-1',
  demoTwinSpaceId => demoTwinSpaceId,
  demoLondonSpaceId => demoLondonSpaceId,
  demoNewYorkSpaceId => demoNewYorkSpaceId,
  demoZurichSpaceId => demoZurichSpaceId,
  demoMilanSpaceId => demoMilanSpaceId,
  demoSecondSpaceId => demoSecondSpaceId,
  _ => '__unavailable__',
};

String _approvalCurrency(Ref ref) => switch (ref.watch(currentWorkspaceProvider).value?.id) {
  demoLondonSpaceId => 'GBP',
  demoNewYorkSpaceId => 'USD',
  demoZurichSpaceId => 'CHF',
  _ => 'EUR',
};

/// Keep supplier and purchase readers on each space's own fixture (#3797).
List<Override> demoPurchasingOverrides(DemoSpaces<DemoPurchasing> spaces) {
  return [
    supplierRepositoryProvider.overrideWith(
      (ref) => demoPickSpace(ref, spaces).suppliers,
    ),
    companyLookupRepositoryProvider.overrideWithValue(
      FakeCompanyLookupRepository(),
    ),
    purchaseRepositoryProvider.overrideWith((ref) {
      final purchases = demoPickSpace(ref, spaces).purchases
        ..mayDecide = (workspaceId) =>
            ref.read(purchaseApprovalAccessProvider(workspaceId));
      return purchases;
    }),
    purchaseApprovalReadsProvider.overrideWith(
      (ref) => FakePurchaseApprovalReads(
        demoPickSpace(ref, spaces).purchases,
        allowedWorkspaceId: _approvalSpace(ref),
        spaceCurrency: _approvalCurrency(ref),
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
    supplierBalanceRepositoryProvider.overrideWith(
      (ref) => FakeSupplierBalanceRepository(
        workspaceId: ref.watch(currentWorkspaceProvider).value?.id ?? 'ws-1',
        purchases: demoPickSpace(ref, spaces).purchases,
      ),
    ),
  ];
}
