// SPDX-License-Identifier: AGPL-3.0-or-later
// #4512 — Master data › Expense categories on a phone and on a desk: the four a business starts with read in the app's words
// (the retired scheduled one in its own section); one is added through its sheet, renamed, put in order, retired and brought back; a
// name is required and an active name is kept once; the server's refusal is said, never silent.
import 'package:deskilo/features/money/domain/expense_category.dart';
import 'package:deskilo/features/money/presentation/screens/expense_categories_screen.dart';
import 'package:deskilo/features/money/providers/bank_statement_providers.dart' show currentWorkspaceProvider;
import 'package:deskilo/features/money/providers/expense_category_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

const _workspace = Workspace(
  id: 'ws-1',
  name: 'Atelier',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'x',
);

Future<InMemoryExpenseCategories> _pump(WidgetTester tester, Size size) async {
  final repo = InMemoryExpenseCategories();
  await pumpApp(
    tester,
    const ExpenseCategoriesScreen(),
    size: size,
    overrides: [
      currentWorkspaceProvider.overrideWith((ref) async => _workspace),
      expenseCategoryRepositoryProvider.overrideWithValue(repo),
    ],
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

Future<void> _name(WidgetTester tester, String text) async {
  await tester.enterText(
    find.descendant(of: find.byKey(const ValueKey('expense-category-name')), matching: find.byType(EditableText)),
    text,
  );
  await tester.pump();
}

Future<ExpenseCategory> _category(InMemoryExpenseCategories repo, String code) async =>
    (await repo.categories('ws-1')).firstWhere((c) => c.code == code);

void main() {
  for (final (name, size) in [('phone', const Size(390, 844)), ('desk', const Size(1440, 900))]) {
    group('on a $name', () {
      testWidgets('a business starts with four categories in the app\'s words, and scheduled retired', (tester) async {
        await _pump(tester, size);
        for (final words in ['Coffee & kitchen', 'Supplies', 'Equipment', 'Other']) {
          expect(find.text(words), findsOneWidget);
        }
        expect(find.text('Retired categories'), findsOneWidget);
        expect(find.text('Scheduled expenses'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('one is added through its sheet, and a name already taken is said', (tester) async {
        final repo = await _pump(tester, size);
        await _tap(tester, const ValueKey('expense-category-add'));
        await _name(tester, 'Cleaning');
        await _tap(tester, const ValueKey('expense-category-save'));
        expect(find.text('Cleaning'), findsOneWidget);
        expect((await repo.categories('ws-1')).where((c) => c.label == 'Cleaning'), hasLength(1));

        await _tap(tester, const ValueKey('expense-category-add'));
        await _name(tester, ' cleaning ');
        await _tap(tester, const ValueKey('expense-category-save'));
        expect(find.text('Another active category already has this name.'), findsOneWidget);
        expect((await repo.categories('ws-1')).where((c) => c.label.toLowerCase() == 'cleaning'), hasLength(1));
      });

      testWidgets('a new category needs a name', (tester) async {
        await _pump(tester, size);
        await _tap(tester, const ValueKey('expense-category-add'));
        await _tap(tester, const ValueKey('expense-category-save'));
        expect(find.text('Give the category a name.'), findsWidgets);
      });

      testWidgets('a built-in category is renamed, and an empty name gives the app\'s words back', (tester) async {
        final repo = await _pump(tester, size);
        final coffee = await _category(repo, 'coffee');
        await _tap(tester, ValueKey('expense-category-open-${coffee.id}'));
        await _name(tester, 'Tea and coffee');
        await _tap(tester, const ValueKey('expense-category-save'));
        expect(find.text('Tea and coffee'), findsOneWidget);
        expect(find.text('Coffee & kitchen'), findsNothing);

        await _tap(tester, ValueKey('expense-category-open-${coffee.id}'));
        await _name(tester, '');
        await _tap(tester, const ValueKey('expense-category-save'));
        expect(find.text('Coffee & kitchen'), findsOneWidget);
      });

      testWidgets('one is put in order, retired and brought back', (tester) async {
        final repo = await _pump(tester, size);
        final other = await _category(repo, 'other');
        await _tap(tester, ValueKey('expense-category-up-${other.id}'));
        final order = [for (final c in await repo.categories('ws-1')) if (!c.retired) c.code];
        expect(order, ['coffee', 'supplies', 'other', 'equipment']);

        await _tap(tester, ValueKey('expense-category-retire-${other.id}'));
        expect((await _category(repo, 'other')).retired, isTrue);
        expect(find.byKey(ValueKey('expense-category-restore-${other.id}')), findsOneWidget);

        await _tap(tester, ValueKey('expense-category-restore-${other.id}'));
        expect((await _category(repo, 'other')).retired, isFalse);
        expect(find.byKey(ValueKey('expense-category-restore-${other.id}')), findsNothing);
      });
    });
  }
}
