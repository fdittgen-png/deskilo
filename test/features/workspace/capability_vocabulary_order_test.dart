// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1869 — when a label on the screen and a synonym are the same phrase,
// the label wins, and the answer does not depend on how many other
// capabilities the vocabulary holds (List.sort is not stable; adding
// one flag used to flip "Carnets" from the feature to credit packs).
import 'package:deskilo/features/workspace/domain/template_capabilities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the screen label beats a synonym of the same phrase', () {
    final v = CapabilityVocabulary({'feature.carnets': ['Carnets']});
    expect(v.parse('Carnets').capabilities, ['feature.carnets']);
  });

  test('growing the vocabulary does not change the answer', () {
    for (var extra = 0; extra < 40; extra++) {
      final v = CapabilityVocabulary({
        'feature.carnets': ['Carnets'],
        for (var i = 0; i < extra; i++) 'feature.x$i': ['Thing number $i'],
      });
      expect(v.parse('Carnets').capabilities, ['feature.carnets'],
          reason: 'with $extra other labels');
    }
  });
}
