// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1869 B — the chart of accounts of one issuer on the legal-identity
// screen: the suggested national accounts arrive as drafts the owner
// saves, a role offers only the posting accounts of the type that fits
// it, choosing one saves a mapping from today, and a local book cannot
// be saved until customers, revenue and bank are mapped.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/data/book_profile_repository.dart';
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/providers/book_profile_providers.dart';
import 'package:deskilo/features/workspace/domain/site.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

Future<FakeBookProfileRepository> _pump(WidgetTester tester) async {
  final workspace = FakeWorkspaceRepository.withWorkspace(
    featureFlags: const {
      'moneyTab': true,
      'invoicing': true,
      'accountingBook': true,
    },
  );
  final ws = workspace.workspaces.first.id;
  workspace.sites.add(
    Site(
      id: 's1',
      workspaceId: ws,
      name: 'Atelier',
      legalId: '111',
      countryCode: 'FR',
      isDefault: true,
    ),
  );
  final books = FakeBookProfileRepository();
  await tester.binding.setSurfaceSize(const Size(800, 3000));
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
  unawaited(
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .push('/legal-identity'),
  );
  await tester.pumpAndSettle();
  return books;
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.scrollUntilVisible(
    f,
    120,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, BookRole role, String label) async {
  await _tapKey(tester, 'book-role-${role.wire}');
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('suggested drafts, typed roles, mappings from today', (
    tester,
  ) async {
    final books = await _pump(tester);
    await _tapKey(tester, 'book-chart-s1');
    await _tapKey(tester, 'book-chart-suggest');
    // FR, no VAT charged: four accounts, no output VAT.
    expect(books.accounts.map((a) => a.code), [
      '411000',
      '706000',
      '512000',
      '606000',
    ]);
    expect(
      books.accounts.every((a) => a.origin == AccountOrigin.suggested),
      isTrue,
    );

    await _tapKey(tester, 'book-role-revenue');
    expect(find.text('706000 · Prestations de services'), findsWidgets);
    expect(
      find.text('411000 · Clients'),
      findsOneWidget,
      reason: 'only the chart lists it: revenue offers income accounts',
    );
    await tester.tap(find.text('706000 · Prestations de services').last);
    await tester.pumpAndSettle();
    expect(books.mappings.single.role, BookRole.revenue);
    expect(
      books.mappings.single.accountId,
      books.accounts.firstWhere((a) => a.code == '706000').id,
    );
  });

  testWidgets('a local book waits for customers, revenue and bank', (
    tester,
  ) async {
    final books = await _pump(tester);
    await _tapKey(tester, 'book-chart-s1');
    await _tapKey(tester, 'book-chart-suggest');
    await _choose(tester, BookRole.customers, '411000 · Clients');
    await _choose(tester, BookRole.revenue, '706000 · Prestations de services');
    // Close the chart sheet.
    Navigator.of(
      tester.element(find.byKey(const ValueKey('book-account-save'))),
    ).pop();
    await tester.pumpAndSettle();

    await _tapKey(tester, 'legal-identity-book');
    await tester.tap(find.byKey(const ValueKey('book-issuer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atelier · 111').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('book-authority-local_book')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('book-unmapped')), findsOneWidget);
    expect(find.textContaining('Bank'), findsWidgets);
    final save = find.byKey(const ValueKey('book-save'));
    await tester.ensureVisible(save);
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    expect(books.saves, isEmpty);
  });
}
