// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — goods receipts: a delivery is checked before it is recorded (a
// sent order, something brought, never more than what is left, never after
// today); the Demo records it by pgTAP 361's rules (partly received, then
// received; a stale revision, a draft and a replay); a buyer records one on
// the order's card, a finance reader only reads what arrived; the server's
// answer and the deliveries parse.
import 'package:deskilo/core/demo/data/purchase_order_repository.dart';
import 'package:deskilo/core/demo/data/purchase_repository.dart';
import 'package:deskilo/core/demo/data/supplier_repository.dart';
import 'package:deskilo/core/demo/seed/demo_purchase_order_seed.dart';
import 'package:deskilo/core/features/enabled_feature_keys.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/money/domain/purchase_order.dart';
import 'package:deskilo/features/money/domain/purchase_order_receipt.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:deskilo/features/money/presentation/widgets/purchases_sheet.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/purchase_order_providers.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
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
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../helpers/screens/purchase_orders_app.dart';

final _today = DateTime(2026, 11, 4);

const _workspace = Workspace(
  id: 'ws',
  name: 'Space',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'x',
);

/// An order of 100 capsules and 12 rolls to Alpha, sent unless [draft].
Future<(FakePurchaseOrderRepository, FakeSupplierRepository)> _orders({
  bool draft = false,
}) async {
  final suppliers = FakeSupplierRepository();
  final alpha = await suppliers.save('ws', const SupplierDraft(name: 'Alpha'));
  final repo = FakePurchaseOrderRepository(
    suppliers: () => suppliers.suppliers,
    services: () => const [],
    now: () => _today,
  );
  final o = await repo.save(
    'ws',
    'seed',
    PurchaseOrderDraft(
      supplierId: alpha,
      lines: const [
        PurchaseOrderLineDraft(
          description: 'Capsules',
          quantity: 100,
          unitPriceCents: 25,
        ),
        PurchaseOrderLineDraft(
          description: 'Rolls',
          quantity: 12,
          unitPriceCents: 150,
        ),
      ],
    ),
  );
  if (!draft) await repo.markSent('ws', o.id, o.revision, 'sent');
  return (repo, suppliers);
}

Widget _scope(List<Override> overrides, Widget home) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: home),
  ),
);

Widget _app(
  FakePurchaseOrderRepository repo,
  FakeSupplierRepository s,
  Set<WorkspacePermission> rights,
) => purchaseOrdersApp([
  currentWorkspaceProvider.overrideWith((ref) async => _workspace),
  myMemberProvider.overrideWith((ref) async => null),
  myPermissionsProvider.overrideWithValue(rights),
  enabledFeaturesSyncProvider.overrideWithValue({
    WorkspaceFeature.purchases,
    WorkspaceFeature.purchaseOrders,
  }),
  supplierRepositoryProvider.overrideWithValue(s),
  purchaseOrderRepositoryProvider.overrideWithValue(repo),
  servicesProvider.overrideWith((ref) async => const <ServiceItem>[]),
  clockProvider.overrideWithValue(FixedClock(_today)),
]);

PurchaseOrderReceiptDraft _delivery(
  PurchaseOrder order,
  Map<int, double> quantities, {
  DateTime? on,
}) => PurchaseOrderReceiptDraft(
  order: order,
  receivedOn: on ?? _today,
  quantities: quantities,
);

void main() {
  group('a delivery is checked first', () {
    test(
      'a sent order, something brought, within what is left, by today',
      () async {
        final (repo, _) = await _orders();
        final o = repo.orders.single;
        expect(_delivery(o, {1: 60}).problemsOn(_today), isEmpty);
        expect(_delivery(o, {1: 0}).problemsOn(_today), [
          PurchaseOrderReceiptProblem.nothing,
        ]);
        expect(_delivery(o, {1: 101}).problemsOn(_today), [
          PurchaseOrderReceiptProblem.tooMany,
        ]);
        expect(
          _delivery(o, {
            1: 1,
          }, on: _today.add(const Duration(days: 1))).problemsOn(_today),
          [PurchaseOrderReceiptProblem.future],
        );
        expect(_delivery(o, {1: 60, 2: 0}).toLines(), [
          {'line_no': 1, 'quantity': 60.0},
        ]);
      },
    );

    test('a draft receives nothing', () async {
      final (repo, _) = await _orders(draft: true);
      expect(
        _delivery(repo.orders.single, {1: 1}).problemsOn(_today),
        contains(PurchaseOrderReceiptProblem.notReceivable),
      );
    });
  });

  group('the Demo records by pgTAP 361', () {
    test('partly received, then received; what arrived counts', () async {
      final (repo, _) = await _orders();
      var o = await repo.recordReceipt(
        'ws',
        'r1',
        _delivery(repo.orders.single, {1: 60}),
      );
      expect(o.state, PurchaseOrderState.partlyReceived);
      expect(o.lines.first.receivedQuantity, 60);
      expect(_delivery(o, {1: 41}).problemsOn(_today), [
        PurchaseOrderReceiptProblem.tooMany,
      ], reason: 'what arrived before counts against what was ordered');
      final replay = await repo.recordReceipt(
        'ws',
        'r1',
        _delivery(o, {1: 60}),
      );
      expect(replay.revision, o.revision, reason: 'the same request replays');
      expect(repo.receipts, hasLength(1));
      o = await repo.recordReceipt('ws', 'r2', _delivery(o, {1: 40, 2: 12}));
      expect(o.state, PurchaseOrderState.received);
      expect(o.receivable, isFalse);
      expect(
        (await repo.fetchReceipts('ws')).map((r) => r.lines),
        containsAll([
          {1: 60.0},
          {1: 40.0, 2: 12.0},
        ]),
      );
    });

    test('a stale revision and a draft are refused', () async {
      final (repo, _) = await _orders();
      final sent = repo.orders.single;
      await repo.recordReceipt('ws', 'r1', _delivery(sent, {1: 1}));
      await expectLater(
        repo.recordReceipt('ws', 'r2', _delivery(sent, {1: 1})),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '40001'),
        ),
      );
      final (drafts, _) = await _orders(draft: true);
      await expectLater(
        drafts.recordReceipt(
          'ws',
          'r3',
          _delivery(drafts.orders.single, {1: 1}),
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('a bill names a sent order, never a draft', () async {
      final (repo, _) = await _orders();
      await repo.linkBill('ws', 'bill-1', repo.orders.single.id);
      expect(repo.billOrders, {'bill-1': repo.orders.single.id});
      await repo.linkBill('ws', 'bill-1', null);
      expect(repo.billOrders, isEmpty);
      final (drafts, _) = await _orders(draft: true);
      await expectLater(
        drafts.linkBill('ws', 'bill-2', drafts.orders.single.id),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  test('the Demo seeds what arrived: one order in two deliveries, one '
      'partly received', () async {
    final suppliers = FakeSupplierRepository();
    await suppliers.save('ws', const SupplierDraft(name: 'Alpha'));
    await suppliers.save('ws', const SupplierDraft(name: 'Beta'));
    final repo = FakePurchaseOrderRepository(
      suppliers: () => suppliers.suppliers,
      services: () => const [],
      now: () => _today,
    );
    seedDemoPurchaseOrders(repo, _today);
    expect(repo.receipts, hasLength(3));
    for (final o in repo.orders) {
      final arrived = <int, double>{};
      for (final r in repo.receipts.where((r) => r.orderId == o.id)) {
        r.lines.forEach((n, q) => arrived[n] = (arrived[n] ?? 0) + q);
      }
      for (final l in o.lines) {
        expect(l.receivedQuantity, arrived[l.lineNo] ?? 0, reason: o.reference);
      }
    }
    expect(
      repo.orders.map((o) => o.state),
      containsAll([
        PurchaseOrderState.received,
        PurchaseOrderState.partlyReceived,
      ]),
    );
    expect(repo.receipts.every((r) => !r.receivedOn.isAfter(_today)), isTrue);
  });

  test('a delivery parses with its line numbers', () {
    final r = PurchaseOrderReceipt.fromJson({
      'id': 'r',
      'order_id': 'o',
      'received_on': '2026-11-01',
      'note': 'short',
      'purchase_order_receipt_lines': [
        {
          'quantity': 6,
          'purchase_order_lines': {'line_no': 2},
        },
      ],
    });
    expect((r.receivedOn, r.note), (DateTime(2026, 11), 'short'));
    expect(r.lines, {2: 6.0});
  });

  group('the order card', () {
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('a buyer records a partial delivery; too many is refused '
        'under its line', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (repo, suppliers) = await _orders();
      await tester.pumpWidget(
        _app(repo, suppliers, {WorkspacePermission.managePurchases}),
      );
      await settle(tester);
      // #3842 — at the desk the order's receipt is in its record.
      await openOrder(tester, '2026-0001');
      expect(find.text('Capsules: 0 of 100 received'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('purchase-order-receive-2026-0001')),
      );
      await settle(tester);
      await tester.enterText(
        find.byKey(const ValueKey('purchase-order-receive-line-1')),
        '101',
      );
      await tester.tap(
        find.byKey(const ValueKey('purchase-order-receive-confirm')),
      );
      await settle(tester);
      expect(find.text('More than what is left of this line'), findsWidgets);
      expect(repo.receipts, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('purchase-order-receive-line-1')),
        '60',
      );
      await tester.enterText(
        find.byKey(const ValueKey('purchase-order-receive-line-2')),
        '',
      );
      await tester.tap(
        find.byKey(const ValueKey('purchase-order-receive-confirm')),
      );
      await settle(tester);
      expect(repo.receipts.single.lines, {1: 60.0});
      expect(repo.orders.single.state, PurchaseOrderState.partlyReceived);
      expect(find.text('Capsules: 60 of 100 received'), findsOneWidget);
    });

    testWidgets('a finance reader reads what arrived and records nothing', (
      tester,
    ) async {
      final (repo, suppliers) = await _orders();
      await tester.pumpWidget(
        _app(repo, suppliers, {WorkspacePermission.viewFinances}),
      );
      await settle(tester);
      expect(find.text('Rolls: 0 of 12 received'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('purchase-order-receive-2026-0001')),
        findsNothing,
      );
    });
  });

  testWidgets('the bill dialog picks a sent order, takes its amounts and '
      'names it on the bill', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (orders, suppliers) = await _orders();
    final bills = FakePurchaseRepository();
    await tester.pumpWidget(
      _scope(
        [
          purchaseRepositoryProvider.overrideWithValue(bills),
          supplierRepositoryProvider.overrideWithValue(suppliers),
          purchaseOrderRepositoryProvider.overrideWithValue(orders),
          enabledFeatureKeysProvider.overrideWithValue({purchaseOrdersKey}),
        ],
        const SingleChildScrollView(
          child: PurchasesView(workspaceId: 'ws', canCapture: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('purchase-add-bill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('purchase-order-link')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('2026-0001').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('purchase-gross')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      '43',
    );
    // The order's supplier is taken with it.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('purchase-supplier')),
        matching: find.textContaining('Alpha'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('purchase-save')));
    await tester.pumpAndSettle();
    final bill = (await bills.fetchPurchases('ws')).single;
    expect(orders.billOrders, {bill.id: orders.orders.single.id});
  });
}
