// SPDX-License-Identifier: 0BSD
//
// Where an EN 16931 export has to GO. The XML alone answered nothing: the
// routing table names the channel and the syntax per country, and says
// honestly where this file is NOT the accepted one.
import 'package:deskilo/features/money/domain/e_invoice_routing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('outside the EU there is no route at all', () {
    expect(eInvoiceRouteFor('CH'), isNull);
    expect(eInvoiceRouteFor('US'), isNull);
    expect(eInvoiceRouteFor(''), isNull);
  });

  test('France routes through an accredited platform, Chorus Pro for B2G',
      () {
    final route = eInvoiceRouteFor('fr')!;
    expect(route.transport, EInvoiceTransport.accredited);
    expect(route.publicChannel, contains('Chorus Pro'));
    expect(route.ublAccepted, isTrue,
        reason: 'UBL is one of the reform\'s three accepted syntaxes');
  });

  test('Belgium is the Peppol mandate', () {
    final route = eInvoiceRouteFor('BE')!;
    expect(route.transport, EInvoiceTransport.peppol);
    expect(route.businessChannel, 'Peppol');
  });

  test('clearance countries take their own syntax, not this file', () {
    for (final code in ['IT', 'PL', 'RO']) {
      final route = eInvoiceRouteFor(code)!;
      expect(route.transport, EInvoiceTransport.clearance,
          reason: '$code puts a national platform in the path');
      expect(route.ublAccepted, isFalse,
          reason: '$code mandates its own syntax — the sheet must warn');
    }
  });

  test('Germany imposes no channel but expects an EN 16931 syntax', () {
    final route = eInvoiceRouteFor('DE')!;
    expect(route.transport, EInvoiceTransport.bilateral);
    expect(route.businessFormat, contains('XRechnung'));
    expect(route.ublAccepted, isTrue);
  });

  test('an EU country without its own mandate falls back to Peppol', () {
    final route = eInvoiceRouteFor('IE')!;
    expect(route.transport, EInvoiceTransport.bilateral);
    expect(route.businessChannel, 'Peppol');
    expect(route.publicChannel, 'Peppol',
        reason: 'Directive 2014/55/EU: every public buyer can receive one');
  });
}
