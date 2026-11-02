// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:deskilo/features/money/providers/company_lookup_providers.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/money/providers/supplier_balance_provider.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'data/company_lookup_repository.dart';
import 'data/supplier_balance_repository.dart';
import 'seed/demo_purchase_seed.dart';

/// Keep the supplier and purchase readers inside the same Demo fixture.
List<Override> demoPurchasingOverrides(DemoPurchasing purchasing) => [
  supplierRepositoryProvider.overrideWithValue(purchasing.suppliers),
  companyLookupRepositoryProvider.overrideWithValue(
    FakeCompanyLookupRepository(),
  ),
  purchaseRepositoryProvider.overrideWithValue(purchasing.purchases),
  supplierBalanceRepositoryProvider.overrideWithValue(
    FakeSupplierBalanceRepository(
      workspaceId: 'ws-1',
      purchases: purchasing.purchases,
    ),
  ),
];
