// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4291 -- how long a quote stays valid is the business's own setting: the days
// a new quote is valid by default (`quotes.default_validity_days`) and the most
// it may be given (`quotes.max_validity_days`). The registry's default is the
// fallback; `save_customer_quote_draft_v1` reads the same two settings.
import 'package:meta/meta.dart';

import '../../../core/settings/setting_defaults.g.dart';
import '../../../core/settings/settings.dart';
import '../../../core/time/calendar_days.dart';

@immutable
class QuoteValidity {
  const QuoteValidity({
    this.defaultDays = SettingDefaults.quotesDefaultValidityDays,
    this.maxDays = SettingDefaults.quotesMaxValidityDays,
  });

  factory QuoteValidity.fromSettings(SettingsSet? settings) {
    int read(String key, int fallback) =>
        settings != null && settings.definitions.containsKey(key)
        ? settings.read<int>(key)
        : fallback;
    return QuoteValidity(
      defaultDays: read(
        'quotes.default_validity_days',
        SettingDefaults.quotesDefaultValidityDays,
      ),
      maxDays: read(
        'quotes.max_validity_days',
        SettingDefaults.quotesMaxValidityDays,
      ),
    );
  }

  final int defaultDays;
  final int maxDays;

  /// The end of validity of a quote offered on [on] when none was stated: the
  /// default, never beyond the longest.
  DateTime defaultEnd(DateTime on) =>
      addCalendarDays(on, defaultDays < maxDays ? defaultDays : maxDays);

  /// Whether [until] is a validity this business allows for an offer on [on].
  bool allows(DateTime on, DateTime until) =>
      !until.isBefore(on) && !until.isAfter(addCalendarDays(on, maxDays));
}
