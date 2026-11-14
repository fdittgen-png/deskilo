// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3963 — three customers of the reference business hold a VAT number, so the
// check of the customer form (the member page's "Check now") has each of its
// three answers to give: Ada's French number carries the key its digits give
// (valid), Bruno's carries another (invalid), Chiara's is Italian, a member
// state the Demo's VIES says does not answer (an outage). The numbers are
// invented; the rule is demo_vies_repository.dart's.
import '../data/profile_repository.dart';
import '../demo_dataset.dart';

const _numbers = {
  'member-1': 'FR32123456789',
  'member-2': 'FR00123456789',
  'member-3': 'IT01234567890',
};

/// The user of the cast member [memberId], '' when there is none.
String _userOf(String memberId) =>
    demoCast.where((p) => p.memberId == memberId).firstOrNull?.userId ?? '';

/// Puts the three numbers on the profiles of the members they belong to.
FakeProfileRepository seedDemoVatNumbers(FakeProfileRepository profiles) {
  for (final entry in _numbers.entries) {
    final i = profiles.profiles.indexWhere((p) => p.id == _userOf(entry.key));
    if (i < 0) continue;
    profiles.profiles[i] = profiles.profiles[i].copyWith(vatId: entry.value);
  }
  return profiles;
}

/// The VAT number on the profile of the cast member [memberId], '' when none.
String demoVatIdOf(FakeProfileRepository profiles, String memberId) =>
    profiles.profiles
        .where((p) => p.id == _userOf(memberId))
        .firstOrNull
        ?.vatId ??
    '';
