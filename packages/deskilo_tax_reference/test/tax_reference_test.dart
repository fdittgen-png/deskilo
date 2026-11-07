// SPDX-License-Identifier: AGPL-3.0-or-later
// #3401 -- the data model stands alone: a set resolves a row by date and its
// revision changes with the rows. The detailed tests stay in the application.
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';
import 'package:test/test.dart';

void main() {
  test('an empty set has a stable revision and no rows', () {
    const empty = TaxReferenceSet([]);
    expect(empty.rows, isEmpty);
    expect(empty.revision, const TaxReferenceSet([]).revision);
  });
}
