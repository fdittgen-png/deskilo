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
import 'seed/demo_london_seed.dart';
import 'seed/demo_new_york_seed.dart';
import 'seed/demo_purchase_seed.dart';
import 'seed/demo_trade_city_seed.dart';
import 'seed/demo_twin_seed.dart';

String _approvalSpace(Ref ref) => switch (ref.watch(currentWorkspaceProvider).value?.id) {
  null || '' || 'ws-1' => 'ws-1',
  demoTwinSpaceId => demoTwinSpaceId,
  demoLondonSpaceId => demoLondonSpaceId,
  demoNewYorkSpaceId => demoNewYorkSpaceId,
  demoZurichSpaceId => demoZurichSpaceId,
  demoMilanSpaceId => demoMilanSpaceId,
  _ => '__unavailable__',
};

String _approvalCurrency(Ref ref) => switch (ref.watch(currentWorkspaceProvider).value?.id) {
  demoLondonSpaceId => 'GBP',
  demoNewYorkSpaceId => 'USD',
  demoZurichSpaceId => demoZurich.currency,
  demoMilanSpaceId => demoMilan.currency,
  _ => 'EUR',
};

/// Keep the supplier and purchase readers inside the same Demo fixture: each
/// space reads its own (#3797), a space not given its own reads [purchasing].
List<Override> demoPurchasingOverrides(
  DemoPurchasing purchasing, {
  DemoPurchasing? leipzig,
  DemoPurchasing? london,
  DemoPurchasing? newYork,
  DemoPurchasing? zurich,
  DemoPurchasing? milan,
  DemoPurchasing? twin,
}) {
  final DemoSpaces<DemoPurchasing> spaces = (
    home: purchasing,
    leipzig: leipzig ?? purchasing,
    london: london ?? purchasing,
    newYork: newYork ?? purchasing,
    zurich: zurich ?? purchasing,
    milan: milan ?? purchasing,
    twin: twin ?? purchasing,
  );
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
