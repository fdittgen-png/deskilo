// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3837 — where the money of a revoked guest pass stands, read from the
// business's invoices: revoking moves no money (#3829), so the pass says
// whether its invoice is still to be corrected. One rule, from what the
// server stores: the pass's invoice is voided, or the pass's customer record
// (one per pass, 0685) holds a replacement or a credit note. A void or a
// credit note waiting for an approval leaves the invoice as it is, so the
// pass reads "not corrected yet" until the approval lands (decision of 13
// November on #3837). Pure Dart: the CLI imports the domain.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

import 'guest_pass.dart';

/// Where a pass's invoice stands.
enum PassInvoiceState {
  /// A free pass: no invoice was made.
  free,

  /// The pass's invoice is not among those read.
  unknown,

  /// The invoice stands as issued, open or paid: nothing corrects it yet.
  notCorrected,

  /// The invoice was voided.
  voided,

  /// The pass's customer record holds a replacement invoice.
  replaced,

  /// The pass's customer record holds a credit note.
  credited;

  /// Whether the money of the pass has been corrected.
  bool get corrected => this == voided || this == replaced || this == credited;
}

/// The pass's invoice, when read, and where it stands.
typedef PassInvoice = ({PassInvoiceState state, Invoice? invoice});

/// Where [pass]'s invoice stands among [invoices] (the business's).
PassInvoice passInvoiceOf(GuestPassRecord pass, Iterable<Invoice> invoices) {
  final id = pass.invoiceId;
  if (id == null) return (state: PassInvoiceState.free, invoice: null);
  final own = invoices.where((i) => i.id == id).firstOrNull;
  if (own == null) return (state: PassInvoiceState.unknown, invoice: null);
  final others = [
    for (final i in invoices)
      if (i.memberId == own.memberId && i.id != own.id) i,
  ];
  final state = switch (own) {
    _ when others.any((i) => i.replacesInvoiceId != null) =>
      PassInvoiceState.replaced,
    _ when others.any((i) => i.isCreditNote) => PassInvoiceState.credited,
    Invoice(isVoided: true) => PassInvoiceState.voided,
    _ => PassInvoiceState.notCorrected,
  };
  return (state: state, invoice: own);
}
