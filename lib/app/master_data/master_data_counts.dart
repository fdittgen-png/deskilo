// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4485 — how many records a kind of master data holds: the length of the
// list its own screen reads, through that screen's own provider, so the card
// and the screen never disagree and a read is shared, not repeated. A read
// that fails stays a failure (the card shows it), never a count of zero.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderBase;

import '../../core/devices/connected_boards_provider.dart';
import '../../features/money/providers/billing_customer_providers.dart';
import '../../features/money/providers/money_providers.dart';
import '../../features/money/providers/supplier_providers.dart';
import '../../features/money/providers/till_drawer_providers.dart';
import '../../features/stock/providers/stock_providers.dart';
import '../../features/stock/providers/workspace_units_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import 'master_data_kinds.dart';

/// The read whose length is the count of [kind] in [workspaceId].
ProviderBase<AsyncValue<List<Object?>>> masterDataSource(
  MasterDataKind kind,
  String workspaceId,
) => switch (kind) {
  MasterDataKind.units => workspaceUnitListProvider(workspaceId),
  MasterDataKind.vatRates => vatRatesProvider,
  MasterDataKind.items => stockItemsProvider(workspaceId),
  MasterDataKind.itemGroups => itemGroupListProvider(workspaceId),
  MasterDataKind.services => allServicesProvider,
  MasterDataKind.places => stockPlaceConfigsProvider(workspaceId),
  MasterDataKind.tills => tillDrawerProvider(workspaceId),
  MasterDataKind.devices => connectedTillBoardsProvider,
  MasterDataKind.suppliers => suppliersProvider(workspaceId),
  MasterDataKind.customers => billingCustomersProvider(workspaceId),
  MasterDataKind.sites => sitesProvider,
};
