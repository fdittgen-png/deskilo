// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4269 -- what a document is, for the books it is written into. A document
// is a credit note, a sale reversed, by what it carries: positions that are all
// reversals and nothing it charges. A monthly invoice whose netted payments
// and credits are larger than its charges has a negative total, but it is
// still a sale (its charges) beside the money that had already arrived (its
// netted credits): it is booked as that, never as an "Avoir" whose charges are
// reversed a second time.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

extension DocumentBooking on Invoice {
  /// Whether the books write this document as a credit note: a negative total
  /// that charges nothing.
  bool get reversesSale => isCreditNote && chargesCents == 0;
}
