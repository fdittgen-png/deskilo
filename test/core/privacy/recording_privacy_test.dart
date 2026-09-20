// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1514 — the substitution itself, without a frame.
//
// The seam is pure Dart precisely so that the property it must have can
// be stated as data: nothing that identifies a person survives it, the
// same person is shown as the same invented one everywhere, and what is
// invented reaches nobody.
import 'package:deskilo/core/privacy/recording_privacy.dart';
import 'package:deskilo/features/profile/domain/personal_info.dart';
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// A complete, real-shaped identity: every field filled, so a field that
/// slips through the seam has something recognisable to slip through as.
const _real = PersonalInfo(
  courtesy: Courtesy.mrs,
  firstName: 'Marie-Claire',
  lastName: 'Dupont',
  company: 'Atelier Dupont SARL',
  street: '14 rue de la Paix',
  postalCode: '34120',
  city: 'Pézenas',
  countryCode: 'FR',
  phone: '+33762456325',
  email: 'marie.dupont@gmail.com',
  vatId: 'FR40303265045',
  legalId: '30326504500058',
);

void main() {
  test('every field that identifies a person is replaced (#1514)', () {
    final shown = recordingIdentity('user-1', _real);
    // Field by field, from `toDb()` — the wire map is the COMPLETE list
    // of what a PersonalInfo carries, so a field added later shows up
    // here on its own and fails until somebody decides about it.
    const structural = {
      PersonalInfo.keyCourtesy,
      PersonalInfo.keyCountryCode,
    };
    final real = _real.toDb();
    final after = shown.toDb();
    for (final key in real.keys) {
      if (structural.contains(key)) {
        expect(after[key], real[key], reason: '$key describes the document');
        continue;
      }
      expect(
        after[key],
        isNot(real[key]),
        reason: '$key reached the screen unchanged — that is a real '
            "person's datum in a recording",
      );
      expect(after[key], isNotEmpty, reason: '$key must still show SOMETHING');
    }
  });

  test('what is invented can reach nobody', () {
    final shown = recordingIdentity('user-1', _real);
    // RFC 2606 reserves `.test`; ARCEP reserves 06 39 98 xx xx.
    expect(shown.email, endsWith('@example.test'));
    expect(shown.phone, startsWith('+336399'));
    expect(recordingPersonFor('anybody').email, endsWith('@example.test'));
  });

  test('the same person is the same invented person everywhere', () {
    final once = recordingPersonFor('user-7');
    final twice = recordingPersonFor('user-7');
    expect(once.fullName, twice.fullName);
    expect(once.email, twice.email);
    // And a different person is a different one — otherwise a recording
    // of a directory would be one name repeated.
    final others = {
      for (var i = 0; i < 20; i++) recordingPersonFor('user-$i').fullName,
    };
    expect(others.length, greaterThan(10));
  });

  test('empty stays empty — the seam invents nobody the space has not', () {
    expect(recordingIdentity('user-1', PersonalInfo.empty).isEmpty, isTrue);
    expect(recordingName('user-1', ''), '');
    expect(recordingName('user-1', '   '), '');
  });

  test('a profile loses its name, its number, its address and its face', () {
    const real = Profile(
      id: 'user-9',
      displayName: 'Marie Dupont',
      whatsapp: '+33762456325',
      statusText: 'At the dentist until 3',
      address: '14 rue de la Paix, 34120 Pézenas',
      countryCode: 'FR',
      vatId: 'FR40303265045',
      avatarPath: 'user-9/avatar',
      identity: _real,
    );
    final shown = recordingProfile(real);
    expect(shown.displayName, isNot(real.displayName));
    expect(shown.whatsapp, isNot(real.whatsapp));
    expect(shown.address, isNot(real.address));
    expect(shown.vatId, isNot(real.vatId));
    // The photograph identifies as well as the name beside it.
    expect(shown.avatarPath, isNull);
    // Free text a member wrote about themselves: nothing can vouch for
    // what is in it, so it does not travel.
    expect(shown.statusText, '');
    // What is NOT personal is kept, or the recording stops being of this
    // workspace: the id the screens key by, the country, the presence.
    expect(shown.id, real.id);
    expect(shown.countryCode, 'FR');
  });
}
