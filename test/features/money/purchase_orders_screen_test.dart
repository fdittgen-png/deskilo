// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — the purchase orders screen: a buyer (managePurchases) drafts a
// new order through the form (each problem under its field first), marks a
// draft sent and cancels it with a reason; a finance reader sees the same
// list and its print, nothing else.
import 'package:deskilo/core/demo/data/purchase_order_repository.dart';
import 'package:deskilo/core/demo/data/supplier_repository.dart';
import 'package:deskilo/core/ui/kit/status_chip.dart';
import 'package:deskilo/features/money/domain/line_unit.dart';
import 'package:deskilo/features/money/domain/purchase_order.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:deskilo/features/money/presentation/widgets/purchase_order_record.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/pickable_units_provider.dart';
import 'package:deskilo/features/money/providers/purchase_order_providers.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart' show VatRate;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/purchase_orders_app.dart';

const _workspace = Workspace(
  id: 'ws',
  name: 'Space',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'x',
);

/// The list, the order's form and the order's record, at the addresses
/// the app gives them (#3608, #3842).
Widget _scope(List<Override> overrides) => purchaseOrdersApp(overrides);

Future<(FakePurchaseOrderRepository, Widget)> _app(
  Set<WorkspacePermission> permissions, {
  List<ServiceItem> items = const [],
  List<Override> extra = const [],
}) async {
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
      servicesProvider.overrideWith((ref) async => items),
      ...extra,
      pickableUnitsProvider.overrideWith(
        (ref, workspaceId) => const [LineUnit(code: 'piece'), LineUnit(code: 'kg'), LineUnit(code: 'h')],
      ),
      vatRatesProvider.overrideWith(
        (ref) async => const [
          VatRate(id: 'r-std', label: 'Standard', percent: 20),
          VatRate(id: 'r-red', label: 'Reduced', percent: 5.5),
        ],
      ),
    ]),
  );
}

/// Opens the picker under [key] and chooses the option whose text starts with [option].
Future<void> _pick(WidgetTester tester, String key, String option) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining(option).last);
  await tester.pumpAndSettle();
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
    // #3842 — at the desk the order is a row of the table.
    expect(find.byKey(const ValueKey('records-rows')), findsOneWidget);
    expect(find.text('2026-0001'), findsOneWidget);

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
    await _pick(tester, 'purchase-order-vat-0', 'Reduced');
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

    // The order's actions are in its record, beside the table.
    await openOrder(tester, '2026-0001');
    expect(
      find.byKey(const ValueKey('purchase-order-panel-2026-0001')),
      findsOneWidget,
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
    await openOrder(tester, '2026-0001');
    expect(
      find.byKey(const ValueKey('purchase-order-panel-2026-0001')),
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

  testWidgets('#3730 — an order in a state a newer server sent is read with '
      'its text and allows nothing, even to a buyer', (tester) async {
    final (orders, app) = await _app({WorkspacePermission.managePurchases});
    final seeded = orders.orders.single;
    orders.orders[0] = PurchaseOrder.fromJson({
      'id': seeded.id,
      'reference': seeded.reference,
      'supplier_id': seeded.supplierId,
      'supplier_name': seeded.supplierName,
      'state': 'future_locked',
      'currency': 'EUR',
      'revision': 3,
      'lines': [
        {
          'line_no': 1,
          'description': 'Paper towels',
          'quantity': 12,
          'unit_price_cents': 150,
        },
      ],
    });
    expect(orders.orders.single.state, PurchaseOrderState.unknown);
    expect(orders.orders.single.state.open, isFalse);
    await tester.pumpWidget(app);
    await _settle(tester);
    await openOrder(tester, '2026-0001');

    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('future_locked', findRichText: true),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('purchase-order-print-2026-0001')),
      findsOneWidget,
    );
    for (final action in const ['edit', 'sent', 'cancel', 'receive', 'email']) {
      expect(
        find.byKey(ValueKey('purchase-order-$action-2026-0001')),
        findsNothing,
        reason: 'an unknown state allows no $action',
      );
    }
  });

  testWidgets('#3842 — an order opens beside the table at its own address; '
      'the form pushed over the list is never read as an order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (orders, app) = await _app({WorkspacePermission.managePurchases});
    await tester.pumpWidget(app);
    await _settle(tester);
    final id = orders.orders.single.id;
    final panel = find.byKey(const ValueKey('purchase-order-panel-2026-0001'));

    // #4492 — the state is a word on its tone, in the table and on the record
    // (beside an open order the table keeps only its staying columns).
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('records-rows')),
        matching: find.widgetWithText(
          StatusChip,
          AppLocalizationsEn().purchasesStateDraft,
        ),
      ),
      findsOneWidget,
    );

    await openOrder(tester, '2026-0001');
    expect(orderAddress(tester), '/money/purchase-orders/order/$id');
    expect(panel, findsOneWidget);
    expect(
      tester.widget(
        find.byKey(const ValueKey('purchase-order-state-2026-0001')),
      ),
      isA<StatusChip>(),
    );
    expect(find.byKey(const ValueKey('records-rows')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('records-total-EUR')),
      findsOneWidget,
      reason: 'one total per currency, under the table',
    );

    await tester.tap(find.byKey(const ValueKey('purchase-order-close')));
    await _settle(tester);
    expect(orderAddress(tester), '/money/purchase-orders');
    expect(panel, findsNothing);

    await tester.tap(find.byKey(const ValueKey('purchase-order-new')));
    await _settle(tester);
    expect(orderAddress(tester), '/money/purchase-orders/new');
    expect(find.byKey(const ValueKey('purchase-order-gone')), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is PurchaseOrderRecord),
      findsNothing,
      reason: '"new" is the form, never an order',
    );
    expect(tester.takeException(), isNull);
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
      await _pick(tester, 'purchase-order-vat-0', 'Reduced');
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
      // The footer's two buttons do not fit side by side in the test
      // font at this width: they stack, and nothing overflows.
      expect(tester.takeException(), isNull);
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
      await openOrder(tester, '2026-0001');
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
      // Back on the order beside the table, the page gone.
      expect(save, findsNothing);
      expect(
        find.byKey(const ValueKey('purchase-order-panel-2026-0001')),
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

  // #4471 -- a unit and a VAT rate are picked from the master data, never typed.
  for (final (label, size) in [('390 wide', const Size(390, 900)), ('1440 wide', const Size(1440, 900))]) {
    group('the unit and the VAT rate of a line are picked ($label)', () {
      testWidgets('a new line offers pickers, no text field, and saves what was picked', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (orders, app) = await _app({WorkspacePermission.managePurchases});
        await tester.pumpWidget(app);
        await _settle(tester);
        await tester.tap(find.byKey(const ValueKey('purchase-order-new')));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        for (final key in ['purchase-order-unit-0', 'purchase-order-vat-0']) {
          expect(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(TextField)), findsNothing, reason: '$key is not typed');
        }
        await tester.tap(find.byKey(const ValueKey('purchase-order-supplier')));
        await _settle(tester);
        await tester.tap(find.textContaining('Alpha').last);
        await _settle(tester);
        await tester.enterText(find.byKey(const ValueKey('purchase-order-desc-0')), 'Coffee beans');
        await tester.enterText(find.byKey(const ValueKey('purchase-order-qty-0')), '5');
        await tester.enterText(find.byKey(const ValueKey('purchase-order-price-0')), '12,50');
        await _pick(tester, 'purchase-order-unit-0', 'kg');
        await _pick(tester, 'purchase-order-vat-0', 'Reduced');
        await tester.ensureVisible(find.byKey(const ValueKey('purchase-order-save')));
        await tester.tap(find.byKey(const ValueKey('purchase-order-save')));
        await _settle(tester);
        final line = orders.orders.last.lines.single;
        expect((line.unit, line.vatRatePercent), ('kg', 5.5));
      });

      testWidgets('a line that names a stocked item starts in the unit the supplier sells it in, and offers only what it converts from', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (_, app) = await _app(
          {WorkspacePermission.managePurchases},
          items: const [ServiceItem(id: 'mugs', workspaceId: 'ws', name: 'Mugs', priceCents: 100, active: true)],
          extra: [
            itemOrderUnitsProvider.overrideWith(
              (ref, key) async => const ItemOrderUnits(units: [LineUnit(code: 'piece'), LineUnit(code: 'kg')], defaultUnit: 'kg'),
            ),
          ],
        );
        await tester.pumpWidget(app);
        await _settle(tester);
        await tester.tap(find.byKey(const ValueKey('purchase-order-new')));
        await _settle(tester);
        await _pick(tester, 'purchase-order-item-0', 'Mugs');
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.descendant(of: find.byKey(const ValueKey('purchase-order-unit-0')), matching: find.text('kg')), findsWidgets);
      });

      testWidgets('an old free unit and percent are shown, flagged, and must be replaced before saving', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (orders, app) = await _app({WorkspacePermission.managePurchases});
        final first = orders.orders.single;
        await orders.save(
          'ws',
          'old-free',
          PurchaseOrderDraft(
            supplierId: first.supplierId,
            lines: const [
              PurchaseOrderLineDraft(description: 'Old line', quantity: 1, unitPriceCents: 100, unit: 'box', vatRatePercent: 55),
            ],
          ),
        );
        await tester.pumpWidget(app);
        await _settle(tester);
        await openOrder(tester, '2026-0002');
        await tester.tap(find.byKey(const ValueKey('purchase-order-edit-2026-0002')));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('box'), findsOneWidget);
        expect(find.textContaining('55'), findsWidgets);
        for (final key in ['purchase-order-unit-0', 'purchase-order-vat-0']) {
          await tester.ensureVisible(find.byKey(ValueKey(key)));
          await tester.pump();
          expect(
            find.descendant(of: find.byKey(ValueKey(key)), matching: find.text('This is not in the list: pick one')),
            findsOneWidget,
            reason: '$key is flagged',
          );
        }
        await tester.ensureVisible(find.byKey(const ValueKey('purchase-order-save')));
        await tester.tap(find.byKey(const ValueKey('purchase-order-save')));
        await _settle(tester);
        expect(orders.orders.last.lines.single.unit, 'box', reason: 'nothing was saved');
        await _pick(tester, 'purchase-order-unit-0', 'kg');
        await _pick(tester, 'purchase-order-vat-0', 'Standard');
        expect(find.text('This is not in the list: pick one'), findsNothing);
        await tester.ensureVisible(find.byKey(const ValueKey('purchase-order-save')));
        await tester.tap(find.byKey(const ValueKey('purchase-order-save')));
        await _settle(tester);
        final line = orders.orders.last.lines.single;
        expect((line.unit, line.vatRatePercent), ('kg', 20));
      });
    });
  }
}
