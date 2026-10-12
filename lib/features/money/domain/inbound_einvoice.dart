// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:xml/xml.dart';

/// #2358 — a supplier's e-invoice as it arrives: UBL 2.1 (Peppol BIS,
/// XRechnung, CIUS-RO) or UN/CEFACT CII (Factur-X, ZUGFeRD, XRechnung CII).
/// Pure Dart; the inbox keeps the bytes and these fields.
///
/// The parser reads what an accountant needs to recognise the document and
/// to match it to an expense: who sent it, its number and dates, the
/// currency and the three totals. It does not validate the norm — the CI
/// validators do that for what we send; for what we receive, a document
/// the parser cannot read is refused with a code, never half-stored.
enum InboundEInvoiceSyntax { ubl, cii }

/// Why a document was refused.
enum InboundEInvoiceProblem {
  /// Not well-formed XML.
  notXml,

  /// A root that is neither a UBL Invoice/CreditNote nor a CII invoice.
  unsupportedRoot,

  /// A field the inbox cannot do without is missing or unreadable.
  missingField,
}

class InboundEInvoiceException implements Exception {
  const InboundEInvoiceException(this.problem, [this.field = '']);

  final InboundEInvoiceProblem problem;

  /// The field (an EN 16931 business term) a [missingField] names.
  final String field;

  @override
  String toString() => 'InboundEInvoiceException($problem $field)';
}

class InboundEInvoice {
  const InboundEInvoice({
    required this.syntax,
    required this.number,
    required this.issueDate,
    required this.currency,
    required this.supplierName,
    required this.netCents,
    required this.taxCents,
    required this.grossCents,
    this.dueDate,
    this.documentType = '380',
    this.supplierVatId = '',
    this.supplierEndpoint = '',
  });

  final InboundEInvoiceSyntax syntax;

  /// BT-1.
  final String number;

  /// BT-2, as `yyyy-mm-dd`.
  final String issueDate;

  /// BT-9, as `yyyy-mm-dd`.
  final String? dueDate;

  /// BT-3 (UNTDID 1001): 380 invoice, 381 credit note, ...
  final String documentType;

  /// BT-5.
  final String currency;

  /// BT-27.
  final String supplierName;

  /// BT-31.
  final String supplierVatId;

  /// BT-34 (the seller's electronic address).
  final String supplierEndpoint;

  /// BT-109, BT-110, BT-112 in minor units.
  final int netCents;
  final int taxCents;
  final int grossCents;

  bool get isCreditNote => documentType == '381' || documentType == '384';

  /// The payload `ingest_einvoice` takes.
  Map<String, Object?> toRpc() => {
    'number': number,
    'issue_date': issueDate,
    'due_date': dueDate,
    'document_type': documentType,
    'currency': currency,
    'supplier_name': supplierName,
    'supplier_vat_id': supplierVatId,
    'supplier_endpoint': supplierEndpoint,
    'net_cents': netCents,
    'tax_cents': taxCents,
    'gross_cents': grossCents,
  };
}

/// Reads [xml]; throws [InboundEInvoiceException] when it cannot.
InboundEInvoice parseInboundEInvoice(String xml) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(xml);
  } on XmlException {
    throw const InboundEInvoiceException(InboundEInvoiceProblem.notXml);
  }
  final root = doc.rootElement;
  switch (root.name.local) {
    case 'Invoice':
    case 'CreditNote':
      return _ubl(root);
    case 'CrossIndustryInvoice':
      return _cii(root);
  }
  throw const InboundEInvoiceException(InboundEInvoiceProblem.unsupportedRoot);
}

// ── tree helpers (namespace prefixes vary, local names do not) ──────────

XmlElement? _child(XmlElement? e, String name) {
  if (e == null) return null;
  for (final c in e.childElements) {
    if (c.name.local == name) return c;
  }
  return null;
}

XmlElement? _path(XmlElement? e, List<String> names) {
  var cur = e;
  for (final n in names) {
    cur = _child(cur, n);
  }
  return cur;
}

String _text(XmlElement? e) => e?.innerText.trim() ?? '';

String _required(String value, String field) {
  if (value.isEmpty) {
    throw InboundEInvoiceException(InboundEInvoiceProblem.missingField, field);
  }
  return value;
}

/// `2026-09-01` or `20260901` (CII format 102) to `2026-09-01`.
String _date(String raw, String field) {
  final s = raw.trim();
  final m = RegExp(r'^(\d{4})-?(\d{2})-?(\d{2})$').firstMatch(s);
  if (m == null) {
    throw InboundEInvoiceException(InboundEInvoiceProblem.missingField, field);
  }
  final y = int.parse(m[1]!);
  final mo = int.parse(m[2]!);
  final d = int.parse(m[3]!);
  if (DateTime.utc(y, mo, d).month != mo) {
    throw InboundEInvoiceException(InboundEInvoiceProblem.missingField, field);
  }
  return '${m[1]}-${m[2]}-${m[3]}';
}

/// A decimal text to minor units without going through a double:
/// `120.5` is 12050; more than two decimals is refused.
int _cents(String raw, String field) {
  final m = RegExp(r'^(-?)(\d+)(?:\.(\d{1,2})0*)?$').firstMatch(raw.trim());
  if (m == null) {
    throw InboundEInvoiceException(InboundEInvoiceProblem.missingField, field);
  }
  final whole = int.parse(m[2]!);
  final frac = int.parse((m[3] ?? '').padRight(2, '0'));
  final v = whole * 100 + frac;
  return m[1] == '-' ? -v : v;
}

// ── UBL ─────────────────────────────────────────────────────────────────

InboundEInvoice _ubl(XmlElement root) {
  final isCredit = root.name.local == 'CreditNote';
  final party = _path(root, ['AccountingSupplierParty', 'Party']);
  final name = _text(_path(party, ['PartyLegalEntity', 'RegistrationName']));
  final supplier = name.isNotEmpty
      ? name
      : _text(_path(party, ['PartyName', 'Name']));
  final totals = _child(root, 'LegalMonetaryTotal');
  final net = _cents(_text(_child(totals, 'TaxExclusiveAmount')), 'BT-109');
  final gross = _cents(_text(_child(totals, 'TaxInclusiveAmount')), 'BT-112');
  final taxText = _text(_path(root, ['TaxTotal', 'TaxAmount']));
  final due = _text(_child(root, 'DueDate'));
  final type = _text(
    _child(root, isCredit ? 'CreditNoteTypeCode' : 'InvoiceTypeCode'),
  );
  return InboundEInvoice(
    syntax: InboundEInvoiceSyntax.ubl,
    number: _required(_text(_child(root, 'ID')), 'BT-1'),
    issueDate: _date(_text(_child(root, 'IssueDate')), 'BT-2'),
    dueDate: due.isEmpty ? null : _date(due, 'BT-9'),
    documentType: type.isEmpty ? (isCredit ? '381' : '380') : type,
    currency: _required(_text(_child(root, 'DocumentCurrencyCode')), 'BT-5'),
    supplierName: _required(supplier, 'BT-27'),
    supplierVatId: _text(_path(party, ['PartyTaxScheme', 'CompanyID'])),
    supplierEndpoint: _text(_child(party, 'EndpointID')),
    netCents: net,
    taxCents: taxText.isEmpty ? gross - net : _cents(taxText, 'BT-110'),
    grossCents: gross,
  );
}

// ── CII ─────────────────────────────────────────────────────────────────

InboundEInvoice _cii(XmlElement root) {
  final doc = _child(root, 'ExchangedDocument');
  final trade = _child(root, 'SupplyChainTradeTransaction');
  final seller = _path(trade, [
    'ApplicableHeaderTradeAgreement',
    'SellerTradeParty',
  ]);
  final settlement = _child(trade, 'ApplicableHeaderTradeSettlement');
  final sums = _child(
    settlement,
    'SpecifiedTradeSettlementHeaderMonetarySummation',
  );
  final net = _cents(_text(_child(sums, 'TaxBasisTotalAmount')), 'BT-109');
  final gross = _cents(_text(_child(sums, 'GrandTotalAmount')), 'BT-112');
  final taxText = _text(_child(sums, 'TaxTotalAmount'));
  final due = _text(
    _path(settlement, [
      'SpecifiedTradePaymentTerms',
      'DueDateDateTime',
      'DateTimeString',
    ]),
  );
  // BT-31 is the registration whose scheme is VA; fall back to the first.
  String vat = '';
  for (final r in seller?.childElements ?? const <XmlElement>[]) {
    if (r.name.local != 'SpecifiedTaxRegistration') continue;
    final id = _child(r, 'ID');
    if (id == null) continue;
    if (vat.isEmpty || id.getAttribute('schemeID') == 'VA') vat = _text(id);
  }
  return InboundEInvoice(
    syntax: InboundEInvoiceSyntax.cii,
    number: _required(_text(_child(doc, 'ID')), 'BT-1'),
    issueDate: _date(
      _text(_path(doc, ['IssueDateTime', 'DateTimeString'])),
      'BT-2',
    ),
    dueDate: due.isEmpty ? null : _date(due, 'BT-9'),
    documentType: _text(_child(doc, 'TypeCode')).isEmpty
        ? '380'
        : _text(_child(doc, 'TypeCode')),
    currency: _required(
      _text(_child(settlement, 'InvoiceCurrencyCode')),
      'BT-5',
    ),
    supplierName: _required(_text(_child(seller, 'Name')), 'BT-27'),
    supplierVatId: vat,
    supplierEndpoint: _text(
      _path(seller, ['URIUniversalCommunication', 'URIID']),
    ),
    netCents: net,
    taxCents: taxText.isEmpty ? gross - net : _cents(taxText, 'BT-110'),
    grossCents: gross,
  );
}
