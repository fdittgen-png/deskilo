// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4135 -- what a payer reads at the provider names the business they pay,
// never the product: no order adapter of create-payment-order sends the
// product's name in a string (payer_text.ts builds the text from the
// business's own name and the reference).

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// [source] without its comments: what is sent, not what is explained.
String code(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .split('\n')
    .map((l) => l.contains('//') ? l.substring(0, l.indexOf('//')) : l)
    .join('\n');

void main() {
  test('the product name is found in a string, not in a comment', () {
    expect(
      code('// DesKilo explains\nconst a = 1;').contains('DesKilo'),
      isFalse,
    );
    expect(code('const name = `DesKilo \${ref}`;').contains('DesKilo'), isTrue);
  });

  test('no order adapter sends the product name to a provider', () {
    final offenders = [
      for (final f in filesWithExtension(
        'supabase/functions/create-payment-order',
        '.ts',
      ))
        if (!f.path.endsWith('_test.ts') &&
            code(f.readAsStringSync()).contains('DesKilo'))
          f.path,
    ];
    expect(
      offenders,
      isEmpty,
      reason: 'what a payer reads names the business (payer_text.ts), never the product',
    );
  });
}
