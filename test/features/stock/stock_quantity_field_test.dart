// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A stock quantity is typed the same way on every sheet: the field lets
// through digits and both decimal marks, and the one reader takes the
// member's own format, exactly. `1,5` is one and a half in French and German,
// `1.5` in English; a quantity shown in a format without grouping reads back
// as itself, so a German 1,500 is never a thousand and five hundred.
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:deskilo/features/stock/presentation/stock_quantity_field.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart'
    show ExactQuantity;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  final oneAndAHalf = ExactQuantity.parse('1.5');

  for (final (locale, typed) in [
    ('fr_FR', '1,5'),
    ('de_DE', '1,5'),
    ('en_GB', '1.5'),
    ('en_US', '1.5'),
  ]) {
    testWidgets(
      'in $locale, $typed is typed as it is and read as one and a half',
      (tester) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        await pumpApp(
          tester,
          Scaffold(
            body: StockQuantityField(
              key: const ValueKey('q'),
              controller: controller,
              label: 'Quantity',
            ),
          ),
        );
        await tester.enterText(find.byKey(const ValueKey('q')), '${typed}x');
        await tester.pump();
        expect(
          controller.text,
          typed,
          reason: 'only digits and decimal marks are let through',
        );
        expect(
          stockQuantityOrNull(controller.text, locale: locale),
          oneAndAHalf,
        );
      },
    );
  }

  test(
    'a quantity shown without grouping reads back as itself in every format',
    () {
      final held = ExactQuantity.parse('1.5');
      for (final locale in ['fr_FR', 'de_DE', 'en_GB', 'it_IT', 'es_ES']) {
        final shown = AppFormat(
          locale: locale,
          currencyCode: 'EUR',
        ).quantity(held, grouped: false);
        expect(
          stockQuantityOrNull(shown, locale: locale),
          held,
          reason: '$locale shows $shown',
        );
      }
    },
  );

  test('what is no quantity is said, never rounded or guessed', () {
    expect(stockQuantityOf('abc', locale: 'fr_FR').value, isNull);
    expect(stockQuantityOf('', locale: 'fr_FR').value, isNull);
    expect(
      stockQuantityOf('-1', locale: 'fr_FR').value,
      isNull,
      reason: 'a quantity typed is never negative',
    );
  });
}
