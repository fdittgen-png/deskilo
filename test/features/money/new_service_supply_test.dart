// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3864 — a new service starts from the business's own switches: at the
// premises when it books places, a general service when it books none; the
// form asks a VAT-registered seller whenever its default is not the premises.
import 'package:deskilo/features/money/domain/new_service_supply.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a business that books places starts a service at the premises', () {
    expect(newServiceSupplyClass(booksPlaces: true), SupplyClass.property);
  });

  test('a business that books no places starts a general service', () {
    expect(newServiceSupplyClass(booksPlaces: false), SupplyClass.general);
  });

  test(
    'a VAT-registered seller is asked when it classifies or books no places',
    () {
      bool asks({required bool classifies, required bool booksPlaces}) =>
          asksSupplyClass(
            vatRegistered: true,
            classifies: classifies,
            booksPlaces: booksPlaces,
          );
      expect(asks(classifies: true, booksPlaces: true), isTrue);
      expect(asks(classifies: false, booksPlaces: false), isTrue);
      expect(asks(classifies: true, booksPlaces: false), isTrue);
      expect(asks(classifies: false, booksPlaces: true), isFalse);
    },
  );

  test('a seller that charges no VAT is never asked', () {
    for (final classifies in [true, false]) {
      for (final booksPlaces in [true, false]) {
        expect(
          asksSupplyClass(
            vatRegistered: false,
            classifies: classifies,
            booksPlaces: booksPlaces,
          ),
          isFalse,
        );
      }
    }
  });
}
