// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4294 (G8, client) -- the Reorder page as a person uses it, at a phone and a desk width: what is
// low, per site; what to order from whom, in the purchase unit; the items with no supplier chosen;
// a DRAFT order made once per request, only by whoever may manage purchases; and a list that could
// not be read says so, never "nothing is low".
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_config.dart' show StockConfigFailure, StockConfigRefused;
import 'package:deskilo/features/stock/domain/stock_reorder.dart';
import 'package:deskilo/features/stock/presentation/stock_reorder_screen.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

class _Reorder implements StockReorder {
  bool failReads = false;
  StockConfigFailure? failDraft;
  final drafts = <({String supplier, List<String> items, String request})>[];

  @override
  Future<List<StockLowRow>> low(String workspaceId, {String? siteId}) async {
    if (failReads) throw StateError('unreachable');
    return [
      StockLowRow(
        pointId: 'p-beans', itemId: 'i-beans', itemName: 'Coffee beans', unit: 'kg', siteId: 's-main', siteCode: 'MAIN',
        onHand: ExactQuantity.parse('12.5'), reorderPoint: ExactQuantity.parse('20'), proposed: ExactQuantity.parse('25'),
      ),
      StockLowRow(
        pointId: 'p-syrup', itemId: 'i-syrup', itemName: 'Syrup', unit: 'l', siteId: 's-main', siteCode: 'MAIN',
        onHand: ExactQuantity.parse('1'), reorderPoint: ExactQuantity.parse('5'), proposed: ExactQuantity.parse('19'),
      ),
    ];
  }

  @override
  Future<ReplenishmentList> replenishment(String workspaceId, {String? siteId}) async {
    if (failReads) throw StateError('unreachable');
    return ReplenishmentList(
      groups: [
        ReplenishmentGroup(
          supplierId: 'sup-1',
          supplierName: 'Café Import',
          lines: [
            ReplenishmentLine(
              pointId: 'p-beans', itemId: 'i-beans', itemName: 'Coffee beans', siteCode: 'MAIN',
              articleRef: 'BEANS-5KG', unit: 'bag', quantity: ExactQuantity.parse('5'),
            ),
          ],
        ),
      ],
      noSupplier: [
        ReplenishmentGap(
          itemId: 'i-syrup', itemName: 'Syrup', siteCode: 'MAIN', unit: 'l', quantity: ExactQuantity.parse('19'),
        ),
      ],
    );
  }

  @override
  Future<ReplenishmentDraft> createDraft(
    String workspaceId, {
    required String supplierId,
    required List<ReplenishmentLine> lines,
    required String requestId,
  }) async {
    if (failDraft case final StockConfigFailure e) throw e;
    drafts.add((supplier: supplierId, items: [for (final l in lines) l.itemId], request: requestId));
    return (orderId: 'o-1', number: 'DRAFT-7');
  }
}

Future<void> _open(WidgetTester tester, _Reorder reorder, Size size, {Set<WorkspacePermission>? held}) async {
  await pumpApp(
    tester,
    const StockReorderScreen(),
    size: size,
    overrides: [
      ...standardTestOverrides(),
      stockReorderProvider.overrideWithValue(reorder),
      myPermissionsProvider.overrideWithValue(
        held ?? {WorkspacePermission.viewStock, WorkspacePermission.managePurchases},
      ),
    ],
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  for (final (name, size) in [('phone', const Size(390, 844)), ('desk', const Size(1440, 900))]) {
    group('on a $name', () {
      testWidgets('the low items show their site, what is on hand and the reorder point', (tester) async {
        await _open(tester, _Reorder(), size);
        final beans = tester.widget<ListTile>(find.byKey(const ValueKey('stock-low-p-beans')));
        expect(
          (beans.subtitle! as Text).data,
          _en.stockReorderLowRow('MAIN', _en.stockQuantityWithUnit('12.5', 'kg'), _en.stockQuantityWithUnit('20', 'kg')),
        );
        expect(find.byKey(const ValueKey('stock-low-p-syrup')), findsOneWidget);
      });

      testWidgets('what to order is grouped by supplier, in the purchase unit, and the item with no supplier chosen is told',
          (tester) async {
        await _open(tester, _Reorder(), size);
        expect(find.text('Café Import'), findsOneWidget);
        expect(
          find.text(_en.stockReorderGroupLine('Coffee beans', _en.stockQuantityWithUnit('5', 'bag'), 'MAIN')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('stock-reorder-no-supplier')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-gap-i-syrup-MAIN')), findsOneWidget);
      });

      testWidgets('a draft order is made from a group, once per request, and nothing is said to be sent', (tester) async {
        final reorder = _Reorder();
        await _open(tester, reorder, size);
        await tester.ensureVisible(find.byKey(const ValueKey('stock-order-draft-sup-1')));
        await tester.tap(find.byKey(const ValueKey('stock-order-draft-sup-1')));
        await _settle(tester);
        expect(reorder.drafts.single.supplier, 'sup-1');
        expect(reorder.drafts.single.items, ['i-beans']);
        expect(reorder.drafts.single.request, isNotEmpty);
        expect(find.text(_en.stockReorderDraftCreated('DRAFT-7')), findsOneWidget);
      });

      testWidgets('a draft asked again later is a new request; a retry after a refusal is the same one', (tester) async {
        final reorder = _Reorder();
        await _open(tester, reorder, size);
        await tester.ensureVisible(find.byKey(const ValueKey('stock-order-draft-sup-1')));
        await tester.tap(find.byKey(const ValueKey('stock-order-draft-sup-1')));
        await _settle(tester);
        await tester.tap(find.byKey(const ValueKey('stock-order-draft-sup-1')));
        await _settle(tester);
        expect(reorder.drafts.length, 2);
        expect(reorder.drafts[0].request, isNot(reorder.drafts[1].request), reason: 'a draft made renews the request');
        reorder.failDraft = const StockConfigRefused('lines[0]', 'mapping_unknown');
        await tester.tap(find.byKey(const ValueKey('stock-order-draft-sup-1')));
        await _settle(tester);
        reorder.failDraft = null;
        await tester.tap(find.byKey(const ValueKey('stock-order-draft-sup-1')));
        await _settle(tester);
        expect(reorder.drafts.length, 3);
        expect(reorder.drafts[2].request, isNot(reorder.drafts[1].request));
      });

      testWidgets('a refused draft says why and makes nothing', (tester) async {
        final reorder = _Reorder()..failDraft = const StockConfigRefused('lines[0]', 'mapping_unknown');
        await _open(tester, reorder, size);
        await tester.ensureVisible(find.byKey(const ValueKey('stock-order-draft-sup-1')));
        await tester.tap(find.byKey(const ValueKey('stock-order-draft-sup-1')));
        await _settle(tester);
        expect(reorder.drafts, isEmpty);
        expect(find.text(_en.stockReasonMappingUnknown), findsOneWidget);
      });

      testWidgets('a reader who may not buy sees the lists and no draft button', (tester) async {
        await _open(tester, _Reorder(), size, held: {WorkspacePermission.viewStock});
        expect(find.byKey(const ValueKey('stock-low-p-beans')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-order-draft-sup-1')), findsNothing);
      });

      testWidgets('a list that could not be read says so, with a retry, never "nothing is low"', (tester) async {
        final reorder = _Reorder()..failReads = true;
        await _open(tester, reorder, size);
        expect(find.byKey(const ValueKey('stock-reorder-low-failed')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-reorder-order-failed')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-reorder-low-empty')), findsNothing);
        reorder.failReads = false;
        await tester.tap(find.byKey(const ValueKey('stock-reorder-low-retry')));
        await _settle(tester);
        expect(find.byKey(const ValueKey('stock-low-p-beans')), findsOneWidget);
      });
    });
  }
}
