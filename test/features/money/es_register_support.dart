// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 -- the Spanish registers moved into `deskilo_jurisdiction_es` and read
// a neutral `RegisterContext`. These tests build documents as `Invoice`s, as
// the host holds them: this file maps them through the host's own builder and
// keeps the call shapes the tests were written against, so the assertions
// stand unchanged.
import 'package:deskilo/features/money/application/jurisdiction/register_context_builder.dart';
import 'package:deskilo/features/money/domain/vat_filing_files.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_es/deskilo_jurisdiction_es.dart' as es;
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';
import 'package:deskilo_xlsx/deskilo_xlsx.dart';

export 'package:deskilo_jurisdiction_es/deskilo_jurisdiction_es.dart'
    hide
        esBuyerIdOf,
        esInvoiceTypeOf,
        esLibroExpedidas,
        modelo347Lines,
        registerDocuments,
        siiFacturasEmitidasXml,
        verifactuRecordFor;

const _party = VatFilingParty(
  countryCode: 'ES',
  name: '',
  street: '',
  postalCode: '',
  city: '',
  vatId: '',
  legalId: '',
);

RegisterContext _context(
  Iterable<Invoice> invoices,
  TaxReferenceSet reference, {
  DateTime? from,
  DateTime? to,
  String? thresholdKey,
  bool immediateSupply = false,
}) => registerContextOf(
  invoices,
  reference: reference,
  party: _party,
  from: from ?? DateTime(1900),
  to: to ?? DateTime(2100),
  thresholdKey: thresholdKey,
  immediateSupply: immediateSupply,
);

/// The documents a register lists for `[from, to)`, as invoices.
List<Invoice> registerDocuments(
  Iterable<Invoice> invoices, {
  required DateTime from,
  required DateTime to,
}) {
  final kept = {
    for (final d in es.registerDocuments(
      [for (final i in invoices) registerDocumentOf(i)],
      from: from,
      to: to,
    ))
      d.number,
  };
  return [
    for (final i in invoices)
      if (kept.contains(i.number)) i,
  ]..sort((a, b) => a.issuedAt.compareTo(b.issuedAt));
}

({String type, String country, String id}) esBuyerIdOf(
  Invoice invoice, {
  required TaxReferenceSet reference,
}) => es.esBuyerIdOf(
  registerDocumentOf(invoice),
  context: _context([invoice], reference),
);

String esInvoiceTypeOf(Invoice invoice, {required TaxReferenceSet reference}) =>
    es.esInvoiceTypeOf(
      registerDocumentOf(invoice),
      context: _context([invoice], reference),
    );

XlsxSheet esLibroExpedidas(
  List<Invoice> documents, {
  required String activity,
  required TaxReferenceSet reference,
  bool monthly = false,
}) => es.esLibroExpedidas(
  [for (final d in documents) registerDocumentOf(d)],
  activity: activity,
  monthly: monthly,
  context: _context(documents, reference),
);

String siiFacturasEmitidasXml(
  List<Invoice> documents, {
  required String vatId,
  required String name,
  required TaxReferenceSet reference,
}) {
  try {
    return es.siiFacturasEmitidasXml(
      [for (final d in documents) registerDocumentOf(d)],
      vatId: vatId,
      name: name,
      context: _context(documents, reference),
    );
  } on RegisterRefusal catch (e) {
    throw VatFilingFileException(_problem(e));
  }
}

({String currency, List<es.Modelo347Line> lines})? modelo347Lines(
  Iterable<Invoice> invoices, {
  required int year,
  required TaxReferenceSet reference,
  required bool immediateSupply,
}) {
  try {
    return es.modelo347Lines(
      [for (final i in invoices) registerDocumentOf(i)],
      year: year,
      context: registerContextOf(
        invoices,
        reference: reference,
        party: _party,
        from: DateTime(year),
        to: DateTime(year + 1),
        thresholdKey: const es.EsRegisters().thresholdKey('es347'),
        immediateSupply: immediateSupply,
      ),
    );
  } on RegisterRefusal catch (e) {
    throw VatFilingFileException(_problem(e));
  }
}

es.VerifactuRecord verifactuRecordFor({
  required Invoice invoice,
  required InvoiceParty seller,
  required InvoiceParty buyer,
  required String previousHuella,
  required DateTime generatedAt,
  String previousNumber = '',
  String previousIssueDate = '',
}) => es.verifactuRecordFor(
  invoice: registerDocumentOf(invoice),
  seller: _partyOf(seller),
  buyer: _partyOf(buyer),
  previousHuella: previousHuella,
  generatedAt: generatedAt,
  previousNumber: previousNumber,
  previousIssueDate: previousIssueDate,
);

RegisterParty _partyOf(InvoiceParty p) => RegisterParty(
  name: p.name,
  company: p.company,
  country: p.country,
  vatId: p.vatId,
  legalId: p.legalId,
  postalCode: p.postalCode,
);

VatFilingFileProblem _problem(RegisterRefusal e) => switch (e.problem) {
  RegisterProblem.vatNumber => VatFilingFileProblem.vatNumber,
  RegisterProblem.unmappedAmount => VatFilingFileProblem.unmappedBox,
  RegisterProblem.exoneratedByImmediateSupply =>
    VatFilingFileProblem.exoneratedBySii,
};
