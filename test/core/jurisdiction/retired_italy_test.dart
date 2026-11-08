// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3338 (of #3328) -- Italy is retired and the rest of the product keeps
// working. The host is composed WITHOUT the Italian invoice profile and the
// Italian VAT filing: every other country still resolves, the other invoice
// syntaxes are still built, a FatturaPA request is an explicit refusal (never
// another syntax, never a fallback), and what was already issued, sent and
// received through Italy is still readable.
import 'package:deskilo/core/jurisdiction/jurisdiction_resolver.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/application/channel_einvoice_xml.dart';
import 'package:deskilo/features/money/application/jurisdiction/installed_invoice_profiles.dart';
import 'package:deskilo/features/money/application/jurisdiction/installed_vat_filings.dart';
import 'package:deskilo/features/money/domain/einvoice_format.dart';
import 'package:deskilo/features/money/domain/einvoice_gateway.dart';
import 'package:deskilo/features/money/domain/einvoice_input.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_line_text.dart';
import 'package:deskilo/features/money/domain/report_strings.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:flutter_test/flutter_test.dart';

const _seller = InvoiceParty(
  name: 'Atelier Nord',
  street: '1 rue de Paris',
  city: 'Paris',
  postalCode: '75001',
  country: 'FR',
  vatId: 'FR12345678901',
  vatRegime: 'vat_registered',
);

const _buyer = InvoiceParty(
  name: 'Studio Sud',
  street: '2 rue de Lyon',
  city: 'Lyon',
  postalCode: '69001',
  country: 'FR',
  vatId: 'FR98765432109',
  endpointScheme: '0009',
  endpointId: '12345678901234',
);

Invoice _invoice() => Invoice(
  id: 'inv-1',
  workspaceId: 'ws-1',
  memberId: 'member-1',
  number: 'FR-2026/0001',
  issuedAt: DateTime(2026, 9, 30),
  period: '2026-09',
  title: '2026-09',
  lines: const [
    InvoiceLine(
      kind: 'subscription',
      label: '50',
      amountCents: 12000,
      vatPercent: 20,
      vatCategory: 'S',
    ),
  ],
  vatTotals: const [
    InvoiceVatTotal(
      percent: 20,
      category: 'S',
      grossCents: 12000,
      netCents: 10000,
      vatCents: 2000,
    ),
  ],
  totalCents: 12000,
  currency: 'EUR',
  memberName: 'Studio Sud',
  memberAddress: '',
  workspaceName: 'Atelier Nord',
  workspaceAddress: '',
  issuerName: 'Flo',
  signature: 'f' * 64,
);

EInvoiceInput get _input => EInvoiceInput(
  invoice: _invoice(),
  seller: _seller,
  buyer: _buyer,
  lineText: (line) => invoiceLineText(const ReportStrings(), line), reference: ActiveTaxReference.current,
);

/// The installed composition with the Italian profile retired.
final _withoutItaly = [
  for (final p in installedInvoiceProfiles)
    if (p.descriptor.moduleId != 'it.invoice_profile.fatturapa') p,
];

void main() {
  test(
    'without the Italian invoice profile, every other syntax is still built',
    () {
      for (final format in [
        EInvoiceFormat.en16931Ubl,
        EInvoiceFormat.peppolBis,
        EInvoiceFormat.xrechnung,
        EInvoiceFormat.ciusRo,
        EInvoiceFormat.en16931Cii,
        EInvoiceFormat.ksefFa3,
      ]) {
        final xml = buildChannelEInvoiceXml(
          format,
          _input,
          profiles: _withoutItaly,
        );
        expect(xml, startsWith('<?xml'), reason: format.name);
        expect(xml, contains('FR-2026/0001'), reason: format.name);
      }
    },
  );

  test('a KSeF request without the Polish profile is refused while FatturaPA '
      'and the EN 16931 syntaxes are still built (#3429)', () {
    final withoutPoland = [
      for (final p in installedInvoiceProfiles)
        if (p.descriptor.moduleId != 'pl.invoice_profile.ksef_fa3') p,
    ];
    expect(
      () => buildChannelEInvoiceXml(
        EInvoiceFormat.ksefFa3,
        _input,
        profiles: withoutPoland,
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'no invoice profile for ksefFa3: unknownProfile',
        ),
      ),
    );
    for (final format in [EInvoiceFormat.fatturaPa, EInvoiceFormat.en16931Ubl]) {
      expect(
        buildChannelEInvoiceXml(format, _input, profiles: withoutPoland),
        startsWith('<?xml'),
        reason: format.name,
      );
    }
  });

  test('a FatturaPA request without its profile is refused, not rendered in '
      'another syntax', () {
    expect(
      () => buildChannelEInvoiceXml(
        EInvoiceFormat.fatturaPa,
        _input,
        profiles: const [],
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'no invoice profile for fatturaPa: unknownProfile',
        ),
      ),
    );
  });

  test('without the Italian VAT filing the other six countries still resolve '
      'and Italy is an explicit refusal', () {
    final installed = [
      for (final c in installedVatFilings)
        if (c.descriptor.capabilityId != 'vat_filing.IT') c,
    ];
    for (final country in ['DE', 'FR', 'GB', 'CH', 'CA', 'ES']) {
      expect(
        resolveCapability(
          JurisdictionOperation.vatFiling,
          LegalContext(countryCode: country),
          installed,
        ),
        isA<Resolved>(),
        reason: country,
      );
    }
    final italy = resolveCapability(
      JurisdictionOperation.vatFiling,
      const LegalContext(countryCode: 'IT'),
      installed,
    );
    expect((italy as Refused).kind, RefusalKind.unknownJurisdiction);
  });

  test('what was sent through Italy stays readable: the transmission row '
      'decodes with its provider, syntax, receipt and document hash', () {
    final row = <String, dynamic>{
      'invoice_id': 'inv-9',
      'id': 'tx-9',
      'phase': 'settled',
      'status': 'accepted',
      'sent_at': '2026-05-01T09:00:00Z',
      'provider': 'it_sdi',
      'format': 'fatturaPa',
      'external_id': 'uuid-123',
      'document_hash': 'a' * 64,
      'receipt': {'notification': 'RC'},
      'receipt_at': '2026-05-01T09:05:00Z',
      'environment': 'prod',
      'destination': 'government',
    };
    final t = InvoiceTransmission.fromRow(row);
    expect(t.provider, 'it_sdi');
    expect(t.format, EInvoiceFormat.fatturaPa.name);
    expect(t.externalId, 'uuid-123');
    expect(t.documentHash, 'a' * 64);
    expect(t.receipt['notification'], 'RC');
    expect(t.receiptAt, isNotNull);
  });
}
