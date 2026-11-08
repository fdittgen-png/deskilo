// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the national invoice mentions (Italy's stamp duty,
// Spain's correcting invoice, France's category of the operation, Canada's
// registrant numbers), pinned BEFORE they move behind the jurisdiction
// contract. The goldens are written by `nationalInvoiceMentions` as it stands
// and compared byte for byte: the move must change none of them. Rewrite only
// with `UPDATE_PARITY_GOLDENS=1`, never under CI.
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'parity_golden.dart';

List<String> _mentions(
  String country, {
  VatRegime regime = VatRegime.vatRegistered,
  String currency = 'EUR',
  int untaxed = 0,
  bool correction = false,
  String rectifies = '',
  String reason = '',
  String vatId = '',
  String legalId = '',
  bool qst = false,
}) => nationalInvoiceMentions(
  sellerCountry: country,
  regime: regime,
  currency: currency,
  untaxedCents: untaxed,
  correction: correction,
  rectifies: rectifies,
  correctionReason: reason,
  sellerVatId: vatId,
  sellerLegalId: legalId,
  qstCharged: qst,
  reference: ActiveTaxReference.current,
);

/// One golden: a scenario per line, `name => the mentions, '|'-separated`.
String _page(Map<String, List<String>> scenarios) {
  final lines = [
    for (final e in scenarios.entries) '${e.key} => ${e.value.join(' | ')}',
  ];
  return '${lines.join('\n')}\n';
}

void main() {
  test('the national mentions are what the invoice model wrote before the '
      'move', () {
    final others = [
      for (final c in ['DE', 'CH', 'GB', 'PL', 'AT', '', 'XX'])
        MapEntry(
          c.isEmpty ? 'empty' : c,
          _mentions(
            c,
            untaxed: 50000,
            correction: true,
            rectifies: 'F-1',
            vatId: '123456789RT0001',
            legalId: '1234567890TQ0001',
            qst: true,
          ),
        ),
    ];
    expectParity(
      dir: 'test/parity/golden/national_mentions',
      text: {
        'it.txt': _page({
          'at the threshold': _mentions('IT', untaxed: 7747),
          'above the threshold': _mentions('IT', untaxed: 7748),
          'far above': _mentions('IT', untaxed: 500000),
          'above, in dollars': _mentions('IT', untaxed: 50000, currency: 'USD'),
          'above, lowercase euro': _mentions('IT', untaxed: 8000, currency: 'eur'),
          'above, exempt seller': _mentions(
            'IT',
            untaxed: 8000,
            regime: VatRegime.exempt,
          ),
          'lowercase country': _mentions('it', untaxed: 8000),
          'padded country': _mentions(' IT ', untaxed: 8000),
        }),
        'es.txt': _page({
          'ordinary': _mentions('ES'),
          'correction, nothing rectified': _mentions('ES', correction: true),
          'correction, rectifies': _mentions(
            'ES',
            correction: true,
            rectifies: 'F-2026-0007',
          ),
          'rectifies is blank': _mentions(
            'ES',
            correction: true,
            rectifies: '   ',
          ),
          for (final code in ['R1', 'R2', 'R3', 'R4', 'R5', 'r3', ' R4 ', 'R9', ''])
            "reason '$code'": _mentions(
              'ES',
              correction: true,
              rectifies: 'F-2026-0007',
              reason: code,
            ),
          "reason R1, nothing rectified": _mentions(
            'ES',
            correction: true,
            reason: 'R1',
          ),
          'lowercase country': _mentions('es', correction: true, rectifies: 'F-1'),
        }),
        'fr.txt': _page({
          'registered': _mentions('FR'),
          'exempt': _mentions('FR', regime: VatRegime.exempt),
          'not subject': _mentions('FR', regime: VatRegime.notSubject),
          'lowercase country': _mentions('fr'),
        }),
        'ca.txt': _page({
          'registered, vat number': _mentions('CA', vatId: '123456789rt0001'),
          'registered, both numbers, qst': _mentions(
            'CA',
            vatId: '123456789rt0001',
            legalId: '1234567890TQ0001',
            qst: true,
          ),
          'registered, qst not charged': _mentions(
            'CA',
            vatId: '123456789rt0001',
            legalId: '1234567890TQ0001',
          ),
          'registered, qst but no number': _mentions('CA', vatId: '1', qst: true),
          'registered, no numbers': _mentions('CA'),
          'blank numbers': _mentions('CA', vatId: '  ', legalId: ' ', qst: true),
          'not a number': _mentions('CA', vatId: 'not a number'),
          'exempt': _mentions(
            'CA',
            regime: VatRegime.exempt,
            vatId: '123456789rt0001',
          ),
          'lowercase country': _mentions('ca', vatId: '123456789rt0001'),
        }),
        'others.txt': _page({for (final e in others) e.key: e.value}),
      },
    );
  });
}
