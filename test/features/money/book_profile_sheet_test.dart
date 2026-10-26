// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1869 — the accounting book on the legal-identity screen: hidden with
// the flag off; on, an owner picks the issuer (two of the same name are
// told apart by their registration), the authority, the fiscal year,
// sees the year it gives, cannot save an external book with no system
// named, saves a version, and is told — without anything overwritten —
// when someone saved the same version first.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/data/book_profile_repository.dart';
import 'package:deskilo/features/money/domain/book_profile.dart';
import 'package:deskilo/features/money/providers/book_profile_providers.dart';
import 'package:deskilo/features/workspace/domain/site.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

const _flags = {'moneyTab': true, 'invoicing': true, 'accountingBook': true};

BookProfile _profile(String ws, int revision) => BookProfile(
  id: 'b1',
  workspaceId: ws,
  issuerSiteId: 's1',
  authority: BookAuthority.localBook,
  externalSystem: '',
  functionalCurrency: 'EUR',
  fiscalYearStartMonth: 1,
  fiscalYearStartDay: 1,
  basis: AccountingBasis.accrual,
  effectiveFrom: DateTime(2026),
  revision: revision,
);

Future<({FakeBookProfileRepository books, String ws})> _pump(
  WidgetTester tester, {
  Map<String, dynamic> flags = _flags,
  bool seeded = false,
  BookProfile Function(String ws)? seed,
}) async {
  final workspace = FakeWorkspaceRepository.withWorkspace(featureFlags: flags);
  final ws = workspace.workspaces.first.id;
  workspace.sites.addAll(
    const [
      Site(
        id: 's1',
        workspaceId: 'ws',
        name: 'Atelier',
        legalId: '111',
        isDefault: true,
      ),
      Site(id: 's2', workspaceId: 'ws', name: 'Atelier', legalId: '222'),
    ].map(
      (s) => Site(
        id: s.id,
        workspaceId: ws,
        name: s.name,
        legalId: s.legalId,
        isDefault: s.isDefault,
      ),
    ),
  );
  final books = FakeBookProfileRepository();
  if (seeded) books.profiles.add(_profile(ws, 1));
  if (seed != null) books.profiles.add(seed(ws));
  await tester.binding.setSurfaceSize(const Size(800, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(workspace: workspace),
        bookProfileRepositoryProvider.overrideWithValue(books),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(Scaffold).first);
  unawaited(GoRouter.of(context).push('/legal-identity'));
  await tester.pumpAndSettle();
  return (books: books, ws: ws);
}

Future<void> _openBook(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('legal-identity-book')),
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('legal-identity-book')));
  await tester.pumpAndSettle();
}

Future<void> _pickIssuer(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const ValueKey('book-issuer')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('flag off: no book on the screen', (tester) async {
    await _pump(tester, flags: const {'moneyTab': true, 'invoicing': true});
    expect(find.byKey(const ValueKey('legal-identity-book')), findsNothing);
  });

  testWidgets('pick the issuer, see the fiscal year, save a version', (
    tester,
  ) async {
    final books = (await _pump(tester)).books;
    expect(
      find.textContaining('pre-accounting'),
      findsOneWidget,
      reason: 'with no book, the screen says what DesKilo then is',
    );
    await _openBook(tester);
    // Two issuers named Atelier, told apart by their registration.
    await _pickIssuer(tester, 'Atelier · 222');
    await tester.tap(
      find.byKey(const ValueKey('book-authority-external_book')),
    );
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('book-save'));
    expect(
      tester.widget<FilledButton>(save).onPressed,
      isNull,
      reason: 'an external book names its system first',
    );
    // The software is picked from the list, never typed.
    await tester.ensureVisible(find.byKey(const ValueKey('book-external')));
    await tester.tap(find.byKey(const ValueKey('book-external')));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('DATEV Rechnungswesen').last);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('book-fiscal-month')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('July').last);
    await tester.pumpAndSettle();
    // The clock is kTestNow; the year that day falls in is shown.
    expect(find.byKey(const ValueKey('book-preview')), findsOneWidget);
    expect(find.textContaining('Fiscal year 20'), findsOneWidget);
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    final saved = books.saves.single;
    expect(saved.issuerSiteId, 's2');
    expect(saved.authority, BookAuthority.externalBook);
    expect(saved.externalSystem, 'DATEV Rechnungswesen');
    expect(saved.fiscalYearStartMonth, 7);
    expect(saved.revision, 0, reason: 'a new version');
    expect(books.profiles.single.revision, 1);
    expect(
      find.byKey(
        ValueKey('book-version-s2-${saved.toJson()['effective_from']}'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a version saved meanwhile is not overwritten', (tester) async {
    final r = await _pump(tester, seeded: true);
    final tile = find.byKey(const ValueKey('book-version-s1-2026-01-01'));
    await tester.scrollUntilVisible(
      tile,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    // Someone else saves the same version while the sheet is open.
    r.books.profiles[0] = _profile(r.ws, 2);
    await tester.tap(
      find.byKey(const ValueKey('book-authority-pre_accounting')),
    );
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('book-save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(r.books.saves.single.revision, 1, reason: 'it sent what it read');
    expect(r.books.profiles.single.revision, 2);
    expect(
      r.books.profiles.single.authority,
      BookAuthority.localBook,
      reason: 'nothing was overwritten',
    );
    expect(find.textContaining('Someone saved this book'), findsOneWidget);
  });

  testWidgets('a software the catalogue does not offer here stays listed '
      'and is saved unchanged', (tester) async {
    // A DE space whose books are kept in Holded (an ES product).
    final r = await _pump(
      tester,
      seed: (ws) => BookProfile(
        id: 'b1',
        workspaceId: ws,
        issuerSiteId: 's1',
        authority: BookAuthority.externalBook,
        externalSystem: 'Holded',
        functionalCurrency: 'EUR',
        fiscalYearStartMonth: 1,
        fiscalYearStartDay: 1,
        basis: AccountingBasis.accrual,
        effectiveFrom: DateTime(2026),
        revision: 1,
      ),
    );
    final tile = find.byKey(const ValueKey('book-version-s1-2026-01-01'));
    await tester.scrollUntilVisible(
      tile,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(tile);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Holded'), findsOneWidget, reason: 'listed, selected');
    expect(find.byKey(const ValueKey('book-external-other')), findsNothing);
    final save = find.byKey(const ValueKey('book-save'));
    await tester.ensureVisible(save);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(save);
    await tester.pump(const Duration(seconds: 1));
    expect(r.books.saves.single.externalSystem, 'Holded');
  });

  testWidgets('"Other…" reveals the field for a software the list lacks; '
      'the app\'s exports and the authorities are no software', (
    tester,
  ) async {
    final books = (await _pump(tester)).books;
    await _openBook(tester);
    await _pickIssuer(tester, 'Atelier · 222');
    await tester.tap(
      find.byKey(const ValueKey('book-authority-external_book')),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.byKey(const ValueKey('book-external')));
    await tester.tap(find.byKey(const ValueKey('book-external')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('DesKilo General ledger'), findsNothing);
    expect(find.text('BMF GoBD Datenträgerüberlassung'), findsNothing);
    expect(find.text('OECD SAF-T'), findsNothing);
    await tester.tap(find.text('Other…').last);
    await tester.pump(const Duration(seconds: 1));
    final other = find.byKey(const ValueKey('book-external-other'));
    expect(other, findsOneWidget);
    await tester.enterText(other, 'Holded');
    await tester.pump();
    final save = find.byKey(const ValueKey('book-save'));
    await tester.ensureVisible(save);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(save);
    await tester.pump(const Duration(seconds: 1));
    expect(books.saves.single.externalSystem, 'Holded');
  });
}
