// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 -- the payment-clause rules of a country come from its add-on, handed
// to `qualifyClauses` / `legalProfileOf` by the host. These tests ask about a
// seller country and a capacity: this file hands the installed add-on's rules
// in, keeping the call shapes the tests were written against.
import 'package:deskilo/features/money/domain/clause_rules.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart' as model;
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';

export 'package:deskilo_invoice_model/deskilo_invoice_model.dart'
    hide legalProfileOf, qualifyClauses;

model.LegalProfile legalProfileOf(
  model.LegalClauseSnapshot snapshot, {
  required TaxReferenceSet reference,
}) => model.legalProfileOf(
  snapshot,
  reference: reference,
  rules: clauseRulesOf(snapshot.sellerCountry),
);

model.QualifiedClauses qualifyClauses(
  model.LegalClauseSnapshot snapshot,
  model.ReportStrings strings, {
  required TaxReferenceSet reference,
}) => model.qualifyClauses(
  snapshot,
  strings,
  reference: reference,
  rules: clauseRulesOf(snapshot.sellerCountry),
);
