// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2373 — Sage 50's audit trail of documents, as the export run writes it,
// for the tests that read its rows: each member keyed by its id as its
// number, the rate groups of [country], nothing refused.
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/sage.dart';
import 'package:deskilo/features/money/domain/sage_documents.dart';
import 'package:flutter_test/flutter_test.dart';

String sageOfInvoices(
  List<Invoice> invoices,
  Map<String, InvoiceMatch> matches, {
  SageAccounts accounts = const SageAccounts(),
  String country = 'GB',
  String currency = 'EUR',
}) {
  final trail = sageRowsOfInvoices(
    invoices: invoices,
    matches: matches,
    accounts: accounts,
    customers: SageCustomers(
      memberNumbers: {for (final i in invoices) i.memberId: i.memberId},
      sellerCountry: country,
    ),
    baseCurrency: currency,
    groupOf: (t) => ActiveTaxReference.current.groupOfRate(
      country,
      t.percent,
      t.category,
    ),
  );
  expect(trail.blockers, isEmpty);
  return sageFile(trail.rows);
}
