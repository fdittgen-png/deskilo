// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3489 -- the doctor's counts are ICU plurals in all five languages: one and
// many read differently, and the English the command line prints is the same
// catalogue entry.
import 'package:deskilo/core/instance/instance_doctor.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one and many differ in every locale', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final words = lookupAppLocalizations(locale);
      expect(
        words.instanceDoctorStuckTitle(1),
        isNot(words.instanceDoctorStuckTitle(2)),
        reason: locale.languageCode,
      );
      expect(words.instanceDoctorStuckTitle(1), contains('1'));
      expect(words.instanceDoctorStuckTitle(2), contains('2'));
      expect(
        words.instanceDoctorNeedsHuman(1),
        isNot(words.instanceDoctorNeedsHuman(3)),
        reason: locale.languageCode,
      );
      expect(
        words.instanceDoctorHeld(1, 1),
        isNot(words.instanceDoctorHeld(2, 2)),
        reason: locale.languageCode,
      );
    }
  });

  test('the report footer and the finding title read the same English', () {
    final en = AppLocalizationsEn();
    expect(en.instanceDoctorStuckTitle(1), '1 account cannot get in');
    expect(en.instanceDoctorStuckTitle(2), '2 accounts cannot get in');
    expect(en.instanceDoctorNeedsHuman(1), '1 finding needs a human.');
    expect(en.instanceDoctorHeld(1, 2), '1 workspace, 2 members');
    final report = doctorReport('ref', const [
      DoctorFinding(DoctorLevel.warn, 't', 'd'),
      DoctorFinding(DoctorLevel.alarm, 't', 'd'),
    ]);
    expect(report, contains('2 findings need a human.'));
  });

  test('the stuck-accounts finding carries typed words and its count', () {
    final finding = InstanceDoctor.checkSignups([
      {'created_7d': 5, 'confirmed_7d': 3, 'stuck': 2, 'oldest_stuck_hours': 30},
    ]).firstWhere((f) => f.words == DoctorWords.stuckAccounts);
    expect(finding.count, 2);
    expect(finding.title, '2 accounts cannot get in');
  });
}
