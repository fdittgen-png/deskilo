// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3556 (part 2) — My finances: an invoice of business A in euros and one of
// business B in francs are filed in one group of mine; the group narrows
// the lists to them and its header says how many and what they come to,
// one total per currency and no combined figure. An invoice the group names
// that cannot be read now is named, left out of the totals, and can be
// removed. A group is renamed and deleted; a name is used once.
import 'package:deskilo/core/demo/data/account_activity_repository.dart';
import 'package:deskilo/core/demo/data/invoice_group_repository.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:deskilo/features/money/domain/invoice_groups.dart';
import 'package:deskilo/features/money/presentation/screens/my_finances_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/screens/my_finances_screen.dart' show invoice;

const _home = '11111111-1111-4111-8111-111111111111';

final _overview = FinanceOverview(
  invoices: [
    invoice('a', ws: 'Atelier', total: 12000),
    invoice('b', ws: 'Limmat', total: 8400, currency: 'CHF'),
    invoice('c', ws: 'Quai', total: 3000),
  ],
);

Future<FakeInvoiceGroupRepository> _show(
  WidgetTester tester, {
  FakeInvoiceGroupRepository? groups,
  String? home = _home,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = groups ?? FakeInvoiceGroupRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        auth: FakeAuthRepository.signedIn(),
        accountActivity: FakeAccountActivityRepository()
          ..financeOverview = _overview,
        invoiceGroups: repo,
        homeInstallation: home,
      ),
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MyFinancesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _closeSheet(WidgetTester tester) async {
  await tester.tapAt(const Offset(400, 20));
  await tester.pumpAndSettle();
}

Finder _inHeader(Finder f) => find.descendant(
  of: find.byKey(const ValueKey('finances-group-header')),
  matching: f,
);

void main() {
  testWidgets('an EUR invoice of A and a CHF invoice of B in one group: two '
      'totals, no combined figure, the lists narrowed to them', (tester) async {
    final repo = await _show(tester);
    expect(
      find.byKey(const ValueKey('finances-group-filter-group-1')),
      findsNothing,
      reason: 'no group yet',
    );

    await tester.tap(find.byKey(const ValueKey('finances-group-a')));
    await tester.pumpAndSettle();
    expect(find.text('Groups of INV-a'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('invoice-group-new-name')),
      '  To reimburse ',
    );
    await tester.tap(find.byKey(const ValueKey('invoice-group-create')));
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('invoice-group-toggle-group-1'));
    expect(
      tester.widget<CheckboxListTile>(toggle).value,
      isTrue,
      reason: 'created and filed in one step',
    );
    await _closeSheet(tester);

    await tester.tap(find.byKey(const ValueKey('finances-group-b')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('invoice-group-toggle-group-1')),
    );
    await tester.pumpAndSettle();
    await _closeSheet(tester);
    final stored = (await repo.groups()).single;
    expect(stored.name, 'To reimburse');
    expect(stored.items.map((i) => (i.ref.networkId, i.number)), [
      ('$_home:ws-Atelier', 'INV-a'),
      ('$_home:ws-Limmat', 'INV-b'),
    ]);

    await tester.tap(
      find.byKey(const ValueKey('finances-group-filter-group-1')),
    );
    await tester.pumpAndSettle();
    expect(_inHeader(find.text('2 invoices')), findsOneWidget);
    final totals = tester
        .widget<Text>(find.byKey(const ValueKey('finances-group-totals')))
        .data!;
    expect(totals.split(' · '), hasLength(2), reason: 'one total per currency');
    expect(
      totals,
      allOf(contains('CHF'), contains('84.00'), contains('120.00')),
    );
    expect(
      totals,
      isNot(contains('204')),
      reason: 'never one figure across currencies',
    );
    expect(find.byKey(const ValueKey('finances-invoice-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('finances-invoice-b')), findsOneWidget);
    expect(find.byKey(const ValueKey('finances-invoice-c')), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('finances-group-filter-group-1')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('finances-invoice-c')),
      findsOneWidget,
      reason: 'choosing the group again shows everything',
    );
  });

  testWidgets('an invoice that cannot be read now is named, left out of the '
      'totals, and can be removed', (tester) async {
    final repo = FakeInvoiceGroupRepository(
      groups: [
        const InvoiceGroup(
          id: 'g1',
          name: 'Taxes 2026',
          items: [
            InvoiceGroupItem(InvoiceRef('$_home:ws-Atelier', 'a'), 'INV-a'),
            InvoiceGroupItem(
              InvoiceRef('22222222-2222-4222-8222-222222222222:ws-gone', 'x'),
              'F-2025-117',
            ),
          ],
        ),
      ],
    );
    await _show(tester, groups: repo);
    await tester.tap(find.byKey(const ValueKey('finances-group-filter-g1')));
    await tester.pumpAndSettle();
    expect(_inHeader(find.text('2 invoices')), findsOneWidget);
    expect(
      _inHeader(
        find.text("1 invoice can't be read now: the totals leave it out."),
      ),
      findsOneWidget,
    );
    expect(
      _inHeader(find.text("F-2025-117 · can't be read now")),
      findsOneWidget,
    );
    final totals = tester
        .widget<Text>(find.byKey(const ValueKey('finances-group-totals')))
        .data!;
    expect(totals, allOf(contains('120.00'), isNot(contains(' · '))));

    await tester.tap(
      find.byKey(const ValueKey('finances-group-unreadable-remove-0')),
    );
    await tester.pumpAndSettle();
    expect(_inHeader(find.text('1 invoice')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('finances-group-unreadable')),
      findsNothing,
    );
  });

  testWidgets('a group is renamed, a name is used once, and deleting the '
      'group leaves the invoices as they are', (tester) async {
    final repo = FakeInvoiceGroupRepository(
      groups: [
        const InvoiceGroup(
          id: 'g1',
          name: 'Taxes 2026',
          items: [
            InvoiceGroupItem(InvoiceRef('$_home:ws-Atelier', 'a'), 'INV-a'),
          ],
        ),
        const InvoiceGroup(id: 'g2', name: 'To reimburse'),
      ],
    );
    await _show(tester, groups: repo);
    await tester.tap(find.byKey(const ValueKey('finances-group-filter-g1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('finances-group-rename')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('invoice-group-rename-name')),
      'to REIMBURSE',
    );
    await tester.tap(find.byKey(const ValueKey('invoice-group-rename-save')));
    await tester.pumpAndSettle();
    expect(
      find.text('You already have a group with this name.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('invoice-group-rename-name')),
      'Taxes 2027',
    );
    await tester.tap(find.byKey(const ValueKey('invoice-group-rename-save')));
    await tester.pumpAndSettle();
    expect(_inHeader(find.text('Taxes 2027')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('finances-group-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('finances-group-delete-yes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('finances-group-header')), findsNothing);
    expect(
      find.byKey(const ValueKey('finances-group-filter-g1')),
      findsNothing,
    );
    expect((await repo.groups()).map((g) => g.name), ['To reimburse']);
    expect(find.byKey(const ValueKey('finances-invoice-a')), findsOneWidget);
  });

  testWidgets('an invoice whose installation cannot be told is not offered '
      'for a group', (tester) async {
    await _show(tester, home: null);
    expect(find.byKey(const ValueKey('finances-invoice-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('finances-group-a')), findsNothing);
  });
}
