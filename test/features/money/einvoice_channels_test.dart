// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2358 — which syntax each channel receives, what each channel still
// needs before Send is offered, and the dated mandate warnings: FR and DE
// sellers are told what comes next, and every seller whose national
// channel does not exist yet stays refused at issue.
import 'package:deskilo/features/money/domain/einvoice_channel_check.dart';
import 'package:deskilo/features/money/domain/einvoice_format.dart';
import 'package:deskilo/features/money/domain/einvoice_mandates.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_clauses.dart';
import 'package:flutter_test/flutter_test.dart';

const _seller = InvoiceParty(
  name: 'Test Space',
  country: 'DE',
  vatId: 'DE123456789',
  email: 'billing@test.example',
  phone: '+49 30 000000',
  endpointId: 'billing@test.example',
  endpointScheme: 'EM',
);

const _buyer = InvoiceParty(
  name: 'Bezirksamt',
  country: 'DE',
  endpointId: '04011000-12345-34',
  endpointScheme: leitwegIdScheme,
  reference: '04011000-12345-34',
);

void main() {
  group('the channel decides the syntax', () {
    test('a network gets XML, a person gets the Factur-X PDF', () {
      EInvoiceFormat f(String provider, [String scheme = '']) =>
          eInvoiceFormatFor(
            provider: provider,
            destination: 'government',
            buyerEndpointScheme: scheme,
          );
      expect(f('peppol'), EInvoiceFormat.peppolBis);
      expect(
        f('peppol', leitwegIdScheme),
        EInvoiceFormat.xrechnung,
        reason: 'a German public body receives XRechnung',
      );
      expect(f('fr_pa'), EInvoiceFormat.en16931Cii);
      expect(f('it_sdi'), EInvoiceFormat.fatturaPa);
      expect(f('pl_ksef'), EInvoiceFormat.ksefFa3);
      expect(f('ro_efactura'), EInvoiceFormat.ciusRo);
      expect(
        f('generic'),
        EInvoiceFormat.facturX,
        reason: 'the generic upload keeps what its platforms expect',
      );
      for (final provider in [
        'generic',
        'peppol',
        'fr_pa',
        'it_sdi',
        'pl_ksef',
        'ro_efactura',
      ]) {
        expect(
          eInvoiceFormatFor(provider: provider, destination: 'customer'),
          EInvoiceFormat.facturX,
          reason: 'the customer leg is read by a person',
        );
      }
    });

    test('only the XML formats are sent as XML', () {
      for (final format in EInvoiceFormat.values) {
        expect(
          format.mimeType,
          format == EInvoiceFormat.facturX
              ? 'application/pdf'
              : 'application/xml',
        );
      }
    });
  });

  group('what a channel still needs', () {
    test('a complete XRechnung party pair needs nothing', () {
      expect(
        channelGaps(
          EInvoiceFormat.xrechnung,
          seller: _seller,
          buyer: _buyer,
          iban: 'DE02120300000000202051',
        ),
        isEmpty,
      );
    });

    test('XRechnung names each missing element', () {
      expect(
        channelGaps(
          EInvoiceFormat.xrechnung,
          seller: _seller.copyWith(endpointId: '', phone: ''),
          buyer: _buyer.copyWith(reference: '', endpointId: ''),
        ),
        [
          ChannelGap.sellerEndpoint,
          ChannelGap.buyerEndpoint,
          ChannelGap.leitwegId,
          ChannelGap.paymentAccount,
          ChannelGap.sellerContact,
        ],
      );
    });

    test('Peppol takes an order number when there is no buyer reference', () {
      final buyer = _buyer.copyWith(reference: '', orderReference: 'PO-1');
      expect(
        channelGaps(EInvoiceFormat.peppolBis, seller: _seller, buyer: buyer),
        isEmpty,
      );
      expect(
        channelGaps(
          EInvoiceFormat.peppolBis,
          seller: _seller,
          buyer: buyer.copyWith(orderReference: ''),
        ),
        [ChannelGap.buyerReference],
      );
    });

    test('a French platform needs both electronic addresses (BR-FR-12/13)', () {
      expect(
        channelGaps(
          EInvoiceFormat.en16931Cii,
          seller: _seller.copyWith(endpointId: ''),
          buyer: _buyer.copyWith(endpointId: ''),
        ),
        [ChannelGap.sellerEndpoint, ChannelGap.buyerEndpoint],
      );
    });

    test('CIUS-RO needs the county of a Romanian address only', () {
      const ro = InvoiceParty(name: 'X', country: 'RO');
      expect(channelGaps(EInvoiceFormat.ciusRo, seller: ro, buyer: _buyer), [
        ChannelGap.subdivision,
      ]);
      expect(
        channelGaps(
          EInvoiceFormat.ciusRo,
          seller: ro.copyWith(subdivision: 'RO-B'),
          buyer: _buyer,
        ),
        isEmpty,
        reason: 'a foreign buyer has no Romanian county',
      );
    });

    test('FatturaPA and FA(3) identify by VAT number', () {
      const bare = InvoiceParty(name: 'X');
      expect(channelGaps(EInvoiceFormat.fatturaPa, seller: bare, buyer: bare), [
        ChannelGap.sellerVatId,
        ChannelGap.buyerTaxId,
      ]);
      expect(channelGaps(EInvoiceFormat.ksefFa3, seller: bare, buyer: bare), [
        ChannelGap.sellerVatId,
      ]);
    });

    test('the download formats need nothing beyond the norm', () {
      const bare = InvoiceParty(name: 'X');
      expect(
        channelGaps(EInvoiceFormat.facturX, seller: bare, buyer: bare),
        isEmpty,
      );
      expect(
        channelGaps(EInvoiceFormat.en16931Ubl, seller: bare, buyer: bare),
        isEmpty,
      );
    });
  });

  group('the mandate calendar', () {
    final today = DateTime(2026, 10, 11);

    test('the dates are the ones the laws set', () {
      String day(String country, MandateDuty duty) =>
          mandatesFor(country)
              .firstWhere((m) => m.duty == duty)
              .from
              .toIso8601String()
              .split('T')
              .first;
      expect(day('FR', MandateDuty.receiveAll), '2026-09-01');
      expect(day('FR', MandateDuty.issueAll), '2027-09-01');
      expect(day('DE', MandateDuty.receiveAll), '2025-01-01');
      expect(day('DE', MandateDuty.issueLarge), '2027-01-01');
      expect(day('DE', MandateDuty.issueAll), '2028-01-01');
      expect(day('BE', MandateDuty.issueAll), '2026-01-01');
      expect(day('PL', MandateDuty.issueAll), '2026-04-01');
      expect(day('ES', MandateDuty.invoiceRecords), '2027-01-01');
    });

    test('a French seller is warned of what is due and what is new', () {
      final warnings = mandateWarnings('fr', today);
      expect(warnings.map((m) => m.duty), [
        MandateDuty.receiveAll,
        MandateDuty.issueLarge,
        MandateDuty.eReporting,
        MandateDuty.issueAll,
      ]);
      expect(
        warnings.last.inForceOn(today),
        isFalse,
        reason: 'issuing for every business is still ahead in 2027',
      );
    });

    test('a German seller is warned of 2027 and 2028, not of 2025', () {
      expect(mandateWarnings('DE', today).map((m) => m.duty), [
        MandateDuty.issueLarge,
        MandateDuty.issueAll,
      ]);
    });

    test('IT, ES, PL and RO sellers stay refused at issue', () {
      for (final country in ['IT', 'ES', 'PL', 'RO']) {
        expect(mandateWarnings(country, today), isEmpty, reason: country);
        expect(
          legalProfileOf(LegalClauseSnapshot(sellerCountry: country)),
          LegalProfile.unsupported,
          reason:
              '$country is refused (seller_country_unsupported) until '
              'its national channel exists',
        );
      }
    });

    test('the warned countries are exactly the ones allowed to issue', () {
      for (final country in mandateWarningCountries) {
        expect(
          legalProfileOf(LegalClauseSnapshot(sellerCountry: country)),
          isNot(LegalProfile.unsupported),
          reason: country,
        );
      }
    });
  });
}
