// SPDX-License-Identifier: 0BSD

/// #720 — the three faces of the Finances tab, like the inbox's chats
/// and alerts: what I PAY, what I CONSUME, what I am INVOICED. One
/// question per face, so a member never scans a bill to find a button.
enum MoneyFace {
  /// Position, open positions, credits, balance, how to pay, record a
  /// payment, buy a package, the monthly payments report.
  payments,

  /// This month's entitlement, subscription, services, packages; the
  /// requests that add to them (expense, extra half-days, consumption).
  consumption,

  /// The month's invoice, my invoices, my conditions, the register for
  /// those allowed to issue.
  invoices;

  static MoneyFace? fromWire(String? name) =>
      name == null ? null : values.where((f) => f.name == name).firstOrNull;
}
