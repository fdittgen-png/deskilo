// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #956 — the payments report keeps its figures separate.

import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  test('the payments report names pending payments and pending expenses apart', () {
    expect(InvoicePdfTemplate.placeholders, containsAll(['pending_payments_total', 'pending_expenses_total']));
  });
}
