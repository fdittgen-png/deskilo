// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:deskilo/features/money/providers/company_lookup_providers.dart';
import 'package:deskilo/features/money/providers/purchase_approval_provider.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/money/providers/supplier_balance_provider.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/features/workspace/providers/settings_providers.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'data/company_lookup_repository.dart';
import 'data/purchase_approval_reads.dart';
import 'data/supplier_balance_repository.dart';
import 'seed/demo_purchase_seed.dart';

/// Keep the supplier and purchase readers inside the same Demo fixture.
List<Override> demoPurchasingOverrides(DemoPurchasing purchasing) => [
  supplierRepositoryProvider.overrideWithValue(purchasing.suppliers),
  companyLookupRepositoryProvider.overrideWithValue(
    FakeCompanyLookupRepository(),
  ),
  purchaseRepositoryProvider.overrideWithValue(purchasing.purchases),
  purchaseApprovalReadsProvider.overrideWith(
    (ref) => FakePurchaseApprovalReads(
      purchasing.purchases,
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
  supplierBalanceRepositoryProvider.overrideWithValue(
    FakeSupplierBalanceRepository(
      workspaceId: 'ws-1',
      purchases: purchasing.purchases,
    ),
  ),
];
