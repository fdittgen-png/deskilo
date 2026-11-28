// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 -- the till's route: it reads the stock's items and hands the till its keys, so the money feature does not
// import the stock.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/routes.dart';
import '../../core/ui/loading_view.dart';
import '../../features/money/domain/counter_till.dart';
import '../../features/money/domain/service_item.dart';
import '../../features/money/presentation/till_drawer/cash_reasons_screen.dart';
import '../../features/money/presentation/till_drawer/till_day_screen.dart';
import '../../features/money/presentation/till_drawer/till_drawer_screen.dart';
import '../../features/money/presentation/till_layout/till_layout_screen.dart';
import '../../features/money/presentation/till_screen.dart';
import '../../features/money/providers/money_providers.dart' show servicesProvider;
import '../../features/stock/domain/stock_code_resolver.dart';
import '../../features/stock/providers/stock_providers.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../route_access.dart';
import '../route_env.dart';
import 'counter_receipts_route.dart';

@visibleForTesting
class TillRoute extends ConsumerWidget {
  const TillRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final workspaceId = workspace?.id;
    // the price of each item, gross: what the till falls back on when it sells offline (the server prices every online sale)
    final prices = {for (final s in ref.watch(servicesProvider).value ?? const <ServiceItem>[]) s.id: s.priceCents}; // empty-ok: the prices only feed the offline fallback, the server prices every online sale
    final keys = workspaceId == null
        ? const AsyncValue<List<TillKey>>.loading()
        : ref
              .watch(stockItemsProvider(workspaceId))
              .whenData((items) => [
                for (final i in items)
                  if (i.active)
                    TillKey(
                      id: i.id,
                      name: i.name,
                      unit: i.unit,
                      grossMinor: prices[i.id],
                      category: i.tillCategory,
                      colour: i.quickKeyColour,
                      minAge: i.minAge,
                      weighed: i.soldByWeight,
                      depositItemId: i.depositItemId,
                    ),
              ]);
    return TillScreen(
      workspaceId: workspaceId,
      currency: workspace?.currencyCode ?? '',
      keys: keys,
      scan: workspaceId == null || !ref.watch(stockScanningProvider)
          ? null
          : (code) async => tillScanOf(await ref.read(stockCodeResolverProvider).resolve(workspaceId, code)),
    );
  }
}

/// #4367 — the cash drawer: the open business, its currency and whether the person manages the sites (they add the tills).
class _TillDrawerRoute extends ConsumerWidget {
  const _TillDrawerRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final manages = ref.watch(myPermissionsProvider).contains(WorkspacePermission.manageSites);
    return TillDrawerScreen(workspaceId: workspace?.id, currency: workspace?.currencyCode ?? '', canManage: manages, canCloseDay: ref.watch(myPermissionsProvider).contains(WorkspacePermission.viewFinances));
  }
}

/// The till id and the till's name in the layout editor's address ([Routes.tillLayoutOf]).
const _tillParam = 'tillId';
const _nameQuery = 'name';

/// #4448 — the layout editor: the open business and the till named in the address.
class _TillLayoutRoute extends ConsumerWidget {
  const _TillLayoutRoute({required this.tillId, required this.tillName});

  final String tillId;
  final String tillName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(currentWorkspaceProvider).value;
    if (workspace == null) return const LoadingView();
    return TillLayoutScreen(workspaceId: workspace.id, tillId: tillId, tillName: tillName);
  }
}

/// #4367 — the day close: the open business and its currency; the route is open to whoever may see the finances.
class _TillDayRoute extends ConsumerWidget {
  const _TillDayRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(currentWorkspaceProvider).value;
    return TillDayScreen(workspaceId: workspace?.id, currency: workspace?.currencyCode ?? '');
  }
}

/// #4514 — the cash reasons of the open business.
class _CashReasonsRoute extends ConsumerWidget {
  const _CashReasonsRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) => CashReasonsScreen(workspaceId: ref.watch(currentWorkspaceProvider).value?.id);
}

/// #4436 -- what a scanned code rings up at the till: an item by its own code or its tag, one piece by its tag.
/// A variant, a lot, a package unit or a place is not something the till rings up yet: it names nothing here.
@visibleForTesting
TillScan tillScanOf(StockCodeResolution r) {
  final item = r.item;
  if (item == null || item.id.isEmpty || r.unit != null || r.variantId != null) return TillScanUnknown(r.code);
  final key = TillKey(id: item.id, name: item.name, unit: item.unit);
  if (r.isPieceTag) return TillScanPiece(key, r.code);
  if (r.kind == ScannedKind.item || (r.kind == ScannedKind.tag && r.tagBound && r.tagOwnerKind == 'item')) return TillScanItem(key);
  return TillScanUnknown(r.code);
}

/// #4366, #4367 — the till, its cash drawer and its day close.
List<RouteBase> tillRoutes(RouteEnv env) => [
    // #4366 — the till: a full-screen basket served in seconds, on the counter receipt of #4184.
    GoRoute(
      path: '/till',
      redirect: env.guard(
        const RouteAccess(features: [WorkspaceFeature.counterReceipts], to: '/money'),
      ),
      builder: (context, state) => const TillRoute(),
      routes: [
        // #4185 — the receipts the till made: share, correct, give back, take back, settle a card answer.
        GoRoute(path: 'receipts', builder: (context, state) => const CounterReceiptsRoute()),
      ],
    ),
    // #4367 — the cash drawer of the tills: open with a float, cash in and out, count and close.
    GoRoute(
      path: '/till/drawer',
      redirect: env.guard(
        const RouteAccess(features: [WorkspaceFeature.counterTillSessions], to: '/till'),
      ),
      builder: (context, state) => const _TillDrawerRoute(),
    ),
    // #4448 — the layout editor of one till: who may lay out the tills, where till layouts are on.
    GoRoute(
      path: Routes.tillLayout,
      redirect: env.guard(
        const RouteAccess(features: [WorkspaceFeature.counterTillLayout], permission: WorkspacePermission.configureTill, to: '/till/drawer'),
      ),
      builder: (context, state) => _TillLayoutRoute(tillId: state.pathParameters[_tillParam] ?? '', tillName: state.uri.queryParameters[_nameQuery] ?? ''),
    ),
    // #4514 — the cash reasons: who configures the tills names them, where till sessions and cash reasons are on.
    GoRoute(
      path: Routes.tillCashReasons,
      redirect: env.guard(
        const RouteAccess(features: [WorkspaceFeature.counterTillSessions, WorkspaceFeature.counterCashReasons], permission: WorkspacePermission.configureTill, to: '/till/drawer'),
      ),
      builder: (context, state) => const _CashReasonsRoute(),
    ),
    // #4367 — the day close: the finances close the business day and read its report.
    GoRoute(
      path: '/till/day',
      redirect: env.guard(
        const RouteAccess(features: [WorkspaceFeature.counterTillSessions], to: '/till'),
      ),
      builder: (context, state) => const _TillDayRoute(),
    ),
];
