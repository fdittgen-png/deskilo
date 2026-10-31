// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2578 — a BI amount is shown with its currency's own minor digits: none
// for the yen, three for the Bahraini dinar, never a euro's two.
import 'package:deskilo/features/workspace/presentation/widgets/bi_module_section.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a 0-decimal currency shows whole units', () {
    final text = biMoneyCell(1250, 'en', 'JPY');
    expect(text, contains('1,250'));
    expect(text, isNot(contains('.')));
  });

  test('a 3-decimal currency shows three minor digits', () {
    expect(biMoneyCell(1250, 'en', 'BHD'), contains('1.250'));
    expect(biMoneyCell(1250, 'en', 'KWD'), contains('1.250'));
  });

  test('a 2-decimal currency shows two', () {
    expect(biMoneyCell(1250, 'en', 'EUR'), contains('12.50'));
  });

  test('no currency is a dash, never a default euro', () {
    expect(biMoneyCell(1250, 'en', null), '—');
    expect(biMoneyCell(1250, 'en', ''), '—');
    expect(biMoneyCell(null, 'en', 'EUR'), '—');
  });
}
