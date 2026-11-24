// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 -- the till's route: it reads the stock's items and hands the till its keys, so the money feature does not
// import the stock.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/money/domain/counter_till.dart';
import '../../features/money/presentation/till_drawer/till_day_screen.dart';
import '../../features/money/presentation/till_drawer/till_drawer_screen.dart';
import '../../features/money/presentation/till_screen.dart';
import '../../features/stock/providers/stock_providers.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import '../../features/workspace/providers/workspace_providers.dart';

class TillRoute extends ConsumerWidget {
  const TillRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceId = ref.watch(currentWorkspaceProvider).value?.id;
    final keys = workspaceId == null
        ? const AsyncValue<List<TillKey>>.loading()
        : ref
              .watch(stockItemsProvider(workspaceId))
              .whenData((items) => [for (final i in items) if (i.active) TillKey(id: i.id, name: i.name, unit: i.unit)]);
    return TillScreen(workspaceId: workspaceId, keys: keys);
  }
}

/// #4367 — the cash drawer: the open business, its currency and whether the person manages the sites (they add the tills).
class TillDrawerRoute extends ConsumerWidget {
  const TillDrawerRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final manages = ref.watch(myPermissionsProvider).contains(WorkspacePermission.manageSites);
    return TillDrawerScreen(workspaceId: workspace?.id, currency: workspace?.currencyCode ?? '', canManage: manages, canCloseDay: ref.watch(myPermissionsProvider).contains(WorkspacePermission.viewFinances));
  }
}

/// #4367 — the day close: the open business and its currency; the route is open to whoever may see the finances.
class TillDayRoute extends ConsumerWidget {
  const TillDayRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(currentWorkspaceProvider).value;
    return TillDayScreen(workspaceId: workspace?.id, currency: workspace?.currencyCode ?? '');
  }
}
