// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- what each country's yearly archive carries, pinned
// BEFORE the rule moves behind the archive contract: the FEC (France), the
// procedures document (Switzerland) and the readable handover (GB, IE, CA, US),
// for every country the app knows and the spellings it accepts. The move must
// change none of these answers.
import 'package:deskilo/features/money/domain/archive_bundle.dart';
import 'package:deskilo/features/money/domain/readable_handover.dart';
import 'package:flutter_test/flutter_test.dart';

/// country -> (carries the FEC, the procedures, the readable handover)
const _expected = <String, ({bool fec, bool procedures, bool handover})>{
  'FR': (fec: true, procedures: false, handover: false),
  'CH': (fec: false, procedures: true, handover: false),
  'DE': (fec: false, procedures: false, handover: false),
  'IT': (fec: false, procedures: false, handover: false),
  'ES': (fec: false, procedures: false, handover: false),
  'GB': (fec: false, procedures: false, handover: true),
  'IE': (fec: false, procedures: false, handover: true),
  'CA': (fec: false, procedures: false, handover: true),
  'US': (fec: false, procedures: false, handover: true),
  'PL': (fec: false, procedures: false, handover: false),
  'AT': (fec: false, procedures: false, handover: false),
  'BE': (fec: false, procedures: false, handover: false),
  'NL': (fec: false, procedures: false, handover: false),
  'LU': (fec: false, procedures: false, handover: false),
  'RO': (fec: false, procedures: false, handover: false),
  'ZZ': (fec: false, procedures: false, handover: false),
  '': (fec: false, procedures: false, handover: false),
};

void main() {
  test('every country\'s archive carries what it carried before the move', () {
    for (final e in _expected.entries) {
      expect(archiveCarriesFec(e.key), e.value.fec, reason: '${e.key}: FEC');
      expect(
        archiveCarriesProcedures(e.key),
        e.value.procedures,
        reason: '${e.key}: procedures',
      );
      expect(
        archiveCarriesReadableHandover(e.key),
        e.value.handover,
        reason: '${e.key}: handover',
      );
    }
  });

  test('the spellings the callers pass are accepted alike', () {
    for (final c in ['ie', ' IE'.trim(), 'Ie']) {
      expect(archiveCarriesReadableHandover(c), isTrue, reason: c);
    }
    expect(archiveCarriesFec('fr'), isTrue);
    expect(archiveCarriesProcedures('ch'), isTrue);
    expect(archiveCarriesProcedures('Ch'), isTrue);
  });

  // INTENDED behaviour change of the move (#3455): the archive add-on is
  // asked through `LegalContext.normalized` like every other capability, so a
  // padded code is trimmed and `UK` is `GB`. Before the move neither was
  // accepted here; no caller passes one today.
  test('intended: harmonised with LegalContext.normalized (trim, UK is GB)', () {
    expect(archiveCarriesReadableHandover('UK'), isTrue);
    expect(archiveCarriesProcedures(' CH '), isTrue);
    expect(archiveCarriesFec(' fr '), isTrue);
    expect(archiveCarriesReadableHandover(' ie'), isTrue);
  });
}
