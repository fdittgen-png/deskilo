// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1869 C — the book and chart sheets in all five languages and at twice
// the text size, on a phone: each opens with its own words and nothing
// overflows. And a workspace with no profile is pre-accounting, with
// nothing written to make it so.
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

const _titles = {
  'en': 'Accounting book',
  'fr': 'Livre comptable',
  'de': 'Buchführung',
  'es': 'Libro contable',
  'it': 'Libro contabile',
};

Future<FakeBookProfileRepository> _pump(
  WidgetTester tester, {
  required String locale,
  double textScale = 1,
}) async {
  final workspace = FakeWorkspaceRepository.withWorkspace(
    featureFlags: const {
      'moneyTab': true,
      'invoicing': true,
      'accountingBook': true,
    },
  );
  final ws = workspace.workspaces.first;
  tester.platformDispatcher.localesTestValue = [Locale(locale)];
  tester.platformDispatcher.localeTestValue = Locale(locale);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  workspace.sites.add(
    Site(
      id: 's1',
      workspaceId: ws.id,
      name: 'Atelier',
      legalId: '111',
      countryCode: 'FR',
      isDefault: true,
    ),
  );
  final books = FakeBookProfileRepository();
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          workspace: workspace,
          deviceLocale: Locale(locale),
        ),
        bookProfileRepositoryProvider.overrideWithValue(books),
      ],
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: const DeskiloApp(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  unawaited(
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .push('/legal-identity'),
  );
  await tester.pumpAndSettle();
  return books;
}

Future<void> _open(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.scrollUntilVisible(
    f,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  for (final MapEntry(key: locale, value: title) in _titles.entries) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$locale at ${scale}x: both sheets open, nothing overflows', (
        tester,
      ) async {
        final books = await _pump(tester, locale: locale, textScale: scale);
        await _open(tester, 'legal-identity-book');
        expect(find.text(title), findsWidgets);
        expect(tester.takeException(), isNull);
        Navigator.of(tester.element(find.byKey(const ValueKey('book-save'))))
            .pop();
        await tester.pumpAndSettle();
        await _open(tester, 'book-chart-s1');
        expect(
          find.byKey(const ValueKey('book-chart-suggest')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        expect(books.saves, isEmpty, reason: 'opening writes nothing');
      });
    }
  }

  test('no profile is pre-accounting, and deciding so writes nothing', () {
    final books = FakeBookProfileRepository();
    expect(
      authorityOn(books.profiles, 's1', DateTime(2026, 10, 2)),
      BookAuthority.preAccounting,
    );
    expect(books.saves, isEmpty);
  });
}
