// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2477 -- the platform owner's editor of the tax reference store: the
// owner sees the values in force, creates a NEW version through the form
// (the old one is closed, not edited) and reads the history; anyone else
// who opens the screen sees no value and no way to add one.
import 'package:deskilo/core/demo/data/tax_reference_repository.dart';
import 'package:deskilo/core/instance/tax_reference_bundle_asset.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/money/presentation/screens/tax_reference_screen.dart';
import 'package:deskilo/features/money/providers/tax_reference_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

FakeTaxReferenceRepository _store() => FakeTaxReferenceRepository([
      const TaxReferenceRow(
        id: 't1',
        country: 'FR',
        key: 'standard',
        validFrom: '2020-01-01',
        value: RateValue(
            label: 'Standard 20 %', percent: 20, group: 'standard', category: 'S'),
        source: 'CGI art. 278',
        confirmed: true,
      ),
    ]);

Future<void> _pump(WidgetTester tester, FakeTaxReferenceRepository store,
    {required bool owner}) async {
  await tester.binding.setSurfaceSize(const Size(800, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream.value('admin-1')),
      taxReferenceRepositoryProvider.overrideWithValue(store),
      taxReferenceBundleLoaderProvider
          .overrideWithValue(() async => const TaxReferenceSet([])),
      clockProvider.overrideWithValue(FixedClock(DateTime.utc(2026, 10, 13))),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: TaxReferenceScreen(canEdit: owner),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the owner creates a new version; the old one is closed and the history lists both',
      (tester) async {
    final store = _store();
    await _pump(tester, store, owner: true);
    expect(find.textContaining('Standard 20 %'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tax-reference-rate-FR-standard')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('tax-ref-percent')), '21');
    await tester.enterText(find.byKey(const ValueKey('tax-ref-label')), 'Standard 21 %');
    await tester.enterText(find.byKey(const ValueKey('tax-ref-valid_from')), '2027-01-01');
    await tester.enterText(find.byKey(const ValueKey('tax-ref-source')), 'Finance act 2027');
    await tester.ensureVisible(find.byKey(const ValueKey('tax-reference-save')));
    await tester.tap(find.byKey(const ValueKey('tax-reference-save')));
    await tester.pumpAndSettle();

    expect(store.rows, hasLength(2));
    expect(store.rows.first.validTo, '2027-01-01', reason: 'the version in force is closed');
    expect((store.rows.last.value as RateValue).percent, 21);
    expect(store.rows.last.source, 'Finance act 2027');
    // Today is 2026-10-13: the list still shows the version in force.
    expect(find.textContaining('Standard 20 %'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tax-reference-history-rate-FR-standard')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Standard 21 %'), findsOneWidget);
    expect(find.textContaining('until 2027-01-01'), findsOneWidget);
  });

  testWidgets('a version without a source is refused by the form', (tester) async {
    final store = _store();
    await _pump(tester, store, owner: true);
    await tester.tap(find.byKey(const ValueKey('tax-reference-rate-FR-standard')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('tax-ref-source')), '');
    await tester.enterText(find.byKey(const ValueKey('tax-ref-valid_from')), '2027-01-01');
    await tester.ensureVisible(find.byKey(const ValueKey('tax-reference-save')));
    await tester.tap(find.byKey(const ValueKey('tax-reference-save')));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsOneWidget);
    expect(store.rows, hasLength(1));
  });

  testWidgets('anyone but the platform owner sees no value and no add button',
      (tester) async {
    await _pump(tester, _store(), owner: false);
    expect(find.textContaining('Standard 20 %'), findsNothing);
    expect(find.byKey(const ValueKey('tax-reference-add')), findsNothing);
    expect(find.textContaining('Only the platform owner'), findsOneWidget);
  });

  testWidgets('the owner sees the bundled-copy notice when the server is away',
      (tester) async {
    final store = _store()..failWith = Exception('offline');
    await _pump(tester, store, owner: true);
    expect(find.textContaining('copy bundled with the app'), findsOneWidget);
  });
}
