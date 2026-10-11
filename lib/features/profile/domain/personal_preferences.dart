// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/i18n/format_prefs.dart';
import '../../../core/data/json_reader.dart';

/// Only presentation preferences: never role, price or workspace policy keys.
abstract final class PersonalPreference {
  static const formatLocale = 'format_locale';
  static const clock = 'clock';
  static const timeZoneMode = 'time_zone_mode';
  static const documentLocale = 'preferred_locale';
  static const uiLocale = 'ui_locale';
  static const theme = 'theme';
  static const paymentProvider = 'payment_provider';
  static const keys = {formatLocale, clock, timeZoneMode, documentLocale, uiLocale, theme, paymentProvider};
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
    // Fail-closed (#2387): an unknown key or a non-text value is dropped.
    final r = JsonReader(data, context: 'personal_preferences');
    Map<String, String> values(String part) {
      final group = r.objectOrAbsent(part);
      return {
        for (final key in PersonalPreference.keys)
          if (group.textOrAbsent(key) case final String value) key: value,
      };
    }

    return PersonalPreferences(
      defaults: values('defaults'),
      overrides: values('overrides'),
    );
  }
}

abstract class PersonalPreferencesRepository {
  Future<PersonalPreferences> read({String? workspaceId});
  Future<void> patch(Map<String, String?> values, {String? workspaceId});
}
