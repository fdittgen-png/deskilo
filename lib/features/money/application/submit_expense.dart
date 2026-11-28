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
import '../../../core/format/decimal_input.dart';
import '../domain/expense_repository.dart';

enum ExpenseOutcome {
  /// No positive amount.
  invalidAmount,

  /// A new supply needs a name.
  missingSupplyName,

  /// A supply needs at least one unit.
  invalidSupplyQuantity,

  /// A unit price was typed but is not a non-negative amount.
  invalidUnitPrice,

  /// #2357 — the deductible share is not a percentage.
  invalidDeductible,

  /// #4479 — VAT a supplier abroad charged needs that supplier's country.
  missingSupplierCountry,

  /// #4479 — the VAT a supplier abroad charged is not stated as a rate (or an amount) the document can have.
  invalidStatedVat,

  /// Filed: waiting for the expense validators.
  submitted,
}

/// What an expense's VAT says beyond its rate and share: #2357 — it bought
/// a fixed asset (CA3 line 19); #2360 — it was bought from a supplier
/// abroad, so the amount carries no VAT and is the base of the acquisition
/// tax the space owes (CH 383).
typedef ExpenseVatFlags = ({bool asset, bool acquisition});

/// #4479 — the VAT a supplier abroad charged on its invoice, kept as a fact of the document: the stated rate and, when the
/// document shows it, the amount. It is not deducted on the space's return (a refund from the supplier's state is a filing of
/// its own, Directive 2008/9/EC), so the space's sales catalogue never interprets it.
class ForeignVat {
  const ForeignVat({required this.percent, this.taxCents});

  final double? percent;
  final int? taxCents;

  /// Whether the stated rate is one a document can have, and the amount, when given, not negative.
  bool get valid => percent != null && percent! > 0 && percent! <= 100 && (taxCents ?? 0) >= 0;
}

/// The VAT payload the expense RPCs take, one shape for a one-off expense and a scheduled one; null for an expense without VAT.
Map<String, Object?>? expenseVatPayload({
  required double? percent,
  required double? deductiblePct,
  String? rateId,
  ExpenseVatFlags flags = (asset: false, acquisition: false),
  ForeignVat? foreign,
  Map<String, Object?> facts = const {},
}) {
  if (foreign != null) {
    return {
      'treatment': 'foreign_charged',
      'stated_percent': foreign.percent,
      if (foreign.taxCents != null) 'stated_tax_cents': foreign.taxCents,
      ...facts,
    };
  }
  if ((percent ?? 0) <= 0) return null;
  return {
    'percent': percent,
    'deductible_pct': deductiblePct,
    'treatment': flags.acquisition ? 'acquisition' : 'domestic',
    'vat_rate_id': ?rateId,
    if (flags.asset) 'asset': true,
    if (flags.acquisition) 'acquisition': true,
    ...facts,
  };
}

/// What the person typed, as text, exactly as the sheet holds it.
class ExpenseDraft {
  const ExpenseDraft({
    required this.locale,
    required this.amount,
    required this.category,
    this.description = '',
    this.isSupply = false,
    this.supplyItemId,
    this.supplyItemName,
    this.supplyName = '',
    this.supplyQuantity = '1',
    this.supplyUnitPrice = '',
    this.vatPercent,
    this.deductible = '100',
    this.vatFlags = (asset: false, acquisition: false),
    this.vatRateId,
    this.foreignVat,
    this.vatFacts = const {},
  });

  /// #3484 — the member's format locale: the amounts typed here read in it.
  final String locale;

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

  /// #2357 — the VAT rate the expense carries (its amount is gross);
  /// null when it carries none or input VAT is off.
  final double? vatPercent;

  /// The share of that VAT the space may deduct, in percent, as typed.
  final String deductible;

  final ExpenseVatFlags vatFlags;

  /// #4479 — the identity of the rate picked from the space's rates; the server resolves the percent from it.
  final String? vatRateId;

  /// #4479 — VAT a supplier abroad charged, as the document states it: not input tax of the space's return, so it has no
  /// rate of the space and no share to deduct; null when the VAT is the space's own.
  final ForeignVat? foreignVat;

  /// #4479 — what the document says: its supplier's country, its number and its date, as typed or picked.
  final Map<String, Object?> vatFacts;

  double? get deductiblePct =>
      parseDecimalInput(deductible, grouping: false)?.toDouble();

  /// The VAT payload the RPC takes, or null for an expense without VAT.
  Map<String, Object?>? get vat => expenseVatPayload(
    percent: vatPercent,
    deductiblePct: deductiblePct,
    rateId: vatRateId,
    flags: vatFlags,
    foreign: foreignVat,
    facts: vatFacts,
  );

  int? get amountCents => parseMinorInput(amount, locale: locale);
  int? get quantity => int.tryParse(supplyQuantity.trim());
  String get name => (supplyItemName ?? supplyName).trim();

  /// The supply payload the RPC takes, or null for an ordinary expense.
  Map<String, Object?>? get supply => !isSupply
      ? null
      : {
          if (supplyItemId != null) 'service_id': supplyItemId,
          'name': name,
          'quantity': quantity,
          'unit_price_cents': parseMinorInput(supplyUnitPrice, locale: locale),
        };
}

/// Whether [draft] may be filed, and if not, why.
ExpenseOutcome expenseOutcome(ExpenseDraft draft) {
  final cents = draft.amountCents;
  if (cents == null || cents <= 0) return ExpenseOutcome.invalidAmount;
  final foreign = draft.foreignVat;
  if (foreign != null) {
    if ((draft.vatFacts['supplier_country'] as String? ?? '').isEmpty) return ExpenseOutcome.missingSupplierCountry;
    if (!foreign.valid) return ExpenseOutcome.invalidStatedVat;
  } else if (draft.vat != null) {
    final share = draft.deductiblePct;
    if (share == null || share < 0 || share > 100) {
      return ExpenseOutcome.invalidDeductible;
    }
  }
  if (!draft.isSupply) return ExpenseOutcome.submitted;
  if (draft.name.isEmpty) return ExpenseOutcome.missingSupplyName;
  final qty = draft.quantity;
  if (qty == null || qty < 1) return ExpenseOutcome.invalidSupplyQuantity;
  final unit = draft.supplyUnitPrice.trim();
  if (unit.isNotEmpty) {
    final unitCents = parseMinorInput(unit, locale: draft.locale);
    if (unitCents == null || unitCents < 0) {
      return ExpenseOutcome.invalidUnitPrice;
    }
  }
  return ExpenseOutcome.submitted;
}

class Expenses {
  const Expenses(this._money);
  final ExpenseRepository _money;

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
      vat: draft.vat,
    );
    return outcome;
  }
}
