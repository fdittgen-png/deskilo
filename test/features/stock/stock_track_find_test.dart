// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4436 -- finding a sale from a track ID, by the screens, on a phone (390) and on a desk (1440), over the Demo's own
// adapters: the till sells two litres of oat milk, which takes lot MILK-12 and freezes it on the line; the Stock page's
// Find opens a search where the lot code, typed in any case, names the lot and that sale, and the sale opens what its
// line took (the lot with its quantity). A piece is found by its tag; a code nothing carries says so; an empty code is
// said under the field; a reader who may not see the money reads the sale as a receipt they may not see and cannot open
// it; a reader who may not read the stock is offered no search and is refused by the read; a failed read says so and
// the retry finds the lot.
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_expiry.dart';
import 'package:deskilo/core/demo/data/demo_stock_ledger.dart';
import 'package:deskilo/core/demo/data/demo_stock_queries.dart';
import 'package:deskilo/core/demo/data/demo_stock_tags.dart';
import 'package:deskilo/core/demo/data/demo_stock_trace_chain.dart';
import 'package:deskilo/core/demo/data/demo_stock_track_find.dart';
import 'package:deskilo/core/demo/data/demo_till.dart';
import 'package:deskilo/features/money/domain/counter_till.dart';
import 'package:deskilo/features/stock/domain/stock_track_find.dart';
import 'package:deskilo/features/stock/presentation/stock_screen.dart';
import 'package:deskilo/features/stock/presentation/stock_track_find_sheet.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();
final _now = DateTime(2026, 11, 24, 10);
const _ws = 'ws-1';

const _owner = {
  WorkspacePermission.viewStock,
  WorkspacePermission.manageStock,
  WorkspacePermission.viewFinances,
};

class _World {
  _World(this.held) {
    final tags = DemoStockTags();
    ledger = DemoStockLedger(_ws, DemoStockConfigCommands(_ws));
    till = DemoTill(
      country: 'FR',
      currency: 'EUR',
      vatPercent: 20,
      clock: () => _now,
    );
    finder = DemoStockTrackFind(
      ledger,
      DemoStockExpiry(() => _now, tags),
      tags,
      sold: () => till.soldLines,
      held: () => held,
    );
  }

  final Set<WorkspacePermission> held;
  late final DemoStockLedger ledger;
  late final DemoTill till;
  late final StockTrackFinder finder;

  /// The counter sells two litres of oat milk: the line takes lot MILK-12 (the Demo's first lot that has not expired).
  Future<void> sellMilk() async {
    final draft = await till.draft(
      _ws,
      requestId: 'draft-1',
      lines: const [
        TillLine(
          itemId: 'demo-item-milk',
          name: 'Oat milk',
          quantity: '2',
          unit: 'l',
        ),
      ],
    );
    await till.finalize(
      _ws,
      requestId: 'sale-1',
      receiptId: draft.receiptId,
      expectedRevision: draft.revision,
      tenders: [TillTender(kind: 'cash', amountMinor: draft.totals.grossMinor)],
    );
  }
}

/// A finder whose next read fails once, as a dropped connection does.
class _Flaky implements StockTrackFinder {
  _Flaky(this._inner);

  final StockTrackFinder _inner;
  bool fail = true;

  @override
  Future<TrackFindAnswer> find(String workspaceId, String code) async {
    if (fail) {
      fail = false;
      throw Exception('the connection dropped');
    }
    return _inner.find(workspaceId, code);
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _openStock(
  WidgetTester tester,
  _World w,
  Size size, {
  StockTrackFinder? finder,
}) async {
  await pumpApp(
    tester,
    const StockScreen(),
    size: size,
    overrides: [
      ...standardTestOverrides(),
      stockQueriesProvider.overrideWithValue(DemoStockQueries(w.ledger)),
      stockTrackFinderProvider.overrideWithValue(finder ?? w.finder),
      stockTraceChainReaderProvider.overrideWithValue(
        DemoStockTraceChain(w.ledger, sold: () => w.till.soldLines),
      ),
      myPermissionsProvider.overrideWithValue(w.held),
    ],
  );
  await _settle(tester);
}

Future<void> _find(WidgetTester tester, String code) async {
  await tester.tap(find.byKey(const ValueKey('stock-track-find-open')));
  await _settle(tester);
  await tester.enterText(
    find.byKey(const ValueKey('stock-track-find-code')),
    code,
  );
  await tester.tap(find.byKey(const ValueKey('stock-track-find-submit')));
  await _settle(tester);
}

void main() {
  for (final (name, size) in [
    ('phone', const Size(390, 844)),
    ('desk', const Size(1440, 900)),
  ]) {
    group('on a $name', () {
      testWidgets(
        'the lot code finds the lot and the sale that took it, and the sale opens what its line took',
        (tester) async {
          final w = _World(_owner);
          await w.sellMilk();
          await _openStock(tester, w, size);
          await _find(tester, 'milk-12');

          expect(
            find.byKey(const ValueKey('stock-track-lot-demo-lot-MILK-12')),
            findsOneWidget,
          );
          expect(
            find.text('Oat milk · ${_en.stockLotLabel('MILK-12')}'),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('stock-track-lot-demo-lot-MILK-09')),
            findsNothing,
            reason: 'another lot of the item',
          );
          final sale = find.byKey(const ValueKey('stock-track-sale-0'));
          expect(
            find.descendant(
              of: sale,
              matching: find.text('${_en.stockChainReceipt('R-00001')} · 2'),
            ),
            findsOneWidget,
          );

          await tester.ensureVisible(sale);
          await tester.tap(sale);
          await _settle(tester);
          expect(find.text(_en.stockChainSaleTitle), findsOneWidget);
          expect(
            find.text(_en.stockChainTookLot('MILK-12', '2')),
            findsOneWidget,
          );
        },
      );

      testWidgets('a tag finds its piece, which no sale took yet', (
        tester,
      ) async {
        final w = _World(_owner);
        await _openStock(tester, w, size);
        await _find(tester, 'e2:80:11:60:60:00:02:05:4a:f3:e0:02');

        expect(
          find.byKey(const ValueKey('stock-track-piece-demo-piece-2')),
          findsOneWidget,
        );
        expect(
          find.text('Gift basket · E2801160600002054AF3E002'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('stock-track-find-no-sale')),
          findsOneWidget,
        );
      });

      testWidgets(
        'a code nothing carries says so, and an empty code is said under the field',
        (tester) async {
          final w = _World(_owner);
          await _openStock(tester, w, size);
          await _find(tester, '   ');
          expect(find.text(_en.stockTrackFindRequired), findsOneWidget);
          expect(
            find.byKey(const ValueKey('stock-track-find-none')),
            findsNothing,
          );

          await tester.enterText(
            find.byKey(const ValueKey('stock-track-find-code')),
            'NOPE-1',
          );
          await tester.tap(
            find.byKey(const ValueKey('stock-track-find-submit')),
          );
          await _settle(tester);
          expect(find.text(_en.stockTrackFindNone('NOPE-1')), findsOneWidget);
          expect(
            find.byKey(const ValueKey('stock-track-find-found')),
            findsNothing,
          );
        },
      );

      testWidgets(
        'a reader who may not see the money reads the sale as a receipt they may not see, and cannot open it',
        (tester) async {
          final w = _World({WorkspacePermission.viewStock});
          await w.sellMilk();
          await _openStock(tester, w, size);
          await _find(tester, 'MILK-12');

          final sale = find.byKey(const ValueKey('stock-track-sale-0'));
          expect(
            find.descendant(
              of: sale,
              matching: find.text('${_en.stockChainUnavailable} · 2'),
            ),
            findsOneWidget,
          );
          expect(
            find.textContaining('R-00001'),
            findsNothing,
            reason: 'the receipt is not named to this reader',
          );
          await tester.ensureVisible(sale);
          await tester.tap(sale);
          await _settle(tester);
          expect(
            find.text(_en.stockChainSaleTitle),
            findsNothing,
            reason: 'what the line took needs the receipt',
          );
        },
      );

      testWidgets('a member who may not read the stock is offered no search', (
        tester,
      ) async {
        final w = _World(const {});
        await _openStock(tester, w, size);
        expect(
          find.byKey(const ValueKey('stock-track-find-open')),
          findsNothing,
        );
      });

      testWidgets(
        'a member who may not read the stock is refused by the read, never told nothing was found',
        (tester) async {
          final w = _World(const {});
          await pumpApp(
            tester,
            const Scaffold(
              body: SingleChildScrollView(
                child: StockTrackFind(workspaceId: _ws),
              ),
            ),
            size: size,
            overrides: [
              ...standardTestOverrides(),
              stockTrackFinderProvider.overrideWithValue(w.finder),
            ],
          );
          await _settle(tester);
          await tester.enterText(
            find.byKey(const ValueKey('stock-track-find-code')),
            'MILK-12',
          );
          await tester.tap(
            find.byKey(const ValueKey('stock-track-find-submit')),
          );
          await _settle(tester);
          expect(
            find.byKey(const ValueKey('stock-track-find-failed')),
            findsOneWidget,
          );
          expect(find.text(_en.refusalPermission), findsOneWidget);
          expect(
            find.byKey(const ValueKey('stock-track-find-none')),
            findsNothing,
            reason: 'a refusal is never "nothing found"',
          );
        },
      );

      testWidgets('a read that fails says so, and the retry finds the lot', (
        tester,
      ) async {
        final w = _World(_owner);
        await _openStock(tester, w, size, finder: _Flaky(w.finder));
        await _find(tester, 'MILK-12');
        expect(find.text(_en.stockReadFailed), findsOneWidget);
        expect(
          find.byKey(const ValueKey('stock-track-find-none')),
          findsNothing,
        );

        await tester.tap(find.byKey(const ValueKey('stock-track-find-retry')));
        await _settle(tester);
        expect(
          find.byKey(const ValueKey('stock-track-lot-demo-lot-MILK-12')),
          findsOneWidget,
        );
      });
    });
  }
}
