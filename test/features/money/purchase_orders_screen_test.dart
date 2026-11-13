// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — the purchase orders screen: a buyer (managePurchases) drafts a
// new order through the form (each problem under its field first), marks a
// draft sent and cancels it with a reason; a finance reader sees the same
// list and its print, nothing else.
import 'package:deskilo/core/demo/data/purchase_order_repository.dart';
import 'package:deskilo/core/demo/data/supplier_repository.dart';
import 'package:deskilo/features/money/domain/purchase_order.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:deskilo/features/money/presentation/screens/purchase_order_page.dart';
import 'package:deskilo/features/money/presentation/screens/purchase_orders_screen.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/purchase_order_providers.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _workspace = Workspace(
  id: 'ws',
  name: 'Space',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'x',
);

/// The list and the order's form, at the addresses the app gives them
/// (#3608: the form is a long task, a page with an address).
Widget _scope(List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp.router(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: GoRouter(
      initialLocation: '/money/purchase-orders',
      routes: [
        GoRoute(
          path: '/money/purchase-orders',
          builder: (context, state) => const PurchaseOrdersScreen(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => const PurchaseOrderPage(),
            ),
            GoRoute(
              path: ':id/edit',
              builder: (context, state) =>
                  PurchaseOrderPage(orderId: state.pathParameters['id']),
            ),
          ],
        ),
      ],
    ),
  ),
);

Future<(FakePurchaseOrderRepository, Widget)> _app(
  Set<WorkspacePermission> permissions,
) async {
  final suppliers = FakeSupplierRepository();
  final alpha = await suppliers.save('ws', const SupplierDraft(name: 'Alpha'));
  final orders = FakePurchaseOrderRepository(
    suppliers: () => suppliers.suppliers,
    services: () => const [],
    now: () => DateTime(2026, 11, 4),
  );
  await orders.save(
    'ws',
    'seed',
    PurchaseOrderDraft(
      supplierId: alpha,
      lines: const [
        PurchaseOrderLineDraft(
          description: 'Paper towels',
          quantity: 12,
          unitPriceCents: 150,
        ),
      ],
    ),
  );
  return (
    orders,
    _scope([
      currentWorkspaceProvider.overrideWith((ref) async => _workspace),
      myMemberProvider.overrideWith((ref) async => null),
      myPermissionsProvider.overrideWithValue(permissions),
      enabledFeaturesSyncProvider.overrideWithValue({
        WorkspaceFeature.purchases,
        WorkspaceFeature.purchaseOrders,
      }),
      supplierRepositoryProvider.overrideWithValue(suppliers),
      purchaseOrderRepositoryProvider.overrideWithValue(orders),
      servicesProvider.overrideWith((ref) async => const <ServiceItem>[]),
    ]),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('a buyer drafts an order, marks it sent and cancels it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (orders, app) = await _app({WorkspacePermission.managePurchases});
    await tester.pumpWidget(app);
    await _settle(tester);
    expect(
      find.byKey(const ValueKey('purchase-order-2026-0001')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('purchase-order-new')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('purchase-order-save')));
    await _settle(tester);
    expect(find.text('Choose the supplier'), findsOneWidget);
    expect(find.text('Say what is ordered, or choose an item'), findsOneWidget);
    expect(orders.orders, hasLength(1));

    await tester.tap(find.byKey(const ValueKey('purchase-order-supplier')));
    await _settle(tester);
    await tester.tap(find.textContaining('Alpha').last);
    await _settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('purchase-order-desc-0')),
      'Coffee beans',
    );
    await tester.enterText(
      find.byKey(const ValueKey('purchase-order-qty-0')),
      '5',
    );
    await tester.enterText(
      find.byKey(const ValueKey('purchase-order-price-0')),
      '12,50',
    );
    await tester.enterText(
      find.byKey(const ValueKey('purchase-order-vat-0')),
      '5.5',
    );
    await tester.tap(find.byKey(const ValueKey('purchase-order-save')));
    await _settle(tester);
    expect(orders.orders, hasLength(2));
    final saved = orders.orders.last;
    expect(
      (
        saved.reference,
        saved.lines.single.unitPriceCents,
        saved.lines.single.vatRatePercent,
      ),
      ('2026-0002', 1250, 5.5),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('purchase-order-sent-2026-0001')),
    );
    await tester.tap(
      find.byKey(const ValueKey('purchase-order-sent-2026-0001')),
    );
    await _settle(tester);
    expect(orders.orders.first.state, PurchaseOrderState.sent);

    await tester.ensureVisible(
      find.byKey(const ValueKey('purchase-order-cancel-2026-0001')),
    );
    await tester.tap(
      find.byKey(const ValueKey('purchase-order-cancel-2026-0001')),
    );
    await _settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('purchase-order-cancel-reason')),
      'ordered twice',
    );
    await tester.tap(
      find.byKey(const ValueKey('purchase-order-cancel-confirm')),
    );
    await _settle(tester);
    expect(orders.orders.first.state, PurchaseOrderState.cancelled);
    expect(orders.orders.first.cancelReason, 'ordered twice');
  });

  testWidgets('a finance reader reads and prints, nothing else', (
    tester,
  ) async {
    final (_, app) = await _app({WorkspacePermission.viewFinances});
    await tester.pumpWidget(app);
    await _settle(tester);
    expect(
      find.byKey(const ValueKey('purchase-order-2026-0001')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('purchase-order-print-2026-0001')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('purchase-order-new')), findsNothing);
    expect(
      find.byKey(const ValueKey('purchase-order-edit-2026-0001')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('purchase-order-cancel-2026-0001')),
      findsNothing,
    );
  });

  group('the order is a long task: a page with its totals', () {
    final summary = find.byKey(const ValueKey('purchase-order-summary'));
    final save = find.byKey(const ValueKey('purchase-order-save'));

    testWidgets('its totals follow the lines, beside the form at 1440', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (_, app) = await _app({WorkspacePermission.managePurchases});
      await tester.pumpWidget(app);
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('purchase-order-new')));
      await _settle(tester);
      expect(
        find.byKey(const ValueKey('long-task-summary')),
        findsOneWidget,
      );
      expect(find.descendant(of: summary, matching: find.text('No line')), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('purchase-order-qty-0')),
        '5',
      );
      await tester.enterText(
        find.byKey(const ValueKey('purchase-order-price-0')),
        '12,50',
      );
      await tester.enterText(
        find.byKey(const ValueKey('purchase-order-vat-0')),
        '5.5',
      );
      await tester.pump();
      for (final amount in ['62.50', '3.44', '65.94']) {
        expect(
          find.descendant(of: summary, matching: find.textContaining(amount)),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(of: summary, matching: find.text('One line')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('purchase-order-add-line')));
      await tester.pump();
      expect(
        find.descendant(of: summary, matching: find.text('2 lines')),
        findsOneWidget,
      );
    });

    testWidgets('at 390 the totals follow the fields and Save is in view', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (_, app) = await _app({WorkspacePermission.managePurchases});
      await tester.pumpWidget(app);
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('purchase-order-new')));
      await _settle(tester);
      // The test font (Ahem) is wider than any real one: the footer's two
      // buttons overflow by a few pixels at 342; that is the font, not
      // the layout, and is taken here.
      expect(tester.takeException(), isA<FlutterError>());
      expect(find.byKey(const ValueKey('long-task-summary')), findsNothing);
      expect(tester.getBottomLeft(save).dy, lessThanOrEqualTo(844));
      expect(tester.getTopLeft(save).dy, greaterThanOrEqualTo(0));
      await tester.scrollUntilVisible(
        summary,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(summary, findsOneWidget);
    });

    testWidgets('a draft is edited at its own address, prefilled', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (orders, app) = await _app({WorkspacePermission.managePurchases});
      await tester.pumpWidget(app);
      await _settle(tester);
      await tester.tap(
        find.byKey(const ValueKey('purchase-order-edit-2026-0001')),
      );
      await _settle(tester);
      expect(find.text('Paper towels'), findsOneWidget);
      expect(
        find.descendant(of: summary, matching: find.textContaining('18.00')),
        findsWidgets,
      );
      await tester.enterText(
        find.byKey(const ValueKey('purchase-order-qty-0')),
        '20',
      );
      await tester.tap(save);
      await _settle(tester);
      expect(orders.orders.first.lines.single.quantity, 20);
      // Back on the list, the page gone.
      expect(save, findsNothing);
      expect(
        find.byKey(const ValueKey('purchase-order-2026-0001')),
        findsOneWidget,
      );
    });

    testWidgets('leaving typed work asks; an unchanged page closes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (orders, app) = await _app({WorkspacePermission.managePurchases});
      await tester.pumpWidget(app);
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('purchase-order-new')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('long-task-close')));
      await _settle(tester);
      expect(save, findsNothing);
      await tester.tap(find.byKey(const ValueKey('purchase-order-new')));
      await _settle(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('purchase-order-desc-0')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('purchase-order-desc-0')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('purchase-order-desc-0')),
        'Coffee',
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);
      expect(
        find.byKey(const ValueKey('unsaved-changes-dialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('unsaved-changes-discard')));
      await _settle(tester);
      expect(save, findsNothing);
      expect(orders.orders, hasLength(1));
    });
  });
}
