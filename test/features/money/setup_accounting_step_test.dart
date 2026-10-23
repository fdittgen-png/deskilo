// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2875 — the accounting step of the setup guide. The form is the legal
// identity screen's own books section, so a version is saved through the
// book profile command its sheet uses; the accounting periods are offered
// only while they are on. The preview says what the books will show: with
// no version, pre-accounting, as the server reads it; for each issuer, by
// its site's name, the version in force today — who keeps the books, the
// fiscal year it gives, when income counts, the currency — and the
// accounts a local book still waits for. One column on a phone.
import 'package:deskilo/app/routes/setup_grow_pages.dart';
import 'package:deskilo/core/demo/data/book_profile_repository.dart';
import 'package:deskilo/features/money/domain/book_profile.dart';
import 'package:deskilo/features/money/providers/book_profile_providers.dart';
import 'package:deskilo/features/workspace/domain/site.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_step_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _phone = Size(360, 2400);

BookProfile _book(
  String site,
  BookAuthority authority, {
  String system = '',
  int month = 1,
  AccountingBasis basis = AccountingBasis.accrual,
}) => BookProfile(
  id: 'b-$site',
  workspaceId: 'ws-1',
  issuerSiteId: site,
  authority: authority,
  externalSystem: system,
  functionalCurrency: 'EUR',
  fiscalYearStartMonth: month,
  fiscalYearStartDay: 1,
  basis: basis,
  effectiveFrom: DateTime(2026),
  revision: 1,
);

Future<FakeBookProfileRepository> _pump(
  WidgetTester tester, {
  List<BookProfile> profiles = const [],
  Map<String, dynamic> flags = const {},
}) async {
  final workspace = FakeWorkspaceRepository.withWorkspace(featureFlags: flags)
    ..sites.addAll(const [
      Site(id: 's1', workspaceId: 'ws-1', name: 'Atelier', isDefault: true),
      Site(id: 's2', workspaceId: 'ws-1', name: 'Annexe'),
    ]);
  final books = FakeBookProfileRepository()..profiles.addAll(profiles);
  await pumpApp(
    tester,
    const SetupStepScreen(stepId: 'accounting', growPages: setupGrowPages),
    size: _phone,
    overrides: [
      ...standardTestOverrides(workspace: workspace),
      bookProfileRepositoryProvider.overrideWithValue(books),
    ],
  );
  await tester.pumpAndSettle();
  return books;
}

Finder _inPreview(Finder f) => find.descendant(
  of: find.byKey(const ValueKey('setup-step-preview')),
  matching: f,
);

void main() {
  testWidgets('no book: pre-accounting; a version saved through the sheet '
      'shows the books it gives', (tester) async {
    final books = await _pump(tester);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('setup-accounting-pre')))
          .data,
      'No book set: DesKilo keeps member balances and invoices '
      '(pre-accounting).',
    );
    expect(find.byKey(const ValueKey('book-periods-button')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('legal-identity-book')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('book-issuer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atelier').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('book-save')));
    await tester.pumpAndSettle();

    expect(books.saves.single.issuerSiteId, 's1');
    expect(find.byKey(const ValueKey('setup-accounting-pre')), findsNothing);
    final issuer = find.byKey(const ValueKey('setup-accounting-issuer-s1'));
    expect(
      find.descendant(of: issuer, matching: find.text('Atelier')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: issuer,
        matching: find.text(
          'DesKilo keeps the member balances and the invoices; nothing is '
          'posted to a ledger.',
        ),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('setup-step-one-column')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a local and an external book: who keeps each, the fiscal '
      'year, when income counts, the currency, the accounts still unmapped', (
    tester,
  ) async {
    await _pump(
      tester,
      profiles: [
        _book('s1', BookAuthority.localBook),
        _book(
          's2',
          BookAuthority.externalBook,
          system: 'DATEV',
          month: 7,
          basis: AccountingBasis.cash,
        ),
      ],
    );
    final local = find.byKey(const ValueKey('setup-accounting-issuer-s1'));
    for (final line in [
      'Atelier',
      'DesKilo keeps the books: invoices and payments are posted to the '
          'chart of accounts.',
      'Fiscal year 2026: Jan 1, 2026 – Dec 31, 2026',
      'Income counts when it is invoiced.',
      'Amounts are kept in EUR.',
    ]) {
      expect(
        find.descendant(of: local, matching: find.text(line)),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(
        of: local,
        matching: find.byKey(const ValueKey('setup-accounting-unmapped')),
      ),
      findsOneWidget,
      reason: 'no account is mapped in the fixture',
    );

    final external = find.byKey(const ValueKey('setup-accounting-issuer-s2'));
    for (final line in [
      'Annexe',
      'DATEV keeps the official books; what DesKilo shows is derived and '
          'says so.',
      // kTestNow is in May 2026: the year from July began in 2025.
      'Fiscal year 2025/26: Jul 1, 2025 – Jun 30, 2026',
      'Income counts when it is paid.',
    ]) {
      expect(
        find.descendant(of: external, matching: find.text(line)),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(
        of: external,
        matching: find.byKey(const ValueKey('setup-accounting-unmapped')),
      ),
      findsNothing,
    );
    expect(
      _inPreview(find.byKey(const ValueKey('setup-accounting-pre'))),
      findsNothing,
    );
  });

  testWidgets('the accounting periods are offered while they are on', (
    tester,
  ) async {
    await _pump(
      tester,
      flags: const {'accountingBook': true, 'accountingPeriods': true},
    );
    expect(find.byKey(const ValueKey('book-periods-button')), findsOneWidget);
  });
}
