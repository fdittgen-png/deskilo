// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/locale/locale_controller.dart';
import '../../../core/theme/theme_controller.dart';
import '../domain/personal_preferences.dart';
import 'personal_preferences_providers.dart';

part 'personal_appearance_providers.g.dart';

@riverpod
Locale? personalLocale(Ref ref) {
  final local = ref.watch(localeControllerProvider).value;
  final value = ref.watch(personalSettingsProvider).value?.effective[PersonalPreference.uiLocale];
  return value == null ? local : value.isEmpty ? null : Locale(value);
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
