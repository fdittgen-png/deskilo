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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

const _workspace = Workspace(
  id: 'ws',
  name: 'Space',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'x',
);

Widget _scope(List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: PurchaseOrdersScreen(),
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
}
