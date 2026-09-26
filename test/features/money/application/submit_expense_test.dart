// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1449 A3 — an expense is filed only as the rules allow: a positive
// amount; a supply needs a name, at least one unit and, if typed, a
// valid unit price. A refusal writes nothing, and a server refusal
// propagates so no success is shown.
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/features/money/application/submit_expense.dart';
import 'package:flutter_test/flutter_test.dart';

ExpenseDraft _draft({
  String amount = '42.90',
  bool isSupply = false,
  String? itemId,
  String? itemName,
  String name = '',
  String qty = '1',
  String unit = '',
}) => ExpenseDraft(
  amount: amount,
  category: 'supplies',
  description: ' paper ',
  isSupply: isSupply,
  supplyItemId: itemId,
  supplyItemName: itemName,
  supplyName: name,
  supplyQuantity: qty,
  supplyUnitPrice: unit,
);

class _Refusing extends FakeMoneyRepository {
  @override
  Future<String> submitExpense({
    required String workspaceId,
    required int amountCents,
    required String category,
    String description = '',
    Map<String, Object?>? supply,
  }) async => throw StateError('refused');
}

void main() {
  test('an ordinary expense is filed with its trimmed description', () async {
    final repo = FakeMoneyRepository();
    expect(
      await Expenses(repo).submit('ws', _draft()),
      ExpenseOutcome.submitted,
    );
    final e = repo.submittedExpenses.single;
    expect(e.amountCents, 4290);
    expect(e.description, 'paper');
  });

  test('no positive amount: refused, nothing written', () async {
    for (final amount in ['', '0', '-3', 'abc']) {
      final repo = FakeMoneyRepository();
      expect(
        await Expenses(repo).submit('ws', _draft(amount: amount)),
        ExpenseOutcome.invalidAmount,
        reason: amount,
      );
      expect(repo.submittedExpenses, isEmpty);
    }
  });

  test('a new supply needs a name and at least one unit', () {
    expect(
      expenseOutcome(_draft(isSupply: true)),
      ExpenseOutcome.missingSupplyName,
    );
    expect(
      expenseOutcome(_draft(isSupply: true, name: 'Capsules', qty: '0')),
      ExpenseOutcome.invalidSupplyQuantity,
    );
    expect(
      expenseOutcome(_draft(isSupply: true, name: 'Capsules', qty: 'x')),
      ExpenseOutcome.invalidSupplyQuantity,
    );
    expect(
      expenseOutcome(
        _draft(isSupply: true, name: 'Capsules', qty: '2', unit: 'abc'),
      ),
      ExpenseOutcome.invalidUnitPrice,
    );
  });

  test(
    'an existing supply is named by the shelf, and its payload is exact',
    () async {
      final repo = FakeMoneyRepository();
      final draft = _draft(
        isSupply: true,
        itemId: 'svc-1',
        itemName: 'Capsules',
        qty: '10',
        unit: '0.50',
      );
      expect(
        await Expenses(repo).submit('ws', draft),
        ExpenseOutcome.submitted,
      );
      expect(draft.supply, {
        'service_id': 'svc-1',
        'name': 'Capsules',
        'quantity': 10,
        'unit_price_cents': 50,
      });
    },
  );

  test('a new supply with an empty unit price sends 0, as the sheet always did', () {
    final draft = _draft(isSupply: true, name: ' Bags ', qty: '3');
    expect(expenseOutcome(draft), ExpenseOutcome.submitted);
    expect(draft.supply, {
      'name': 'Bags',
      'quantity': 3,
      'unit_price_cents': 0,
    });
  });

  test('a server refusal propagates: no success', () async {
    await expectLater(
      Expenses(_Refusing()).submit('ws', _draft()),
      throwsStateError,
    );
  });
}
