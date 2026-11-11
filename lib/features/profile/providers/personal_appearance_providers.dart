// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/i18n/format_prefs.dart';
import '../../../core/i18n/shown_language.dart';
import '../../../core/locale/device_locale.dart';
import '../../../core/locale/locale_controller.dart';
import '../../../core/theme/theme_controller.dart';
import '../domain/personal_preferences.dart';
import 'personal_preferences_providers.dart';
import 'profile_providers.dart';

part 'personal_appearance_providers.g.dart';

@riverpod
Locale? personalLocale(Ref ref) {
  final local = ref.watch(localeControllerProvider).value;
  final value = ref.watch(personalSettingsProvider).value?.effective[PersonalPreference.uiLocale];
  return value == null ? local : value.isEmpty ? null : Locale(value);
}

/// The language the app is shown in (`MaterialApp`'s own resolution of the
/// account's language over the device's languages): the LANGUAGE of every
/// derived format locale.
@riverpod
String shownLanguageCode(Ref ref) => shownLanguage(
      chosen: ref.watch(personalLocaleProvider),
      device: [
        ref.watch(deviceLocaleProvider),
        ...PlatformDispatcher.instance.locales.skip(1),
      ],
    );

/// The person's format preferences: the account's own when [accountOnly]
/// (a personal surface: no business's exception reaches it), else with the
/// open business's exception over them; the profile's copy while the
/// preferences load.
@riverpod
FormatPrefs personalFormatPrefs(Ref ref, {required bool accountOnly}) {
  final profile =
      ref.watch(myProfileProvider).value?.formatPrefs ?? FormatPrefs.defaults;
  final stored = ref.watch(personalSettingsProvider).value;
  if (stored == null) return profile;
  return (accountOnly ? PersonalPreferences(defaults: stored.defaults) : stored)
      .formats(profile);
}

@riverpod
ThemeMode? personalTheme(Ref ref) {
  final local = ref.watch(themeControllerProvider).value;
  return switch (ref.watch(personalSettingsProvider).value?.effective[PersonalPreference.theme]) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    'system' => null,
    _ => local,
  };
}
