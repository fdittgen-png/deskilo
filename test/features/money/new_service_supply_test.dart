// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3864 — a new service starts from the business's own switches: at the
// premises when it books places, a general service when it books none; the
// form asks a VAT-registered seller whenever its default is not the premises.
import 'package:deskilo/features/money/domain/new_service_supply.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const places = {WorkspaceFeature.placeBooking};
  const classifies = {WorkspaceFeature.supplyClassification};

  test('a business that books places starts a service at the premises', () {
    expect(newServiceSupplyClass(places), SupplyClass.property);
  });

  test('a business that books no places starts a general service', () {
    expect(newServiceSupplyClass(const {}), SupplyClass.general);
    expect(newServiceSupplyClass(classifies), SupplyClass.general);
  });

  test(
    'a VAT-registered seller is asked when it classifies or books no places',
    () {
      expect(asksSupplyClass(vatRegistered: true, enabled: classifies), isTrue);
      expect(asksSupplyClass(vatRegistered: true, enabled: const {}), isTrue);
      expect(
        asksSupplyClass(
          vatRegistered: true,
          enabled: {...places, ...classifies},
        ),
        isTrue,
      );
      expect(asksSupplyClass(vatRegistered: true, enabled: places), isFalse);
    },
  );

  test('a seller that charges no VAT is never asked', () {
    expect(asksSupplyClass(vatRegistered: false, enabled: const {}), isFalse);
    expect(asksSupplyClass(vatRegistered: false, enabled: classifies), isFalse);
  });
}
