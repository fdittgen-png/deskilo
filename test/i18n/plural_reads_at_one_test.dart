// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4429 -- a plural reads as a singular at one: the German and French cycle
// plan said "alle Tage" and "tous les 1 jour" for a plan of one day (French
// `one` also covers 0, so its form carries the number). The words
// that change with the count live inside the plural, in every language.
import 'package:deskilo/l10n/app_localizations_de.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo/l10n/app_localizations_es.dart';
import 'package:deskilo/l10n/app_localizations_fr.dart';
import 'package:deskilo/l10n/app_localizations_it.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the cycle plan reads at one and at many in the five languages', () {
    expect(
      [
        AppLocalizationsDe().stockCyclePlanEvery(1),
        AppLocalizationsDe().stockCyclePlanEvery(14),
      ],
      ['jeden Tag', 'alle 14 Tage'],
    );
    expect(
      [
        AppLocalizationsFr().stockCyclePlanEvery(1),
        AppLocalizationsFr().stockCyclePlanEvery(14),
      ],
      ['Intervalle : 1 jour', 'Intervalle : 14 jours'],
    );
    expect(
      [
        AppLocalizationsEn().stockCyclePlanEvery(1),
        AppLocalizationsEn().stockCyclePlanEvery(14),
      ],
      ['every day', 'every 14 days'],
    );
    expect(AppLocalizationsEs().stockCyclePlanEvery(1), 'cada día');
    expect(AppLocalizationsIt().stockCyclePlanEvery(1), 'ogni giorno');
  });
}
