// SPDX-License-Identifier: 0BSD

/// #720 — the four faces of the Finances tab, like the inbox's chats
/// and alerts: the month's STATEMENT, what I PAY (and ask for), what I
/// am INVOICED, and my DOCUMENTS. One question per face, so a member
/// never scans a bill to find a button.
enum MoneyFace {
  /// The month as it stands: account position, days, subscription,
  /// services, packages, open positions, credits, the invoice card, the
  /// balance. Read-only.
  statement,

  /// Settle and ask: overdue notice, balance, how to pay / pay online,
  /// record a payment, buy a package, submit an expense, request
  /// half-days, add a consumption.
  payments,

  /// Invoicing only: what is open and due, every invoice issued to me,
  /// the register for issuers.
  invoices,

  /// #833 — what the month's bookings actually were: the window booked,
  /// the time present, and what of it bills. Read, and one ask.
  usage,

  /// The rest of the paperwork: my conditions, the payments report, the
  /// month's statement as PDF, the document library.
  documents;

  static MoneyFace? fromWire(String? name) =>
      name == null ? null : values.where((f) => f.name == name).firstOrNull;
}
