// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 -- INTENDED behaviour change of moving the records-location notices
// behind the archive contract (#3461): the issuer's add-on is asked through
// `LegalContext.normalized` like every other capability, so a raw `ca` or a
// padded ` DE ` resolves like `CA` and `DE`. Before the move the constructor's
// getters compared the code exactly (only `fromSettings` normalised it), so a
// raw code answered no notice; no caller passes one today. The baseline pins
// (`records_location_parity_test` and its goldens) are unchanged.
import 'package:deskilo/features/money/domain/records_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('intended: harmonised with LegalContext.normalized (a raw ca)', () {
    const location = RecordsLocation(
      issuerCountry: 'ca',
      hostingCountry: null,
      craReference: '',
    );
    expect(location.craNotice, isTrue);
    expect(location.aoNotice, isFalse);
  });

  test('intended: harmonised with LegalContext.normalized (a padded DE)', () {
    const location = RecordsLocation(
      issuerCountry: ' DE ',
      hostingCountry: 'US',
      craReference: '',
    );
    expect(location.aoNotice, isTrue);
    expect(location.craNotice, isFalse);
  });
}
