// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import 'app_format.dart';

/// The language the app is SHOWN in: the one the person chose ([chosen]),
/// else the first of the [device]'s languages the app ships, else the
/// app's first supported language — the resolution `MaterialApp` itself
/// applies. Never the raw device language: a Dutch device that reads the
/// app in English formats in English.
String shownLanguage({required Locale? chosen, required List<Locale> device}) {
  final preferred = chosen == null ? device : [chosen];
  return basicLocaleListResolution(
    preferred,
    AppLocalizations.supportedLocales,
  ).languageCode;
}

/// The format locale of a personal surface nobody chose one for: the shown
/// [language] paired with the [deviceRegion]; without a device region, the
/// operator's default format locale ([operatorLocale], `locale.default_locale`)
/// when it is in that language, else its region paired with that language.
String personalDefaultFormatLocale({
  required String language,
  required String? deviceRegion,
  required String operatorLocale,
}) {
  if (deviceRegion != null && deviceRegion.isNotEmpty) {
    return defaultFormatLocale(language, deviceRegion);
  }
  final parts = operatorLocale.split('_');
  if (parts.first == language && kFormatLocales.contains(operatorLocale)) {
    return operatorLocale;
  }
  return defaultFormatLocale(language, parts.length > 1 ? parts[1] : '');
}
