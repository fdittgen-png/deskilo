// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3402 -- what kind of document an invoice is. It lived beside the billing
// rules (settings-driven); the invoice model and the tax-point engine read it,
// so it has its own file, free of the settings.

/// What an invoice CHARGES FOR (#802, migration 0142).
///
/// A subscription is paid in advance, so its invoice has to exist before
/// the month it covers; what the month actually cost — overage,
/// accessories, services, packages, adjustments — cannot be known until
/// the month ends. One document could never be both, so there are two.
enum InvoiceKind {
  /// The historical whole-month document: every pre-0142 invoice, and
  /// still what issuing by hand produces.
  full,

  /// The monthly fee, issued AHEAD of the period it covers.
  subscription,

  /// Everything the month actually cost, issued once it is over.
  usage,

  /// Several invoices regrouped into one (#803).
  settlement;

  static InvoiceKind fromWire(String? raw) =>
      InvoiceKind.values.asNameMap()[raw ?? ''] ?? InvoiceKind.full;

  /// Whether this document charges the fee for a month still to come.
  /// The reader needs telling: an invoice dated 28 August for September
  /// otherwise looks like a mistake.
  bool get isInAdvance => this == InvoiceKind.subscription;
}
