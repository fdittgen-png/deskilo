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

Future<FakeBookProfileRepository> _pump(
  WidgetTester tester, {
  List<(String, String, AccountType)> accounts = const [],
}) async {
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
  final books = FakeBookProfileRepository()
    ..accounts.addAll([
      for (final (code, name, type) in accounts)
        BookAccount(
          id: 'acc-$code',
          workspaceId: ws,
          issuerSiteId: 's1',
          code: code,
          name: name,
          type: type,
          isPosting: true,
          origin: AccountOrigin.manual,
          revision: 1,
        ),
    ]);
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
  testWidgets('the suggested chart is taken mapped; a role re-points from '
      'today (#2365)', (tester) async {
    final books = await _pump(tester);
    await _tapKey(tester, 'book-chart-s1');
    await _tapKey(tester, 'book-chart-suggest');
    // FR, no VAT charged: no tax account.
    expect(books.accounts.map((a) => a.code), [
      '411000',
      '706000',
      '512000',
      '606000',
      '401000',
      '654000',
    ]);
    expect(
      books.accounts.every((a) => a.origin == AccountOrigin.suggested),
      isTrue,
    );
    String codeOf(BookRole role) => books.accounts
        .firstWhere(
          (a) => a.id == books.mappings.firstWhere((m) => m.role == role).accountId,
        )
        .code;
    expect(
      {for (final m in books.mappings) m.role: codeOf(m.role)},
      {
        BookRole.customers: '411000',
        BookRole.revenue: '706000',
        BookRole.bank: '512000',
        BookRole.expenses: '606000',
        BookRole.suppliers: '401000',
        BookRole.writeOff: '654000',
      },
    );

    await _tapKey(tester, 'book-role-revenue');
    expect(
      find.text('411000 · Clients'),
      findsNWidgets(2),
      reason: 'the chart and the customers role show it: revenue offers '
          'income accounts only',
    );
    await tester.tap(find.text('706000 · Prestations de services').last);
    await tester.pumpAndSettle();
    expect(
      books.mappings.where((m) => m.role == BookRole.revenue).single.revision,
      2,
      reason: 'the same day corrects its version, never a second one',
    );
  });

  testWidgets('a local book waits for customers, revenue and bank', (
    tester,
  ) async {
    final books = await _pump(
      tester,
      accounts: [
        ('411000', 'Clients', AccountType.asset),
        ('706000', 'Prestations de services', AccountType.income),
      ],
    );
    await _tapKey(tester, 'book-chart-s1');
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
