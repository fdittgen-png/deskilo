// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3601 -- the customer named on an invoice is the member it belongs to: the
// fixture's own check read the member id and never the name.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

/// What is wrong with the customer name of [invoice], given [memberNames].
List<String> invoiceNameProblems(
  Invoice invoice,
  Map<String, String> memberNames,
) {
  final named = memberNames[invoice.memberId];
  if (named == null || invoice.memberName == named) return const [];
  return [
    'invoice ${invoice.number}: names "${invoice.memberName}" but member '
        '${invoice.memberId} is "$named"',
  ];
}
