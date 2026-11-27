// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4492 — the purchase orders on a phone are the records page the desk has:
// a card per order that opens the order at its own address, the worded main
// action in the page's bar (no floating button), a read that failed said as
// one with Try again — never as "no orders" — and the kit's empty state.
import 'dart:io';

import 'package:deskilo/core/demo/data/purchase_order_repository.dart';
import 'package:deskilo/core/demo/data/supplier_repository.dart';
import 'package:deskilo/core/ui/empty_state.dart';
import 'package:deskilo/core/ui/kit/status_chip.dart';
import 'package:deskilo/features/money/domain/purchase_order.dart';
import 'package:deskilo/features/money/presentation/screens/purchase_orders_screen.dart';
import 'package:deskilo/features/money/providers/purchase_order_providers.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/read_probe.dart';
import '../../helpers/screens/purchase_orders_app.dart';

final _en = AppLocalizationsEn();

const _workspace = Workspace(
  id: 'ws',
  name: 'Space',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'x',
);

List<Override> _space(Set<WorkspacePermission> permissions) => [
  currentWorkspaceProvider.overrideWith((ref) async => _workspace),
  myMemberProvider.overrideWith((ref) async => null),
  myPermissionsProvider.overrideWithValue(permissions),
  enabledFeaturesSyncProvider.overrideWithValue({
    WorkspaceFeature.purchases,
    WorkspaceFeature.purchaseOrders,
  }),
];

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('an order is a card that opens the order at its own address; '
      'New order is the worded action of the bar', (tester) async {
    _phone(tester);
    final suppliers = FakeSupplierRepository();
    final alpha = await suppliers.save(
      'ws',
      const SupplierDraft(name: 'Alpha'),
    );
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
    await tester.pumpWidget(
      purchaseOrdersApp([
        ..._space({WorkspacePermission.managePurchases}),
        supplierRepositoryProvider.overrideWithValue(suppliers),
        purchaseOrderRepositoryProvider.overrideWithValue(orders),
      ]),
    );
    await _settle(tester);

    final card = find.byKey(const ValueKey('purchase-order-2026-0001'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.textContaining('Alpha')),
      findsOneWidget,
      reason: 'the card names the supplier',
    );
    expect(
      find.descendant(
        of: card,
        matching: find.widgetWithText(StatusChip, _en.purchasesStateDraft),
      ),
      findsOneWidget,
      reason: 'the state is its chip on the card, as on the row',
    );
    expect(
      find.descendant(
        of: card,
        matching: find.textContaining(_en.purchasesStateDraft),
      ),
      findsOneWidget,
      reason: 'and is said once: no state word in the line under the number',
    );
    expect(
      find.byKey(const ValueKey('purchase-order-print-2026-0001')),
      findsNothing,
      reason: 'what an order allows is on its record, not on the list',
    );
    expect(find.byType(FloatingActionButton), findsNothing);
    final add = find.descendant(
      of: find.byType(AppBar),
      matching: find.byKey(const ValueKey('purchase-order-new')),
    );
    expect(add, findsOneWidget);
    expect(tester.widget(add), isA<FilledButton>());
    expect(
      find.descendant(of: add, matching: find.text(_en.purchaseOrderNew)),
      findsOneWidget,
    );

    await openOrder(tester, '2026-0001');
    expect(
      orderAddress(tester),
      '/money/purchase-orders/order/${orders.orders.single.id}',
    );
    expect(
      find.byKey(const ValueKey('purchase-order-print-2026-0001')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a read that failed says so with Try again and is never "no '
      'orders"; the list and an order read again', (tester) async {
    _phone(tester);
    final read = ReadProbe<List<PurchaseOrder>>();
    await tester.pumpWidget(
      purchaseOrdersApp([
        ..._space({WorkspacePermission.viewFinances}),
        purchaseOrdersProvider.overrideWith((ref, workspaceId) => read()),
      ], retryReads: false),
    );
    await tester.pump();
    read.fail(const SocketException('no route'));
    await _settle(tester);

    expect(find.byKey(const ValueKey('records-failed')), findsOneWidget);
    expect(find.text(_en.purchaseOrdersEmpty), findsNothing);
    await tester.tap(find.byKey(const ValueKey('records-retry')));
    await tester.pump();
    expect(read.calls, 2, reason: 'Try again reads the orders again');
    read.fail(const SocketException('no route'));
    await _settle(tester);

    // An order's own page, reached by its address while the read fails.
    GoRouter.of(
      tester.element(find.byType(PurchaseOrdersScreen)),
    ).go('/money/purchase-orders/order/any');
    await _settle(tester);
    expect(find.byKey(const ValueKey('read-failure')), findsOneWidget);
    expect(find.byKey(const ValueKey('purchase-order-gone')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('purchase-order-retry')));
    await tester.pump();
    expect(read.calls, 3, reason: 'Try again reads the orders again');

    // Answered without that order: the empty state, on the order's page.
    read.answer(const []);
    await _settle(tester);
    expect(find.byKey(const ValueKey('read-failure')), findsNothing);
    expect(
      tester.widget(find.byKey(const ValueKey('purchase-order-gone'))),
      isA<EmptyState>(),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('no orders yet is the empty state, not a bare sentence', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      purchaseOrdersApp([
        ..._space({WorkspacePermission.viewFinances}),
        purchaseOrdersProvider.overrideWith((ref, workspaceId) async => []),
      ]),
    );
    await _settle(tester);
    final empty = find.byKey(const ValueKey('purchase-orders-empty'));
    expect(tester.widget(empty), isA<EmptyState>());
    expect(
      find.descendant(of: empty, matching: find.text(_en.purchaseOrdersEmpty)),
      findsOneWidget,
    );
  });
}
