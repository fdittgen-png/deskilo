// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import '../../../core/i18n/format_prefs.dart';

/// Only presentation preferences: never role, price or workspace policy keys.
abstract final class PersonalPreference {
  static const formatLocale = 'format_locale';
  static const clock = 'clock';
  static const timeZoneMode = 'time_zone_mode';
  /// #3648 — 'locale', 'monday', 'sunday' or 'saturday'.
  static const weekStart = 'week_start';
  static const documentLocale = 'preferred_locale';
  static const uiLocale = 'ui_locale';
  static const theme = 'theme';
  static const paymentProvider = 'payment_provider';
  /// #2552 XPRIV-01 — 'masked' or 'shown'; a personal default only.
  static const privateValues = 'private_values';
  /// Whether [documentLocale] (letters and notifications) follows the
  /// interface language or was chosen on its own; a personal default only.
  static const documentLocaleMode = 'document_locale_mode';
  static const keys = {formatLocale, clock, timeZoneMode, weekStart, documentLocale, uiLocale, theme, paymentProvider, privateValues, documentLocaleMode};
  /// The keys a business may hold its own exception of (the reset clears them).
  static Set<String> get workspaceKeys => keys.difference({documentLocaleMode});
}

/// How the language of letters and notifications is decided: it follows the
/// interface language (every account that never chose, so a stored value
/// stays as it is), or the person chose it and the interface language never
/// writes it again.
enum DocumentLocaleMode {
  follows('follows'),
  chosen('chosen');

  const DocumentLocaleMode(this.wire);
  final String wire;

  static DocumentLocaleMode fromWire(String? wire) =>
      values.where((m) => m.wire == wire).firstOrNull ?? follows;
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
