// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1449 A3 — submitting an ordinary expense, optionally as a supply for
// the space (#731).
//
// The sheet used to close first and then check: an amount of zero, a
// supply with no name or a quantity below one returned silently after
// the sheet was gone, so the person saw nothing happen and had to start
// again. The rules live here now; the sheet asks them before it closes
// and keeps the form open with the reason, and the command refuses the
// same way whatever a future caller forgets.
import '../../../core/format/cents.dart';
import '../domain/money_repository.dart';

enum ExpenseOutcome {
  /// No positive amount.
  invalidAmount,

  /// A new supply needs a name.
  missingSupplyName,

  /// A supply needs at least one unit.
  invalidSupplyQuantity,

  /// A unit price was typed but is not a non-negative amount.
  invalidUnitPrice,

  /// Filed: waiting for the expense validators.
  submitted,
}

/// What the person typed, as text, exactly as the sheet holds it.
class ExpenseDraft {
  const ExpenseDraft({
    required this.amount,
    required this.category,
    this.description = '',
    this.isSupply = false,
    this.supplyItemId,
    this.supplyItemName,
    this.supplyName = '',
    this.supplyQuantity = '1',
    this.supplyUnitPrice = '',
  });

  final String amount;
  final String category;
  final String description;
  final bool isSupply;

  /// An existing supply on the shelf; null for a new one.
  final String? supplyItemId;
  final String? supplyItemName;
  final String supplyName;
  final String supplyQuantity;
  final String supplyUnitPrice;

  int? get amountCents => parseCentsInput(amount);
  int? get quantity => int.tryParse(supplyQuantity.trim());
  String get name => (supplyItemName ?? supplyName).trim();

  /// The supply payload the RPC takes, or null for an ordinary expense.
  Map<String, Object?>? get supply => !isSupply
      ? null
      : {
          if (supplyItemId != null) 'service_id': supplyItemId,
          'name': name,
          'quantity': quantity,
          'unit_price_cents': parseCentsInput(supplyUnitPrice),
        };
}

/// Whether [draft] may be filed, and if not, why.
ExpenseOutcome expenseOutcome(ExpenseDraft draft) {
  final cents = draft.amountCents;
  if (cents == null || cents <= 0) return ExpenseOutcome.invalidAmount;
  if (!draft.isSupply) return ExpenseOutcome.submitted;
  if (draft.name.isEmpty) return ExpenseOutcome.missingSupplyName;
  final qty = draft.quantity;
  if (qty == null || qty < 1) return ExpenseOutcome.invalidSupplyQuantity;
  final unit = draft.supplyUnitPrice.trim();
  if (unit.isNotEmpty) {
    final unitCents = parseCentsInput(unit);
    if (unitCents == null || unitCents < 0) {
      return ExpenseOutcome.invalidUnitPrice;
    }
  }
  return ExpenseOutcome.submitted;
}

class Expenses {
  const Expenses(this._money);
  final MoneyRepository _money;

  /// Files [draft] for [workspaceId]. Nothing is written unless the rules
  /// allow it; a server refusal propagates, so no success is shown.
  Future<ExpenseOutcome> submit(String workspaceId, ExpenseDraft draft) async {
    final outcome = expenseOutcome(draft);
    if (outcome != ExpenseOutcome.submitted) return outcome;
    await _money.submitExpense(
      workspaceId: workspaceId,
      amountCents: draft.amountCents!,
      category: draft.category,
      description: draft.description.trim(),
      supply: draft.supply,
    );
    return outcome;
  }
}
