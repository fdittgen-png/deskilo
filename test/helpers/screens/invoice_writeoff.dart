// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared pump/fixtures that used to live in invoice_writeoff_test.dart and were borrowed by
// importing that test file (#2601). Moved verbatim.

import 'package:deskilo/features/money/domain/invoice.dart';

import '../test_clock.dart';

InvoiceMatch partialMatch(String invoiceId, {DateTime? writeoffAt}) =>
    InvoiceMatch(
      invoiceId: invoiceId,
      paidCents: 10000,
      resolution: 'under_accepted',
      note: 'paid what they could',
      matchedAt: kTestNow,
      writeoffAt: writeoffAt,
    );
