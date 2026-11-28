// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1449 — the words of the reason an expense cannot be filed, and the field each reason is about, so its sentence sits under
// that field. #4479 adds the supplier's country and the VAT a supplier abroad charged.
import '../../../../l10n/app_localizations.dart';
import '../../application/submit_expense.dart';

/// The sentence for [outcome], or null when the expense may be filed.
String? expenseOutcomeText(AppLocalizations l10n, ExpenseOutcome outcome) => switch (outcome) {
  ExpenseOutcome.submitted => null,
  ExpenseOutcome.invalidAmount => l10n.expenseInvalidAmount,
  ExpenseOutcome.missingSupplyName => l10n.expenseMissingSupplyName,
  ExpenseOutcome.invalidSupplyQuantity => l10n.expenseInvalidSupplyQuantity,
  ExpenseOutcome.invalidUnitPrice => l10n.expenseInvalidUnitPrice,
  ExpenseOutcome.invalidDeductible => l10n.expenseInvalidDeductible,
  ExpenseOutcome.missingSupplierCountry => l10n.expenseMissingSupplierCountry,
  ExpenseOutcome.invalidStatedVat => l10n.expenseInvalidStatedVat,
};

/// The key of the field [outcome] is about, or null when none is.
String? expenseOutcomeField(ExpenseOutcome outcome) => switch (outcome) {
  ExpenseOutcome.submitted => null,
  ExpenseOutcome.invalidAmount => 'amount',
  ExpenseOutcome.missingSupplyName => 'supplyName',
  ExpenseOutcome.invalidSupplyQuantity => 'supplyQuantity',
  ExpenseOutcome.invalidUnitPrice => 'supplyUnit',
  ExpenseOutcome.invalidDeductible => 'deductible',
  ExpenseOutcome.missingSupplierCountry => 'vatCountry',
  ExpenseOutcome.invalidStatedVat => 'statedPercent',
};
