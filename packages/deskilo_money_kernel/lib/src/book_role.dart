// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3376 -- the account types and the roles a posting books to: the vocabulary
// of the posting model, with no chart, no tax reference and no application
// type behind it.

enum AccountType { asset, liability, equity, income, expense }

/// What a posting needs an account for.
enum BookRole {
  customers('customers', AccountType.asset),
  revenue('revenue', AccountType.income),
  bank('bank', AccountType.asset),
  vatOutput('vat_output', AccountType.liability),

  /// #2357 — deductible VAT on expenses (FR 44566, DE 1576/1406).
  vatInput('vat_input', AccountType.asset),
  expenses('expenses', AccountType.expense),

  /// #2365 (0517) — the bases the posting contract adds: what the space
  /// owes its suppliers, output tax not yet due, the written-off rest of a
  /// receivable, a discount granted, money in transit at a payment provider
  /// and that provider's fees.
  suppliers('suppliers', AccountType.liability),
  vatPending('vat_pending', AccountType.liability),
  writeOff('write_off', AccountType.expense),
  cashDiscount('cash_discount', AccountType.expense),
  clearing('clearing', AccountType.asset),
  fees('fees', AccountType.expense),

  /// #2573 — what a purchase line bought when it is not an operating cost:
  /// long-lasting equipment, goods for resale, a prepayment, a refundable
  /// deposit. Unmapped, the purchase blocks instead of booking an expense.
  fixedAssets('fixed_assets', AccountType.asset),
  stock('stock', AccountType.asset),
  prepayments('prepayments', AccountType.asset),
  deposits('deposits', AccountType.asset);

  const BookRole(this.wire, this.type);
  final String wire;

  /// The only account type this role may book to.
  final AccountType type;

  static BookRole fromWire(String? wire) => values.firstWhere(
    (v) => v.wire == wire,
    orElse: () => throw FormatException('unknown role $wire'),
  );
}
