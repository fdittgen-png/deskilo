// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3402 -- what kind of document an invoice is. It lived beside the billing
// rules (settings-driven); the invoice model and the tax-point engine read it,
// so it has its own file, free of the settings.

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

/// When the two automatic invoice runs happen, stored in
/// `workspaces.billing_rules` (migration 0142).
///
/// Every field is a decision an owner can defend to their members, which
/// is why none of them is hard-coded: when the subscription invoice
/// arrives, whether the end-of-month one is raised at all, and whether a
/// member who owes nothing extra still gets the document that says so.
