// SPDX-License-Identifier: AGPL-3.0-or-later
// #3405 -- the declaration model stands alone: a form is filled from lines with
// an explicit tax reference set, and the catalogue is data resolved on a set.
// The detailed tests of every form stay in the application.
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';
import 'package:deskilo_vat_declaration/deskilo_vat_declaration.dart';
import 'package:test/test.dart';

void main() {
  test(
    'a country without a form gets the generic one, filled on an empty set',
    () {
      const reference = TaxReferenceSet([]);
      final boxes = vatFormBoxes('ZZ', const [], reference: reference);
      expect(boxes, isA<List<VatFormBox>>());
    },
  );

  test(
    'the catalogue asks the set it is given: an empty one refuses, named',
    () {
      expect(
        () => vatFormCatalogueOn(const TaxReferenceSet([])),
        throwsA(isA<TaxReferenceUnavailable>()),
      );
    },
  );
}
