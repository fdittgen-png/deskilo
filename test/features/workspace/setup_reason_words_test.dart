// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3076 — a reason is one whole sentence per key, so the French elision is
// right ("Parce qu'aucun…", never "Parce que aucun…") and no language
// composes a prefix with a fragment.
import 'package:deskilo/l10n/app_localizations_de.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo/l10n/app_localizations_es.dart';
import 'package:deskilo/l10n/app_localizations_fr.dart';
import 'package:deskilo/l10n/app_localizations_it.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('French reasons elide before a vowel', () {
    final fr = AppLocalizationsFr();
    expect(fr.setupReason('no_money'), startsWith('Parce qu’aucun '));
    expect(fr.setupReason('association'), startsWith('Parce qu’une '));
    expect(fr.setupReason('door_tablet'), startsWith('Parce qu’une '));
    expect(fr.setupReason('later'), startsWith('Parce qu’un '));
    expect(fr.setupReason('several_rooms'), startsWith('Parce qu’il '));
    expect(fr.setupReason('keeps_books'), startsWith('Parce que vous '));
  });

  test('every language answers a whole sentence for a reason', () {
    final starts = {
      AppLocalizationsEn(): 'Because ',
      AppLocalizationsDe(): 'Weil ',
      AppLocalizationsEs(): 'Porque ',
      AppLocalizationsIt(): 'Perché ',
      AppLocalizationsFr(): 'Parce qu',
    };
    for (final e in starts.entries) {
      expect(e.key.setupReason('pay_online'), startsWith(e.value));
    }
  });
}
