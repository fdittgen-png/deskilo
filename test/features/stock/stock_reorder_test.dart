// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4294 (G8, client) -- the Reorder page as a person uses it, at a phone and a desk width: what is
// low, per site; what to order from whom, in the purchase unit; the items with no supplier chosen;
// a DRAFT order made once per request, only by whoever may manage purchases; and a list that could
// not be read says so, never "nothing is low".
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_ledger.dart';
import 'package:deskilo/core/demo/data/demo_stock_queries.dart';
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:deskilo/core/i18n/format_controller.dart';
import 'package:deskilo/core/ui/dropdown_field.dart';
import 'package:deskilo/features/stock/domain/stock_config.dart' show StockConfigFailure, StockConfigRefused, StockSaved;
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
  final saved = <({Map<String, Object?> point, String? id, int? rev, String request})>[];
  StockConfigFailure? failSave;
  final points_ = <StockReorderPoint>[
    StockReorderPoint(
      id: 'pt-beans', revision: 3, itemId: 'demo-item-beans', siteId: 'demo-place-main', active: true,
      reorderPoint: ExactQuantity.parse('20'), reorderQuantity: ExactQuantity.parse('25'),
    ),
    StockReorderPoint(
      id: 'pt-syrup', revision: 1, itemId: 'demo-item-syrup', siteId: 'demo-place-main', active: false,
      reorderPoint: ExactQuantity.parse('5'), targetQuantity: ExactQuantity.parse('20'),
    ),
  ];

  @override
  Future<List<StockReorderPoint>> points(String workspaceId) async {
    if (failReads) throw StateError('unreachable');
    return points_;
  }

  @override
  Future<StockSaved> savePoint(
    String workspaceId, {
    required Map<String, Object?> point,
    required String requestId,
    String? pointId,
    int? expectedRevision,
  }) async {
    if (failSave case final StockConfigFailure e) throw e;
    saved.add((point: point, id: pointId, rev: expectedRevision, request: requestId));
    return (id: pointId ?? 'pt-new', revision: (expectedRevision ?? 0) + 1, replayed: false);
  }

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

Future<void> _open(WidgetTester tester, _Reorder reorder, Size size, {Set<WorkspacePermission>? held, Locale? locale}) async {
  final config = DemoStockConfigCommands('ws-1');
  await pumpApp(
    tester,
    const StockReorderScreen(),
    size: size,
    locale: locale,
    overrides: [
      // a test that names a language also formats in it (the member's format locale)
      ...standardTestOverrides(pinFormats: locale == null),
      if (locale != null) ...[
        appFormatProvider.overrideWithValue(AppFormat(locale: locale.languageCode == 'de' ? 'de_DE' : 'en_US', currencyCode: 'EUR')),
        personalFormatProvider.overrideWithValue(AppFormat(locale: locale.languageCode == 'de' ? 'de_DE' : 'en_US', currencyCode: 'EUR')),
      ],
      stockReorderProvider.overrideWithValue(reorder),
      stockConfigCommandsProvider.overrideWithValue(config),
      stockQueriesProvider.overrideWithValue(DemoStockQueries(DemoStockLedger('ws-1', config))),
      myPermissionsProvider.overrideWithValue(
        held ?? {WorkspacePermission.viewStock, WorkspacePermission.managePurchases, WorkspacePermission.manageStock},
      ),
    ],
  );
  await _settle(tester);
}

/// The page is a lazy list: scroll until [target] is built and on screen.
Future<void> _reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 300, scrollable: find.byType(Scrollable).first);
  await tester.pump();
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

      testWidgets('the reorder points are listed with their rule; a reader who may not manage the stock cannot add or edit', (tester) async {
        await _open(tester, _Reorder(), size, held: {WorkspacePermission.viewStock});
        await _reveal(tester, find.byKey(const ValueKey('stock-point-pt-beans')));
        expect(find.byKey(const ValueKey('stock-point-pt-beans')), findsOneWidget);
        final syrup = tester.widget<ListTile>(find.byKey(const ValueKey('stock-point-pt-syrup')));
        expect((syrup.subtitle! as Text).data, contains(_en.stockReorderRuleTarget(_en.stockQuantityWithUnit('20', 'l'))));
        expect((syrup.subtitle! as Text).data, contains(_en.stockReorderPointInactive));
        expect(find.byKey(const ValueKey('stock-point-add')), findsNothing);
      });

      // #4425 -- a level typed with the member's decimal separator: 15,5 in German and 15.5 in English save the same
      for (final (code, typed, saved) in [('de', '15,5', '15.5'), ('en', '15.5', '15.5'), ('de', '1.234,5', '1234.5'), ('en', '1,234.5', '1234.5')]) {
        testWidgets('a level typed $typed in $code is saved as $saved', (tester) async {
          final reorder = _Reorder();
          await _open(tester, reorder, size, locale: Locale(code));
          await _reveal(tester, find.byKey(const ValueKey('stock-point-pt-beans')));
          await tester.tap(find.byKey(const ValueKey('stock-point-pt-beans')));
          await _settle(tester);
          await tester.enterText(find.byKey(const ValueKey('stock-point-level')), typed);
          await tester.tap(find.byKey(const ValueKey('stock-point-save')));
          await _settle(tester);
          expect(reorder.saved.single.point['reorder_point'], saved);
        });
      }

      testWidgets('a point is changed at the revision read; its item and site are fixed', (tester) async {
        final reorder = _Reorder();
        await _open(tester, reorder, size);
        await _reveal(tester, find.byKey(const ValueKey('stock-point-pt-beans')));
        await tester.tap(find.byKey(const ValueKey('stock-point-pt-beans')));
        await _settle(tester);
        expect(tester.widget<AppDropdownField<String>>(find.byKey(const ValueKey('stock-point-item'))).onChanged, isNull,
            reason: 'the item is fixed once the point exists');
        await tester.enterText(find.byKey(const ValueKey('stock-point-level')), '15,5');
        await tester.tap(find.byKey(const ValueKey('stock-point-save')));
        await _settle(tester);
        final save = reorder.saved.single;
        expect((save.id, save.rev), ('pt-beans', 3), reason: 'the revision that was read');
        expect(save.point['reorder_point'], '15.5', reason: 'a decimal comma is read as the server reads it');
        expect(save.point['reorder_quantity'], '25');
        expect(save.point.containsKey('item_id'), isFalse);
      });

      testWidgets('a new point names its item and site; a mistake is said under its field and nothing is sent', (tester) async {
        final reorder = _Reorder();
        await _open(tester, reorder, size);
        await _reveal(tester, find.byKey(const ValueKey('stock-point-add')));
        await tester.tap(find.byKey(const ValueKey('stock-point-add')));
        await _settle(tester);
        await tester.tap(find.byKey(const ValueKey('stock-point-save')));
        await _settle(tester);
        expect(reorder.saved, isEmpty, reason: 'no item, no site, no level: nothing is sent');
        expect(find.text(_en.stockReasonItemForeign), findsOneWidget);
        expect(find.text(_en.stockReasonSiteUnknown), findsOneWidget);
        expect(find.text(_en.stockReasonQuantityInvalid), findsOneWidget);
      });

      testWidgets('a level to order up to that is not above the point is refused before it is sent', (tester) async {
        final reorder = _Reorder();
        await _open(tester, reorder, size);
        await _reveal(tester, find.byKey(const ValueKey('stock-point-pt-beans')));
        await tester.tap(find.byKey(const ValueKey('stock-point-pt-beans')));
        await _settle(tester);
        await tester.tap(find.text(_en.stockReorderPointModeTarget));
        await _settle(tester);
        await tester.enterText(find.byKey(const ValueKey('stock-point-value')), '10');
        await tester.tap(find.byKey(const ValueKey('stock-point-save')));
        await _settle(tester);
        expect(reorder.saved, isEmpty);
        expect(find.text(_en.stockReasonTargetBelowPoint), findsOneWidget);
      });

      testWidgets('a refusal of the server is said under the sheet and the sheet stays', (tester) async {
        final reorder = _Reorder()..failSave = const StockConfigRefused('item_id', 'point_twice');
        await _open(tester, reorder, size);
        await _reveal(tester, find.byKey(const ValueKey('stock-point-pt-beans')));
        await tester.tap(find.byKey(const ValueKey('stock-point-pt-beans')));
        await _settle(tester);
        await tester.tap(find.byKey(const ValueKey('stock-point-save')));
        await _settle(tester);
        expect(find.text(_en.stockReasonPointTwice), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-point-save')), findsOneWidget);
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
