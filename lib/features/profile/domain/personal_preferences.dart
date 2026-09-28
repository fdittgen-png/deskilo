// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/i18n/format_prefs.dart';

/// Only presentation preferences: never role, price or workspace policy keys.
abstract final class PersonalPreference {
  static const formatLocale = 'format_locale';
  static const clock = 'clock';
  static const timeZoneMode = 'time_zone_mode';
  static const documentLocale = 'preferred_locale';
  static const uiLocale = 'ui_locale';
  static const theme = 'theme';
  static const keys = {formatLocale, clock, timeZoneMode, documentLocale, uiLocale, theme};
}

class PersonalPreferences {
  PersonalPreferences({Map<String, String> defaults = const {}, Map<String, String> overrides = const {}})
      : defaults = Map.unmodifiable(defaults), overrides = Map.unmodifiable(overrides);

  final Map<String, String> defaults;
  final Map<String, String> overrides;
  Map<String, String> get effective => {...defaults, ...overrides};

  FormatPrefs formats(FormatPrefs fallback) => FormatPrefs.fromDb({
    ...fallback.toDb(), ...effective,
  });

  factory PersonalPreferences.fromJson(Map<String, dynamic> data) {
    Map<String, String> values(Object? raw) => raw is Map
        ? {for (final key in PersonalPreference.keys) if (raw[key] is String) key: raw[key] as String}
        : {};
    return PersonalPreferences(defaults: values(data['defaults']), overrides: values(data['overrides']));
  }
}

abstract class PersonalPreferencesRepository {
  Future<PersonalPreferences> read({String? workspaceId});
  Future<void> patch(Map<String, String?> values, {String? workspaceId});
}
