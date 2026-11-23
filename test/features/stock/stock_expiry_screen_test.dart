// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4431 (G17) -- the expiry report as a person uses it, on the Demo's lots and pieces, at a phone and a desk width: what expired
// and what expires come in date order with how far each is from the date; a scope narrows the list; a place and a horizon
// narrow it too; a list with nothing says so; a failed read says so and reads again; the report prints through the report engine.
import 'package:deskilo/core/demo/data/demo_stock_expiry.dart';
import 'package:deskilo/core/demo/data/demo_stock_tags.dart';
import 'package:deskilo/features/stock/domain/stock_expiry.dart';
import 'package:deskilo/features/stock/presentation/stock_expiry_printer.dart';
import 'package:deskilo/features/stock/presentation/stock_expiry_screen.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

/// The report of the Demo's lots on the test clock's day (the lots' dates are relative to it).
DemoStockExpiry _demo() => DemoStockExpiry(() => kTestNow, DemoStockTags());

class _Printer implements StockExpiryPrinter {
  final printed = <({ExpiryReport report, ExpiryQuery query})>[];

  @override
  Future<void> print(BuildContext context, WidgetRef ref, {required ExpiryReport report, required ExpiryQuery query}) async {
    printed.add((report: report, query: query));
  }
}

/// A report that cannot be read the first time.
class _Flaky implements StockExpiry {
  _Flaky(this._inner);

  final StockExpiry _inner;
  int reads = 0;

  @override
  Future<ExpiryReport> report(String workspaceId, ExpiryQuery query, {int maxRows = 2000}) =>
      ++reads == 1 ? Future.error(Exception('down')) : _inner.report(workspaceId, query, maxRows: maxRows);
}

Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _open(WidgetTester tester, Size size, {StockExpiry? expiry, StockExpiryPrinter? printer}) async {
  await pumpApp(
    tester,
    // a scope of its own: the standard one already wires the app's printer
    ProviderScope(
      overrides: [
        stockExpiryReportProvider.overrideWith((ref, key) => (expiry ?? _demo()).report(key.workspaceId, key.query)),
        stockExpiryPrinterProvider.overrideWithValue(printer),
      ],
      child: const StockExpiryScreen(),
    ),
    size: size,
    overrides: standardTestOverrides(),
  );
  await _frames(tester);
}

void main() {
  for (final (name, size) in [('a phone', const Size(390, 844)), ('a desk', const Size(1440, 900))]) {
    group('on $name', () {
      testWidgets('what expired and what expires, by date, each with how far it is from the date', (tester) async {
        await _open(tester, size);
        // today's reference is the test clock's day: only the order and the words are asserted, not the Demo's offsets
        expect(find.byKey(const ValueKey('stock-expiry-row-0')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-expiry-empty')), findsNothing);
        expect(find.textContaining('MILK-09'), findsOneWidget, reason: 'the milk that expired');
        expect(find.textContaining('BASKET-1'), findsNWidgets(5), reason: 'the basket is listed piece by piece');
        expect(find.text(_en.stockExpiryDaysPast('6')), findsOneWidget);
      });

      testWidgets('a scope narrows the list: only what expired', (tester) async {
        await _open(tester, size);
        await tester.tap(find.byKey(const ValueKey('stock-expiry-scope')));
        await _frames(tester);
        await tester.tap(find.text(_en.stockExpiryScopeExpired).last);
        await _frames(tester);
        expect(find.textContaining('MILK-09'), findsOneWidget);
        expect(find.textContaining('BASKET-1'), findsNothing);
      });

      testWidgets('a horizon too short for anything says nothing is expiring', (tester) async {
        await _open(tester, size);
        await tester.tap(find.byKey(const ValueKey('stock-expiry-scope')));
        await _frames(tester);
        await tester.tap(find.text(_en.stockExpiryScopeExpiring).last);
        await _frames(tester);
        await tester.enterText(find.byKey(const ValueKey('stock-expiry-horizon')), '1');
        await _frames(tester);
        expect(find.byKey(const ValueKey('stock-expiry-empty')), findsOneWidget);
      });

      testWidgets('a failed read says so and reads again', (tester) async {
        final flaky = _Flaky(_demo());
        await _open(tester, size, expiry: flaky);
        expect(find.byKey(const ValueKey('stock-expiry-failed')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('stock-expiry-retry')));
        await _frames(tester);
        expect(find.byKey(const ValueKey('stock-expiry-failed')), findsNothing);
        expect(find.byKey(const ValueKey('stock-expiry-row-0')), findsOneWidget);
        expect(flaky.reads, 2);
      });

      testWidgets('the report prints through the report engine, for the question asked', (tester) async {
        final printer = _Printer();
        await _open(tester, size, printer: printer);
        await tester.tap(find.byKey(const ValueKey('stock-expiry-print')));
        await _frames(tester);
        expect(printer.printed, hasLength(1));
        expect(printer.printed.single.report.rows, isNotEmpty);
        expect(printer.printed.single.query.scope, ExpiryScope.both);
      });

      testWidgets('with no printer wired there is no print button', (tester) async {
        await _open(tester, size);
        expect(find.byKey(const ValueKey('stock-expiry-print')), findsNothing);
      });
    });
  }

  test('the Demo lists what expired, then what expires, by date then place; a place keeps its own', () async {
    final all = await _demo().report('ws', const ExpiryQuery());
    expect(all.rows.map((r) => r.days), [...all.rows.map((r) => r.days)]..sort());
    expect(all.rows.where((r) => r.days < 0).map((r) => r.lotCode), ['MILK-09', 'APPLES-OLD']);
    final main = await _demo().report('ws', const ExpiryQuery(locationId: 'demo-place-main'));
    expect(main.rows.map((r) => r.lotCode), ['MILK-09', 'MILK-12']);
  });
}
