// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3610 — what search offers this person, assembled where the app's
// features meet: the pages of the business's navigation (the entries the
// sidebar and the drawer show, so a page the person may not open is never
// offered), three actions, and one record source per kind (members,
// invoices by number, customers, suppliers) on the repositories that exist.
// Each is asked whether the person may use it every time the search window
// builds; a record is opened at its address, through the route's own guard
// and the page's own read.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/context_l10n.dart';
import '../features/money/presentation/widgets/invoice_form_sheet.dart';
import '../features/money/presentation/widgets/purchase_dialogs.dart';
import '../features/money/providers/money_providers.dart';
import '../features/money/providers/purchase_providers.dart';
import '../features/money/providers/supplier_providers.dart';
import '../features/search/domain/search_result.dart';
import '../features/search/presentation/search_palette.dart';
import '../features/workspace/domain/invite_uri.dart';
import '../features/workspace/domain/workspace_feature.dart';
import '../features/workspace/domain/workspace_permission.dart';
import '../features/workspace/presentation/widgets/invite_sheet.dart';
import '../features/workspace/presentation/widgets/report_pages.dart';
import '../features/workspace/providers/workspace_providers.dart';
import 'shell/desk_frame.dart';
import 'shell/shell_drawer_entries.dart';
import 'shell/shell_menu.dart';
import 'shell/shell_nav_groups.dart';

typedef _F = WorkspaceFeature;
typedef _P = WorkspacePermission;

/// Opens the search window. [later] gives the context and the ref an
/// action opens its sheet with once the window has closed (the router's
/// navigator, the app's own ref).
Future<void> openSearch(
  BuildContext context,
  GoRouter router, {
  required BuildContext? Function() later,
  required WidgetRef appRef,
}) => showSearchPalette(
  context,
  offers: (context, ref) =>
      _searchOffers(context, ref, router, later: later, appRef: appRef),
  openRoute: (route) => unawaited(router.push(route)),
);

/// What [ref]'s person may find now.
SearchOffers _searchOffers(
  BuildContext context,
  WidgetRef ref,
  GoRouter router, {
  required BuildContext? Function() later,
  required WidgetRef appRef,
}) => (
  fixed: [
    ..._pages(context, ref, router),
    ..._actions(context, ref, later: later, appRef: appRef),
  ],
  sources: _sources(context, ref),
);

/// The pages of the business's navigation, as the sidebar offers them.
List<SearchOffer> _pages(BuildContext context, WidgetRef ref, GoRouter router) {
  final l10n = context.l10n;
  final path = router.routeInformationProvider.value.uri.path;
  final menu = ShellMenu.of(
    context,
    ref,
    permanent: true,
    tabs: deskPlaceOf(context, ref, router, path).tabs,
  );
  final fixed = <SearchOffer>[];
  final seen = <String>{};
  void page(DrawerEntry e, String? group) {
    if (!seen.add(e.key)) return;
    final route = e.route;
    fixed.add(
      SearchOffer(
        SearchResult(
          id: 'page:${e.key}',
          kind: SearchKind.page,
          source: 'pages',
          title: e.label,
          where: group == null
              ? l10n.searchKindPage
              : '${l10n.searchKindPage} · $group',
        ),
        route == null ? e.onTap : () => unawaited(router.push(route)),
      ),
    );
  }

  void group(NavGroup g) {
    for (final e in g.entries) {
      page(e, g.title);
    }
    g.sub.forEach(group);
  }

  for (final e in menu.navigation) {
    page(e, null);
  }
  menu.groups.forEach(group);
  for (final e in menu.account) {
    page(e, null);
  }
  // #3617 — the reports that are pages, from their one declaration; one
  // the menu already offers at the same address is not offered twice.
  final routes = {
    for (final g in menu.groups) ...[
      for (final e in g.entries) ?e.route,
      for (final sub in g.sub)
        for (final e in sub.entries) ?e.route,
    ],
    for (final e in menu.navigation) ?e.route,
  };
  final member = ref.watch(myMemberProvider).value;
  for (final r in reportPagesFor(
    features: ref.watch(enabledFeaturesSyncProvider),
    permissions: ref.watch(myPermissionsProvider),
    isAdmin: member?.isAdmin ?? false,
    actsAsOwner: member?.actsAsOwner ?? false,
  )) {
    if (routes.contains(r.route)) continue;
    fixed.add(
      SearchOffer(
        SearchResult(
          id: 'report:${r.id}',
          kind: SearchKind.page,
          source: 'pages',
          title: r.name(l10n),
          where: '${l10n.searchKindPage} · ${l10n.uxReportsTitle}',
        ),
        () => unawaited(router.push(r.route)),
      ),
    );
  }
  return fixed;
}

/// New invoice, New purchase, Invite a member: each where its sheet opens.
List<SearchOffer> _actions(
  BuildContext context,
  WidgetRef ref, {
  required BuildContext? Function() later,
  required WidgetRef appRef,
}) {
  final l10n = context.l10n;
  final features = ref.watch(enabledFeaturesSyncProvider);
  final perms = ref.watch(myPermissionsProvider);
  final workspace = ref.watch(currentWorkspaceProvider).value;
  SearchOffer action(
    String id,
    String title,
    void Function(BuildContext) run,
  ) => SearchOffer(
    SearchResult(
      id: 'action:$id',
      kind: SearchKind.action,
      source: 'actions',
      title: title,
      where: l10n.searchKindAction,
    ),
    () {
      final at = later();
      if (at != null && at.mounted) run(at);
    },
  );
  final wsId = workspace?.id;
  return [
    if (features.contains(_F.invoicing) && perms.contains(_P.issueInvoices))
      action(
        'new-invoice',
        l10n.invoiceCreate,
        (at) => unawaited(showInvoiceIssueSheet(at, appRef)),
      ),
    if (wsId != null &&
        features.contains(_F.purchases) &&
        perms.contains(_P.managePurchases))
      action('new-purchase', l10n.searchActionNewPurchase, (at) async {
        final saved = await showPurchaseBillDialog(at, wsId);
        if (saved ?? false) appRef.invalidate(purchasesProvider(wsId));
      }),
    if (workspace != null &&
        perms.any({_P.manageMembers, _P.manageConfiguration}.contains))
      action(
        'invite',
        l10n.searchActionInvite,
        (at) => unawaited(
          showInviteSheet(at, workspace: workspace, role: InviteRole.user),
        ),
      ),
  ];
}

/// One source per kind of record the person may read.
List<SearchSource> _sources(BuildContext context, WidgetRef ref) {
  final l10n = context.l10n;
  final features = ref.watch(enabledFeaturesSyncProvider);
  final perms = ref.watch(myPermissionsProvider);
  final member = ref.watch(myMemberProvider).value;
  final wsId = ref.watch(currentWorkspaceProvider).value?.id;
  final money = features.contains(_F.invoicing);
  final readsInvoices = perms.any(
    {_P.viewMyMoney, _P.viewFinances, _P.issueInvoices}.contains,
  );
  return [
    if (features.contains(_F.memberPage) &&
        (perms.contains(_P.manageMembers) || (member?.isAdmin ?? false)))
      _MemberSource(ref, l10n.searchKindMember),
    if (money && readsInvoices) _InvoiceSource(ref, l10n.invoicingColInvoice),
    if (money && perms.contains(_P.issueInvoices))
      _CustomerSource(ref, l10n.invoicingColCustomer),
    if (wsId != null &&
        features.contains(_F.supplyExpenses) &&
        features.contains(_F.purchases) &&
        perms.any({_P.viewFinances, _P.managePurchases}.contains))
      _SupplierSource(ref, wsId, l10n.purchasesSupplier),
  ];
}

class _MemberSource implements SearchSource {
  _MemberSource(this._ref, this._what);

  final WidgetRef _ref;
  final String _what;

  @override
  String get id => 'members';

  @override
  Future<List<SearchResult>> search(String query) async {
    final names = await _ref.read(memberNamesProvider.future);
    final members = await _ref.read(workspaceMembersProvider.future);
    return [
      for (final m in members)
        if (names[m.id] case final name? when searchMatches(query, [name]))
          SearchResult(
            id: 'member:${m.id}',
            kind: SearchKind.record,
            source: id,
            title: name,
            where: _what,
            route: '/member/${m.id}',
          ),
    ];
  }
}

class _InvoiceSource implements SearchSource {
  _InvoiceSource(this._ref, this._what);

  final WidgetRef _ref;
  final String _what;

  @override
  String get id => 'invoices';

  @override
  Future<List<SearchResult>> search(String query) async => [
    for (final i in await _ref.read(invoicesProvider.future))
      if (searchMatches(query, [i.number, i.clientName]))
        SearchResult(
          id: 'invoice:${i.id}',
          kind: SearchKind.record,
          source: id,
          title: i.number,
          where: '$_what · ${i.clientName}',
          route: '/invoices/${i.id}',
        ),
  ];
}

/// A customer is a member invoiced: opened at their own address (#3614),
/// beside the invoice list on a large window.
class _CustomerSource implements SearchSource {
  _CustomerSource(this._ref, this._what);

  final WidgetRef _ref;
  final String _what;

  @override
  String get id => 'customers';

  @override
  Future<List<SearchResult>> search(String query) async {
    final seen = <String>{};
    return [
      for (final i in await _ref.read(invoicesProvider.future))
        if (seen.add(i.memberId) && searchMatches(query, [i.clientName]))
          SearchResult(
            id: 'customer:${i.memberId}',
            kind: SearchKind.record,
            source: id,
            title: i.clientName,
            where: _what,
            // #3614 — the customer's own address.
            route: '/invoices/customer/${Uri.encodeComponent(i.memberId)}',
          ),
    ];
  }
}

/// Opened on the suppliers page, as its row opens it (#3615 gives
/// suppliers an address of their own).
class _SupplierSource implements SearchSource {
  _SupplierSource(this._ref, this._workspaceId, this._what);

  final WidgetRef _ref;
  final String _workspaceId;
  final String _what;

  @override
  String get id => 'suppliers';

  @override
  Future<List<SearchResult>> search(String query) async => [
    for (final s in await _ref.read(suppliersProvider(_workspaceId).future))
      if (s.isActive && searchMatches(query, [s.name, s.number, s.city]))
        SearchResult(
          id: 'supplier:${s.id}',
          kind: SearchKind.record,
          source: id,
          title: s.name,
          where: s.city.isEmpty ? _what : '$_what · ${s.city}',
          route: Uri(
            path: '/money/suppliers',
            queryParameters: {'supplier': s.id},
          ).toString(),
        ),
  ];
}
