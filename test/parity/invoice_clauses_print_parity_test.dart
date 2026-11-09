// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- what an invoice prints that depends on a country,
// pinned BEFORE it moves behind the contract: the payment clauses by seller
// country and customer capacity, the seller's identity numbers as a Swiss or
// Canadian one prints them, the Swiss QR bill's gate and addresses, and the
// VATEX / exemption codes of a category. The goldens are written by the code
// as it stands and compared byte for byte; rewrite only with
// `UPDATE_PARITY_GOLDENS=1`, never under CI.
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/report_data.dart';
import 'package:deskilo/features/money/domain/swiss_qr_bill_invoice.dart';
import 'package:deskilo/features/money/domain/swiss_qr_bill_pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import '../features/money/clause_rules_support.dart';
import 'parity_golden.dart';


final _reference = ActiveTaxReference.current;

String _clause(QualifiedClause c) => '${c.basis.name}:"${c.text}"';

String _clauses() {
  const ownerAll = PaymentTerms(
    paymentTerms: 'Net 30',
    latePenalty: 'Late 3x',
    recoveryIndemnity: 'EUR 40',
    escompte: 'No discount',
  );
  final out = StringBuffer();
  for (final country in [
    'FR',
    'DE',
    'GB',
    'CH',
    'CA',
    'US',
    'AT',
    'IT',
    'ES',
    'PL',
    'JP',
    'fr',
    ' de ',
    '',
    'XX',
  ]) {
    for (final capacity in CustomerCapacity.values) {
      for (final (label, terms) in [
        ('none', PaymentTerms.empty),
        ('owner', ownerAll),
      ]) {
        final q = qualifyClauses(
          LegalClauseSnapshot(
            sellerCountry: country,
            buyerCapacity: capacity,
            clauses: terms,
          ),
          const ReportStrings(),
          reference: _reference,
        );
        out
          ..writeln(
            '[${country.isEmpty ? '(blank)' : country} / ${capacity.name} / $label] ${q.profile.name}',
          )
          ..writeln('  terms=${_clause(q.paymentTerms)}')
          ..writeln('  late=${_clause(q.latePenalty)}')
          ..writeln('  indemnity=${_clause(q.recoveryIndemnity)}')
          ..writeln('  escompte=${_clause(q.escompte)}')
          ..writeln('  deficiencies=${q.deficiencies.join(',')}');
      }
    }
  }
  for (final association in [false, true]) {
    final legacy = legacyClauses(
      InvoiceLegal.fromJson({'seller_kind': association ? 'association' : ''}),
      PaymentTerms.empty,
      const ReportStrings(),
    );
    out
      ..writeln('[legacy association=$association] ${legacy.profile.name}')
      ..writeln('  late=${_clause(legacy.latePenalty)}')
      ..writeln('  indemnity=${_clause(legacy.recoveryIndemnity)}');
  }
  return out.toString();
}

String _sellerIds() {
  final out = StringBuffer();
  for (final (country, vat, legal) in [
    ('CH', 'CHE123456788', ''),
    ('CH', 'CHE-123.456.788', ''),
    ('CH', 'CHE-123.456.788 MWST', ''),
    ('CH', 'CHE-123.456.789', ''),
    (' ch ', 'CHE123456788', ''),
    ('CA', '123456789RT0001', '1234567890TQ0001'),
    ('CA', '123456789', '1234567890'),
    ('CA', 'junk', 'junk'),
    ('FR', 'FR12812345678', '812345678'),
    ('DE', 'DE123456789', ''),
    ('', 'CHE123456788', ''),
  ]) {
    final data = legalMentionData(
      const ReportStrings(),
      null,
      reference: _reference,
      seller: InvoiceParty(country: country, vatId: vat, legalId: legal),
    );
    out.writeln(
      '[$country] vat="${data['seller_vat_id']}" legal="${data['seller_legal_id']}"',
    );
  }
  return out.toString();
}

Invoice _invoice({
  String sellerCountry = 'CH',
  String buyerCountry = '',
  String buyerPostal = '8000',
  String buyerCity = 'Zürich',
  int total = 12345,
  bool voided = false,
}) => Invoice(
  id: 'i1',
  workspaceId: 'ws',
  memberId: 'm',
  number: 'INV-2026-0001',
  issuedAt: DateTime.utc(2026, 5, 4, 10),
  title: 'Desk',
  lines: const [],
  totalCents: total,
  currency: 'CHF',
  memberName: 'Ana',
  memberAddress: '',
  workspaceName: 'Space AG',
  workspaceAddress: '',
  issuerName: '',
  signature: '',
  voidedAt: voided ? DateTime.utc(2026, 5, 5) : null,
  sellerParty: InvoiceParty(
    name: 'Space AG',
    street: 'Bahnhofstrasse 12a',
    postalCode: '8001',
    city: 'Zürich',
    country: sellerCountry,
  ),
  buyerParty: InvoiceParty(
    name: 'Ana',
    company: 'Kunde GmbH',
    street: 'Hauptstrasse 3',
    postalCode: buyerPostal,
    city: buyerCity,
    country: buyerCountry,
  ),
);

String _qrBill() {
  const qrIban = 'CH4431999123000889012';
  const iban = 'CH9300762011623852957';
  final out = StringBuffer();
  void row(
    String label,
    Invoice invoice, {
    String workspaceCountry = 'CH',
    bool proforma = false,
  }) {
    final bill = swissQrBillOf(
      invoice,
      iban: iban,
      qrIban: qrIban,
      workspaceCountry: workspaceCountry,
      proforma: proforma,
    );
    out.writeln(
      '[$label] ${bill == null ? 'none' : bill.payload.replaceAll('\n', '|')}',
    );
  }

  row('CH seller', _invoice());
  row('seller ch lower case', _invoice(sellerCountry: ' ch '));
  row('DE seller', _invoice(sellerCountry: 'DE'));
  row('no seller country, workspace CH', _invoice(sellerCountry: ''));
  row(
    'no seller country, workspace DE',
    _invoice(sellerCountry: ''),
    workspaceCountry: 'DE',
  );
  row('proforma', _invoice(), proforma: true);
  row('voided', _invoice(voided: true));
  row('credit note', _invoice(total: -100));
  row('zero', _invoice(total: 0));
  row('buyer without country defaults to CH', _invoice());
  row(
    'buyer in DE',
    _invoice(buyerCountry: 'DE', buyerPostal: '10115', buyerCity: 'Berlin'),
  );
  row('buyer without postal code', _invoice(buyerPostal: ''));
  return out.toString();
}

String _ibans() {
  final out = StringBuffer();
  for (final (label, iban) in [
    ('CH QR-IBAN', 'CH44 3199 9123 0008 8901 2'),
    ('CH plain', 'CH93 0076 2011 6238 5295 7'),
    ('CH bad checksum', 'CH94 0076 2011 6238 5295 7'),
    ('LI QR-IBAN', 'LI19 3100 0123 4567 8901 2'),
    ('LI plain', 'LI21 0881 0000 2324 013A A'),
    ('LI bad checksum', 'LI22 0881 0000 2324 013A A'),
    ('li lower case', 'li21 0881 0000 2324 013a a'),
    ('DE', 'DE89 3704 0044 0532 0130 00'),
    ('too short', 'CH44 3199'),
  ]) {
    out.writeln('[$label] qr=${isQrIban(iban)} swiss=${isSwissIban(iban)}');
  }
  return out.toString();
}

/// The text a one-font PDF page shows, read back through its ToUnicode map.
String _pageText(Uint8List bytes) {
  final text = String.fromCharCodes(bytes);
  final map = <int, int>{};
  for (final m in RegExp(
    r'<([0-9A-Fa-f]{4})>\s*<([0-9A-Fa-f]{4})>',
  ).allMatches(text)) {
    map[int.parse(m.group(1)!, radix: 16)] = int.parse(m.group(2)!, radix: 16);
  }
  final words = <String>[];
  for (final m in RegExp(
    r'\[((?:<[0-9A-Fa-f]+>|[^\]<])*)\]\s*TJ',
  ).allMatches(text)) {
    final word = StringBuffer();
    for (final h in RegExp(r'<([0-9A-Fa-f]+)>').allMatches(m.group(1)!)) {
      final hex = h.group(1)!;
      for (var i = 0; i + 4 <= hex.length; i += 4) {
        word.writeCharCode(
          map[int.parse(hex.substring(i, i + 4), radix: 16)] ?? 63,
        );
      }
    }
    words.add(word.toString());
  }
  return words.join(' ');
}

Future<String> _pdfAddresses() async {
  final font = pw.Font.ttf(
    ByteData.sublistView(
      File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync(),
    ),
  );
  const words = SwissQrBillStrings(
    receipt: 'Receipt',
    paymentPart: 'Payment',
    account: 'Account',
    reference: 'Reference',
    additionalInfo: 'Info',
    payableBy: 'PayableBy',
    payableByAddress: 'PayableByAddress',
    currency: 'Currency',
    amount: 'Amount',
    acceptancePoint: 'Point',
    separate: 'Separate',
  );
  final out = StringBuffer();
  for (final (label, debtor) in [
    (
      'CH debtor',
      const SwissQrAddress(
        name: 'Kunde',
        street: 'Hauptstrasse',
        houseNumber: '3',
        postalCode: '8000',
        city: 'Zuerich',
      ),
    ),
    (
      'DE debtor',
      const SwissQrAddress(
        name: 'Kunde',
        street: 'Hauptstrasse',
        houseNumber: '3',
        postalCode: '10115',
        city: 'Berlin',
        country: 'DE',
      ),
    ),
    ('no debtor', null),
  ]) {
    final bill = SwissQrBill.forInvoice(
      iban: 'CH93 0076 2011 6238 5295 7',
      qrIban: 'CH44 3199 9123 0008 8901 2',
      creditor: const SwissQrAddress(
        name: 'Cowork AG',
        street: 'Rue du Lac',
        houseNumber: '1',
        postalCode: '2501',
        city: 'Biel',
      ),
      debtor: debtor,
      totalCents: 1000,
      currency: 'CHF',
      invoiceNumber: 'INV-1',
    )!;
    final doc = pw.Document(compress: false)
      ..addPage(
        swissQrBillPage(
          bill: bill,
          strings: words,
          baseFont: font,
          boldFont: font,
        ),
      );
    out.writeln('[$label] ${_pageText(await doc.save())}');
  }
  return out.toString();
}

String _vatCompliance() {
  final out = StringBuffer();
  for (final category in ['AE', 'G', 'E', 'Z', 'S', 'O', '']) {
    for (final regime in VatRegime.values) {
      for (final country in ['FR', 'DE', 'GB', 'fr', '']) {
        out.writeln(
          '[$category / ${regime.name} / $country] '
          'code="${exemptionCodeForCategory(category, country, regime)}" '
          'mention="${exemptionMentionFor(category: category, sellerCountry: country, sellerReason: 'own reason', buyerReason: 'buyer reason', regime: regime, reference: _reference)}"',
        );
      }
    }
  }
  return out.toString();
}

void main() {
  test(
    'what an invoice prints by country is what it was before the move',
    () async {
      expectParity(
        dir: 'test/parity/golden/invoice_clauses_print',
        text: {
          'clauses.txt': _clauses(),
          'seller_ids.txt': _sellerIds(),
          'swiss_qr_bill.txt': _qrBill(),
          'swiss_ibans.txt': _ibans(),
          'swiss_qr_bill_pdf.txt': await _pdfAddresses(),
          'vat_compliance.txt': _vatCompliance(),
        },
      );
    },
  );
}
