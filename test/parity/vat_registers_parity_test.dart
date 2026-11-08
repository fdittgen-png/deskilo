// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- which registers of issued invoices a country's law asks
// for in a file the app writes, pinned BEFORE the rule moves behind the VAT
// filing contract: Spain (the libro, the SII message, the modelo 347), Italy
// (the registro delle fatture emesse) and nobody else, in the order the
// declarations screen lists them. The move must change none of these answers.
import 'package:deskilo/features/money/domain/vat_registers.dart';
import 'package:flutter_test/flutter_test.dart';

const _expected = <String, List<VatRegisterKind>>{
  'ES': [VatRegisterKind.esLibro, VatRegisterKind.esSii, VatRegisterKind.es347],
  'IT': [VatRegisterKind.itRegistro],
  'FR': [],
  'DE': [],
  'CH': [],
  'GB': [],
  'CA': [],
  'PL': [],
  'AT': [],
  'IE': [],
  'US': [],
  'ZZ': [],
  '': [],
};

void main() {
  test('every country\'s registers are what they were before the move', () {
    for (final e in _expected.entries) {
      expect(vatRegistersFor(e.key), e.value, reason: e.key);
    }
  });

  test('the spellings the callers pass are accepted alike', () {
    expect(vatRegistersFor('es'), _expected['ES']);
    expect(vatRegistersFor(' ES '), _expected['ES']);
    expect(vatRegistersFor('it'), _expected['IT']);
    expect(vatRegistersFor(' It'), _expected['IT']);
  });
}
