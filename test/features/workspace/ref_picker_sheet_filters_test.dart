// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant: with a long list of invoices the picker narrows in one tap by
// status (counts shown), offers person / month / type / amount in an advanced
// panel whose button says how many results it gives, shows what is on as
// removable chips, sorts, groups by month, and clears — and a short list or
// a list without facets keeps the plain sheet.
import 'package:deskilo/features/workspace/presentation/widgets/ref_picker_sheet.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _facets = [
  RefFacet(key: 'status', label: 'Status', quick: true),
  RefFacet(key: 'person', label: 'Person'),
  RefFacet(key: 'month', label: 'Month'),
];

List<RefCandidate> _invoices() => [
  for (var i = 0; i < 12; i++)
    refCandidate(
      id: 'inv$i',
      label: 'INV-${100 + i} · ${i.isEven ? 'Ana' : 'Ben'}',
      icon: Icons.receipt_long_outlined,
      amountCents: (i + 1) * 1000,
      at: DateTime(2026, i < 6 ? 9 : 10, 1 + i),
      facets: {
        'status': i % 3 == 0
            ? (id: 'paid', label: 'Paid')
            : (id: 'open', label: 'Open (unpaid)'),
        'person': i.isEven
            ? (id: 'ana', label: 'Ana')
            : (id: 'ben', label: 'Ben'),
        'month': i < 6
            ? (id: '2026-09', label: '2026-09')
            : (id: '2026-10', label: '2026-10'),
      },
    ),
];

Future<void> _open(
  WidgetTester tester,
  List<RefCandidate> c, {
  List<RefFacet> facets = _facets,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showRefPicker(
                context,
                title: 'Which invoice?',
                candidates: c,
                keyPrefix: 'p',
                facets: facets,
                formatAmount: (cents) => '${cents ~/ 100} €',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

int _rows(WidgetTester tester) => find
    .byWidgetPredicate((w) => w is ListTile && '${w.key}'.contains("'p-inv"))
    .evaluate()
    .length;

void main() {
  testWidgets('quick chips narrow by status and show the counts', (
    tester,
  ) async {
    await _open(tester, _invoices());
    expect(_rows(tester), 12);
    // 4 paid (0,3,6,9), 8 open.
    expect(find.text('All · 12'), findsOneWidget);
    expect(find.text('Paid · 4'), findsOneWidget);
    expect(find.text('Open (unpaid) · 8'), findsOneWidget);

    await tester.tap(find.byKey(const Key('p-quick-open')));
    await tester.pumpAndSettle();
    expect(_rows(tester), 8);
    await tester.tap(find.byKey(const Key('p-quick-all')));
    await tester.pumpAndSettle();
    expect(_rows(tester), 12);
  });

  testWidgets('the advanced panel narrows by person and says how many', (
    tester,
  ) async {
    await _open(tester, _invoices());
    await tester.tap(find.byKey(const Key('p-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('p-facet-person-ana')));
    await tester.pumpAndSettle();
    // Ana has the even ones: 6.
    expect(find.text('Show 6 results'), findsOneWidget);
    await tester.tap(find.byKey(const Key('p-apply')));
    await tester.pumpAndSettle();
    expect(_rows(tester), 6);
    // What is on shows as a removable chip, and the button wears a count.
    expect(find.byKey(const Key('p-active-person-ana')), findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byKey(const Key('p-active-person-ana')),
        matching: find.byTooltip('Delete')));
    await tester.pumpAndSettle();
    expect(_rows(tester), 12);
  });

  testWidgets('sorting by amount and clearing every filter', (tester) async {
    await _open(tester, _invoices());
    await tester.tap(find.byKey(const Key('p-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Highest amount'));
    await tester.pumpAndSettle();
    final first = tester
        .widgetList<ListTile>(
          find.byWidgetPredicate(
            (w) => w is ListTile && '${w.key}'.contains("'p-inv"),
          ),
        )
        .first;
    expect('${first.key}', contains('inv11'));

    await tester.tap(find.byKey(const Key('p-quick-paid')));
    await tester.pumpAndSettle();
    expect(_rows(tester), 4);
    await tester.tap(find.byKey(const Key('p-clear')));
    await tester.pumpAndSettle();
    expect(_rows(tester), 12);
  });

  testWidgets('rows are grouped under their month while sorted by date', (
    tester,
  ) async {
    await _open(tester, _invoices());
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('September 2026'), findsOneWidget);
  });

  testWidgets('a list without facets keeps the plain sheet', (tester) async {
    await _open(tester, [
      for (var i = 0; i < 10; i++)
        refCandidate(id: 'inv$i', label: 'Seat $i', icon: Icons.chair_outlined),
    ], facets: const []);
    expect(find.byKey(const Key('p-filter')), findsOneWidget);
    expect(find.byKey(const Key('p-more')), findsNothing);
    expect(find.byKey(const Key('p-sort')), findsNothing);
  });
}
