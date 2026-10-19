// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2576 -- typing in one asset: a row with a problem is refused in the form,
// a good one is judged by the same reader as a file, a blank figure stays
// unknown, and the staged batch carries the one row.
import 'package:deskilo/core/demo/seed/demo_valuation_seed.dart';
import 'package:deskilo/features/money/domain/asset_valuation.dart';
import 'package:deskilo/features/money/presentation/widgets/asset_valuations_sheet.dart';
import 'package:deskilo/features/money/providers/asset_valuation_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _type(WidgetTester t, String key, String text) async {
  final finder = find.byKey(ValueKey(key));
  await t.ensureVisible(finder);
  await t.enterText(finder, text);
}

void main() {
  test('a cell with a comma or a quote is quoted and read back whole', () {
    final csv = [
      valuationHeaderLine,
      [
        '1',
        'book',
        '2026-01-01',
        '2026-12-31',
        'EUR',
        '',
        '',
        '',
        '',
        '',
        '',
        'FA "1", lot 2',
      ].map(valuationCsvCell).join(','),
    ].join('\n');
    expect(readValuationCsv(csv).usable, isTrue);
  });

  testWidgets('a typed row is checked, then staged with the source named', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = seedDemoValuations(DateTime(2026, 10, 18));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [assetValuationRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AssetValuationsView(workspaceId: 'ws'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('valuation-import')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('valuation-type')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('valuation-manual-use')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('valuation-manual-invalid')),
      findsOneWidget,
    );

    await _type(tester, 'valuation-manual-asset', '7');
    await _type(tester, 'valuation-manual-from', '2027-01-01');
    await _type(tester, 'valuation-manual-to', '2027-12-31');
    await _type(tester, 'valuation-manual-currency', 'EUR');
    await _type(tester, 'valuation-manual-amount-0', '120000');
    await _type(tester, 'valuation-manual-amount-3', '24000');
    await _type(tester, 'valuation-manual-amount-5', '96000');
    await tester.tap(find.byKey(const ValueKey('valuation-manual-use')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('valuation-preview')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('valuation-source')),
      'Cabinet Martin',
    );
    await tester.tap(find.byKey(const ValueKey('valuation-stage')));
    await tester.pumpAndSettle();
    final staged = (await repo.fetchBatches('ws')).last;
    expect(staged.status, ValuationStatus.staged);
    expect(staged.rowCount, 1);
  });
}
