// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3610 — search through the app: Ctrl+K opens it; a record result opens
// the record and comes back first as a recent item; what the person may
// not open is not offered (and goes the moment a permission is taken away
// with the window open); another workspace's answers never show; a
// customer or a supplier named by an address opens as its row opens it, and
// one the reader cannot read is said in words.

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:deskilo/core/demo/data/supplier_repository.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoice_page.dart';
import 'package:deskilo/features/money/presentation/screens/suppliers_desk.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/features/search/domain/search_result.dart';
import 'package:deskilo/features/search/presentation/search_palette.dart';
import 'package:deskilo/features/search/providers/search_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/presentation/widgets/report_pages.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

Finder _k(String key) => find.byKey(ValueKey(key));

class _Perms extends Notifier<Set<WorkspacePermission>> {
  @override
  Set<WorkspacePermission> build() => WorkspacePermission.values.toSet();
  void set(Set<WorkspacePermission> next) => state = next;
}

final _perms = NotifierProvider<_Perms, Set<WorkspacePermission>>(_Perms.new);

class _Scope extends Notifier<SearchScope?> {
  @override
  SearchScope? build() =>
      (account: 'u1', server: 'https://dev', workspace: 'ws-1');
  void set(SearchScope? next) => state = next;
}

final _scope = NotifierProvider<_Scope, SearchScope?>(_Scope.new);

typedef _App = ({ProviderContainer c, GoRouter router, String invoice});

Future<_App> _pump(
  WidgetTester tester, {
  Size size = const Size(1440, 900),
  FakeSupplierRepository? suppliers,
  String path = '/invoices',
  bool menu = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final money = FakeMoneyRepository();
  final id = await money.createInvoice(
    workspaceId: 'ws-1',
    memberId: 'member-1',
    period: kTestPeriod,
  );
  final features = WorkspaceFeature.values.toSet();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          money: money,
          workspace: FakeWorkspaceRepository.withWorkspace(
            featureFlags: {for (final f in features) f.name: true},
          ),
        ),
        enabledFeaturesSyncProvider.overrideWithValue(features),
        myPermissionsProvider.overrideWith((ref) => ref.watch(_perms)),
        searchScopeProvider.overrideWith((ref) => ref.watch(_scope)),
        if (menu) webShellProvider.overrideWithValue(true),
        if (suppliers != null)
          supplierRepositoryProvider.overrideWithValue(suppliers),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  final c = ProviderScope.containerOf(tester.element(find.byType(DeskiloApp)));
  final router = c.read(routerProvider)..go(path);
  await tester.pumpAndSettle();
  return (c: c, router: router, invoice: id);
}

Future<void> _ctrlK(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_k('search-field'), text);
  await tester.pump(searchDebounce);
  await tester.pumpAndSettle();
}

String _at(GoRouter r) => r.routeInformationProvider.value.uri.toString();

void main() {
  testWidgets('Ctrl+K finds an invoice by its number and opens it; it comes '
      'back first as a recent item', (tester) async {
    final app = await _pump(tester);
    final number = (await app.c.read(invoicesProvider.future))
        .firstWhere((i) => i.id == app.invoice)
        .number;
    await _ctrlK(tester);
    expect(_k('search-palette'), findsOneWidget);
    await _type(tester, number);
    await tester.tap(_k('search-result-invoice:${app.invoice}'));
    await tester.pumpAndSettle();
    expect(_k('search-palette'), findsNothing);
    expect(_at(app.router), '/invoices/${app.invoice}');
    expect(find.byType(InvoicePage), findsOneWidget);

    await _ctrlK(tester);
    expect(_k('search-recent'), findsOneWidget);
    expect(_k('search-result-invoice:${app.invoice}'), findsOneWidget);
  });

  testWidgets('on a phone the bar keeps its controls and the drawer\'s first entry opens search', (
    tester,
  ) async {
    await _pump(tester, size: const Size(390, 844), path: '/money', menu: true);
    // The phone's bar keeps its controls: Settings one tap away, no
    // search button folding it; search is the drawer's first entry.
    expect(_k('shell-search-button'), findsNothing);
    tester
        .stateList<ScaffoldState>(find.byType(Scaffold))
        .firstWhere((s) => s.hasDrawer)
        .openDrawer();
    await tester.pumpAndSettle();
    await tester.tap(_k('drawer-search'));
    await tester.pumpAndSettle();
    expect(_k('search-palette'), findsOneWidget);
    await _type(tester, 'invoic');
    expect(
      find.descendant(
        of: _k('search-palette'),
        matching: find.byType(ListTile),
      ),
      findsWidgets,
    );
  });

  testWidgets('a phone\'s bar is unchanged: Settings one tap away, nothing '
      'folded for search', (tester) async {
    await _pump(tester, size: const Size(390, 844), path: '/money');
    expect(_k('shell-search-button'), findsNothing);
    expect(_k('shell-overflow-button'), findsNothing);
    expect(_k('shell-settings-button'), findsOneWidget);
  });

  testWidgets('what the person may not open is not offered, and goes when a '
      'permission is taken away with the window open', (tester) async {
    final app = await _pump(tester);
    final number = (await app.c.read(invoicesProvider.future)).first.number;
    await _ctrlK(tester);
    await _type(tester, 'new');
    expect(_k('search-result-action:new-invoice'), findsOneWidget);
    await _type(tester, number);
    expect(_k('search-result-invoice:${app.invoice}'), findsOneWidget);

    app.c.read(_perms.notifier).set({WorkspacePermission.viewMyMoney});
    await tester.pumpAndSettle();
    await _type(tester, 'new');
    expect(_k('search-result-action:new-invoice'), findsNothing);
    expect(_k('search-result-action:new-purchase'), findsNothing);
    // The pages the navigation does not offer this person are not offered.
    await _type(tester, 'members');
    expect(_k('search-result-page:drawer-members'), findsNothing);
    await _type(tester, 'suppliers');
    expect(_k('search-result-page:drawer-suppliers'), findsNothing);
  });

  testWidgets('a revoked record is not offered again from the recent items', (
    tester,
  ) async {
    final app = await _pump(tester);
    final number = (await app.c.read(invoicesProvider.future)).first.number;
    await _ctrlK(tester);
    await _type(tester, number);
    await tester.tap(_k('search-result-invoice:${app.invoice}'));
    await tester.pumpAndSettle();
    app.c.read(_perms.notifier).set(const {});
    await tester.pumpAndSettle();
    await _ctrlK(tester);
    expect(_k('search-result-invoice:${app.invoice}'), findsNothing);
  });

  testWidgets('another workspace: the answers and the recent items of the '
      'first never show', (tester) async {
    final app = await _pump(tester);
    final number = (await app.c.read(invoicesProvider.future)).first.number;
    await _ctrlK(tester);
    await _type(tester, number);
    await tester.tap(_k('search-result-invoice:${app.invoice}'));
    await tester.pumpAndSettle();
    await _ctrlK(tester);
    await _type(tester, number);
    expect(_k('search-result-invoice:${app.invoice}'), findsOneWidget);
    app.c.read(_scope.notifier).set((
      account: 'u1',
      server: 'https://dev',
      workspace: 'ws-2',
    ));
    await tester.pumpAndSettle();
    expect(_k('search-result-invoice:${app.invoice}'), findsNothing);
    expect(app.c.read(searchRecentsProvider), isEmpty);
  });

  testWidgets('#3614 — a customer has an address of their own, and the '
      'search opens it; one the reader has no invoice of is said in words', (
    tester,
  ) async {
    final app = await _pump(tester);
    final invoice = (await app.c.read(invoicesProvider.future)).single;
    await _ctrlK(tester);
    await _type(tester, invoice.clientName);
    await tester.tap(_k('search-result-customer:${invoice.memberId}'));
    await tester.pumpAndSettle();
    expect(_at(app.router), '/invoices/customer/${invoice.memberId}');
    expect(_k('customer-page-statement'), findsOneWidget);

    app.router.go('/invoices/customer/nobody');
    await tester.pumpAndSettle();
    expect(_k('search-record-unreadable'), findsOneWidget);
  });

  testWidgets('#3615 — the search opens a supplier at its own address; '
      'an unknown one is said in words', (tester) async {
    final suppliers = FakeSupplierRepository();
    final id = await suppliers.save('ws-1', const SupplierDraft(name: 'ACME'));
    final app = await _pump(tester, suppliers: suppliers);
    await _ctrlK(tester);
    await _type(tester, 'acme');
    await tester.tap(_k('search-result-supplier:$id'));
    await tester.pumpAndSettle();
    // #3615 — the supplier's own address, its payables beside the table.
    expect(_at(app.router), '/money/suppliers/$id');
    expect(_k('search-record-unreadable'), findsNothing);
    expect(find.byType(SupplierRecord), findsOneWidget, reason: 'its payables');

    app.router.go('/money/suppliers/nobody');
    await tester.pumpAndSettle();
    expect(_k('search-record-unreadable'), findsOneWidget);
  });

  testWidgets('#3617 — the search finds every report the person may open, '
      'from the same declaration as the reports page', (tester) async {
    final app = await _pump(tester);
    final member = await app.c.read(myMemberProvider.future);
    final reports = reportPagesFor(
      features: app.c.read(enabledFeaturesSyncProvider),
      permissions: app.c.read(myPermissionsProvider),
      isAdmin: member?.isAdmin ?? false,
      actsAsOwner: member?.actsAsOwner ?? false,
    );
    expect(reports, isNotEmpty);
    final l = lookupAppLocalizations(const Locale('en'));
    for (final r in reports) {
      await _ctrlK(tester);
      await _type(tester, r.name(l));
      expect(
        find.descendant(
          of: _k('search-palette'),
          matching: find.text(r.name(l)),
        ),
        findsWidgets,
        reason: r.id,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    }
  });
}
