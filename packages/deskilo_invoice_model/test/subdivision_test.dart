// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3649 -- the one mapping from a stored region to what an e-invoice writes.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:test/test.dart';

void main() {
  test('the part after the country, whichever way it was stored', () {
    expect(subdivisionPart('RO', 'B'), 'B');
    expect(subdivisionPart('RO', 'ro-b'), 'B');
    expect(subdivisionPart('it', ' mi '), 'MI');
    expect(subdivisionPart('RO', ''), '');
  });

  test('the whole ISO 3166-2 code, and nothing for no region', () {
    expect(subdivisionIso('RO', 'B'), 'RO-B');
    expect(subdivisionIso('RO', 'RO-CJ'), 'RO-CJ');
    expect(subdivisionIso('RO', ''), '');
  });
}
