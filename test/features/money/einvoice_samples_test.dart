// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2358 — one sample per e-invoice format, written where the
// `einvoice-validate` workflow runs the official validators on them
// (KoSIT with the XRechnung and Peppol BIS configurations, Mustang for
// Factur-X, the SdI and KSeF schemas). Without EINVOICE_SAMPLES_DIR the
// test only proves every sample builds and parses, so the suite stays
// offline; the validators run in CI, at pinned versions.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/features/money/domain/einvoice_format.dart';
import 'package:deskilo/features/money/domain/einvoice_input.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_cii.dart';
import 'package:deskilo/features/money/domain/invoice_fatturapa.dart';
import 'package:deskilo/features/money/domain/invoice_ksef_fa3.dart';
import 'package:deskilo/features/money/domain/invoice_line_text.dart';
import 'package:deskilo/features/money/domain/invoice_pdf.dart';
import 'package:deskilo/features/money/domain/invoice_ubl.dart';
import 'package:deskilo/features/money/domain/report_strings.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';

import '../../helpers/einvoice_samples.dart';

/// A VAT-registered French space invoicing a French company: 20 % on a
/// subscription and on two overage days, paid by transfer within 30 days.
Invoice _invoice() => Invoice(
  id: 'inv-1',
  workspaceId: 'ws-1',
  memberId: 'member-1',
  number: 'F-2026-0042',
  issuedAt: DateTime(2026, 9, 30),
  period: '2026-09',
  title: '2026-09',
  lines: const [
    InvoiceLine(
      kind: 'subscription',
      label: '50',
      amountCents: 24000,
      vatPercent: 20,
      vatCategory: 'S',
    ),
    InvoiceLine(
      kind: 'overage',
      label: '',
      quantity: 2,
      amountCents: 4800,
      vatPercent: 20,
      vatCategory: 'S',
    ),
  ],
  vatTotals: const [
    InvoiceVatTotal(
      percent: 20,
      category: 'S',
      grossCents: 28800,
      netCents: 24000,
      vatCents: 4800,
    ),
  ],
  totalCents: 28800,
  currency: 'EUR',
  memberName: 'Atelier Nord SARL',
  memberAddress: '1 Rue Test\n34120 Pézenas',
  workspaceName: 'Test Space',
  workspaceAddress: '2 Place du Marché',
  issuerName: 'Flo',
  signature: 'f' * 64,
  // #2358 — the French payment mentions (BR-FR-05), as frozen.
  legalSnapshot: const {
    'schema': 1,
    'seller_country': 'FR',
    'buyer_country': 'FR',
    'clauses': {
      'late_penalty': 'Pénalités de retard : trois fois le taux légal.',
      'recovery_indemnity':
          'Indemnité forfaitaire pour frais de recouvrement : 40 €.',
      'escompte': 'Pas d’escompte pour paiement anticipé.',
    },
  },
);

const _seller = InvoiceParty(
  name: 'Test Space SAS',
  street: '2 Place du Marché',
  city: 'Pézenas',
  postalCode: '34120',
  country: 'FR',
  vatId: 'FR32812345678',
  legalId: '812345678',
  vatRegime: 'vat_registered',
  endpointId: '812345678',
  endpointScheme: '0225',
  email: 'billing@test-space.example',
  phone: '+33 4 00 00 00 00',
);

const _buyer = InvoiceParty(
  name: 'Atelier Nord SARL',
  street: '1 Rue Test',
  city: 'Pézenas',
  postalCode: '34120',
  country: 'FR',
  vatId: 'FR40303265045',
  legalId: '303265045',
  endpointId: '303265045',
  endpointScheme: '0225',
  email: 'compta@atelier-nord.example',
);

/// The same month billed once at a single national rate: [gross] at
/// [percent] %, split as the server would freeze it.
Invoice _nationalInvoice({
  required String currency,
  required double percent,
  required int gross,
  required int net,
}) => _invoice().copyWith(
  currency: currency,
  lines: [
    InvoiceLine(
      kind: 'subscription',
      label: '50',
      amountCents: gross,
      vatPercent: percent,
      vatCategory: 'S',
    ),
  ],
  vatTotals: [
    InvoiceVatTotal(
      percent: percent,
      category: 'S',
      grossCents: gross,
      netCents: net,
      vatCents: gross - net,
    ),
  ],
  totalCents: gross,
);

const _sellerIt = InvoiceParty(
  name: 'Spazio Prova S.r.l.',
  street: 'Via Roma 1',
  city: 'Milano',
  postalCode: '20121',
  country: 'IT',
  subdivision: 'MI',
  vatId: 'IT01234567897',
  legalId: '01234567897',
  vatRegime: 'vat_registered',
);

const _buyerIt = InvoiceParty(
  name: 'Studio Nord S.r.l.',
  street: 'Corso Italia 10',
  city: 'Torino',
  postalCode: '10121',
  country: 'IT',
  subdivision: 'TO',
  vatId: 'IT09876543217',
  endpointId: 'KRRH6B9',
);

const _sellerPl = InvoiceParty(
  name: 'Przestrzen Testowa Sp. z o.o.',
  street: 'ul. Prosta 1',
  city: 'Warszawa',
  postalCode: '00-850',
  country: 'PL',
  vatId: 'PL5260001246',
  vatRegime: 'vat_registered',
);

const _buyerPl = InvoiceParty(
  name: 'Pracownia Polnoc Sp. z o.o.',
  street: 'ul. Dluga 5',
  city: 'Krakow',
  postalCode: '31-147',
  country: 'PL',
  vatId: 'PL6750001923',
);

/// Belgium: both parties addressed by their enterprise number on Peppol.
const _sellerBe = InvoiceParty(
  name: 'Test Space BV',
  street: 'Rue de la Loi 1',
  city: 'Bruxelles',
  postalCode: '1000',
  country: 'BE',
  vatId: 'BE0123456749',
  legalId: '0123456749',
  vatRegime: 'vat_registered',
  endpointId: '0123456749',
  endpointScheme: '0208',
  email: 'billing@test-space.example',
);

const _buyerBe = InvoiceParty(
  name: 'Client NV',
  street: 'Boulevard du Roi Albert II 27',
  city: 'Bruxelles',
  postalCode: '1030',
  country: 'BE',
  vatId: 'BE0202239951',
  legalId: '0202239951',
  endpointId: '0202239951',
  endpointScheme: '0208',
  reference: 'PO-778',
);

/// Germany: a public buyer, addressed — and referenced — by its
/// Leitweg-ID, as XRechnung demands.
const _sellerDe = InvoiceParty(
  name: 'Test Space GmbH',
  street: 'Hauptstraße 1',
  city: 'Berlin',
  postalCode: '10115',
  country: 'DE',
  vatId: 'DE123456789',
  legalId: 'HRB 12345',
  vatRegime: 'vat_registered',
  endpointId: 'billing@test-space.example',
  endpointScheme: 'EM',
  email: 'billing@test-space.example',
  phone: '+49 30 000000',
);

const _buyerDe = InvoiceParty(
  name: 'Bezirksamt Mitte',
  street: 'Karl-Marx-Allee 31',
  city: 'Berlin',
  postalCode: '10178',
  country: 'DE',
  endpointId: '04011000-12345-34',
  endpointScheme: leitwegIdScheme,
  reference: '04011000-12345-34',
);

/// Romania: each address names its county.
const _sellerRo = InvoiceParty(
  name: 'Test Space SRL',
  street: 'Strada Exemplu 1',
  city: 'SECTOR1',
  postalCode: '010011',
  country: 'RO',
  subdivision: 'RO-B',
  vatId: 'RO1234567',
  legalId: 'J40/1234/2020',
  vatRegime: 'vat_registered',
);

const _buyerRo = InvoiceParty(
  name: 'Client SRL',
  street: 'Strada Client 2',
  city: 'Cluj-Napoca',
  postalCode: '400001',
  country: 'RO',
  subdivision: 'RO-CJ',
  vatId: 'RO7654321',
  legalId: '7654321',
);

String _line(InvoiceLine line) => invoiceLineText(const ReportStrings(), line);

pw.Font _ttf(String path) =>
    pw.Font.ttf(ByteData.sublistView(File(path).readAsBytesSync()));

const _pdfStrings = InvoicePdfStrings(
  invoiceTitle: 'Invoice',
  issuedOn: 'Issued on',
  issuedBy: 'Issued by',
  billedTo: 'Billed to',
  total: 'Balance due',
  signature: 'Digital signature (SHA-256)',
  voided: 'ERRONEOUS',
  voidedWatermark: 'Erroneous',
  proforma: 'Proforma',
  replaces: 'Replaces',
  description: 'Description',
  charges: 'Charges',
  payments: 'Payments',
  annex: 'Annex — details',
  attendance: 'Check-ins',
  activity: 'Bookings & payments',
  reserved: 'reserved',
  page: 'Page',
);

/// format id → file name and bytes.
Future<Map<String, Uint8List>> _samples() async {
  final invoice = _invoice();
  final ubl = buildInvoiceUbl(EInvoiceInput(invoice: invoice,
    seller: _seller,
    buyer: _buyer,
    lineText: _line,
    iban: 'FR7630006000011234567890189'));
  final cii = buildInvoiceCii(EInvoiceInput(invoice: invoice,
    seller: _seller,
    buyer: _buyer,
    lineText: _line,
    iban: 'FR7630006000011234567890189'));
  final pdf = await buildInvoicePdf(
    invoice: invoice,
    strings: _pdfStrings,
    money: (cents) => '${(cents / 100).toStringAsFixed(2)} EUR',
    lineText: _line,
    activityText: (entry) => '',
    dateLabel: 'Sep 30, 2026',
    facturXml: cii,
    colorProfile: File('assets/pdf/sRGB2014.icc').readAsBytesSync(),
    baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
    boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
  );
  final fatturaPa = buildInvoiceFatturaPa(
    invoice: _nationalInvoice(
      currency: 'EUR',
      percent: 22,
      gross: 24400,
      net: 20000,
    ),
    seller: _sellerIt,
    buyer: _buyerIt,
    lineText: _line,
    iban: 'IT60X0542811101000000123456',
    dueDate: DateTime(2026, 10, 30),
  );
  final ksef = buildInvoiceKsefFa3(
    invoice: _nationalInvoice(
      currency: 'PLN',
      percent: 23,
      gross: 24600,
      net: 20000,
    ),
    seller: _sellerPl,
    buyer: _buyerPl,
    lineText: _line,
    iban: 'PL61109010140000071219812874',
    dueDate: DateTime(2026, 10, 30),
  );
  String profiled(
    UblProfile profile,
    Invoice invoice,
    InvoiceParty seller,
    InvoiceParty buyer,
    String iban,
  ) => buildInvoiceUbl(EInvoiceInput(invoice: invoice,
    seller: seller,
    buyer: buyer,
    lineText: _line,
    iban: iban,
    dueDate: DateTime(2026, 10, 30),
    paymentTerms: '30 days net'),
    profile: profile);
  return {
    'en16931-ubl.xml': utf8.encode(ubl),
    'peppol-bis.xml': utf8.encode(
      profiled(
        UblProfile.peppolBis,
        _nationalInvoice(
          currency: 'EUR',
          percent: 21,
          gross: 24200,
          net: 20000,
        ),
        _sellerBe,
        _buyerBe,
        'BE68539007547034',
      ),
    ),
    'xrechnung.xml': utf8.encode(
      profiled(
        UblProfile.xrechnung,
        _nationalInvoice(
          currency: 'EUR',
          percent: 19,
          gross: 23800,
          net: 20000,
        ),
        _sellerDe,
        _buyerDe,
        'DE02120300000000202051',
      ),
    ),
    'cius-ro.xml': utf8.encode(
      profiled(
        UblProfile.ciusRo,
        _nationalInvoice(
          currency: 'RON',
          percent: 19,
          gross: 23800,
          net: 20000,
        ),
        _sellerRo,
        _buyerRo,
        'RO49AAAA1B31007593840000',
      ),
    ),
    'fatturapa.xml': utf8.encode(fatturaPa),
    'ksef-fa3.xml': utf8.encode(ksef),
    'en16931-cii.xml': utf8.encode(cii),
    'factur-x.pdf': pdf,
  };
}

void main() {
  test(
    'every e-invoice sample builds, and lands where CI validates it',
    () async {
      final samples = await _samples();
      for (final MapEntry(:key, :value) in samples.entries) {
        if (key.endsWith('.xml')) {
          expect(
            () => XmlDocument.parse(utf8.decode(value)),
            returnsNormally,
            reason: key,
          );
        }
      }
      expect(
        samples.keys.toSet(),
        eInvoiceSampleFiles.values.toSet(),
        reason: 'one sample per format the app claims is validated',
      );
      final dir = Platform.environment['EINVOICE_SAMPLES_DIR'] ?? '';
      if (dir.isEmpty) return;
      Directory(dir).createSync(recursive: true);
      for (final MapEntry(:key, :value) in samples.entries) {
        File('$dir/$key').writeAsBytesSync(value);
      }
    },
  );
}
