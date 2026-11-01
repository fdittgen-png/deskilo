// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/profile/providers/personal_preferences_providers.dart';
import '../../features/profile/providers/profile_providers.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../locale/device_locale.dart';
import '../locale/locale_controller.dart';
import '../settings/region_defaults.dart';
import '../settings/setting_defaults.g.dart';
import '../time/workspace_time.dart';
import 'app_format.dart';
import 'format_prefs.dart';
import 'workspace_currency.dart';

part 'format_controller.g.dart';

/// THE resolved [AppFormat] for the signed-in member in the active
/// workspace (#711): their format locale (or the derived default), the
/// workspace's currency, their clock and zone preference.
///
/// THREE SIDE EFFECTS, all deliberate and both documented here because a
/// provider with side effects is a thing to be suspicious of:
///
///  1. `Intl.defaultLocale` is set to the resolved locale. That is what
///     makes the two dozen `DateFormat.MMMd()` calls the app grew before
///     this seam existed (#701) stop formatting in `en_US`. It is a
///     global, and this is the one place that writes it.
///  2. [WorkspaceTime.displayMode] follows the member's zone preference,
///     so `WorkspaceTime.display()` — the helper the older screens
///     already call — honours it without each of them changing.
///  3. [WorkspaceCurrency] learns the platform's default currency, so the
///     ambient grain of a screen with no workspace follows the operator's
///     `locale.default_currency` and not the compile-time copy (#2488).
///
/// Under the `regionalFormats` feature OFF, the member's stored
/// preferences are ignored and everything reads as it did before: the
/// UI language's home region, 24-hour clock, workspace zone.
@riverpod
AppFormat appFormat(Ref ref) {
  // No language chosen in the app: the one the app is DRAWN in, which is
  // the platform's (#3060). `Intl.systemLocale` is not that on the web, so
  // dates stayed English under a French or German browser.
  final uiLanguage = ref.watch(localeControllerProvider).value?.languageCode ??
      ref.watch(deviceLocaleProvider).languageCode;
  final workspace = ref.watch(currentWorkspaceProvider).value;
  final features = ref.watch(enabledFeaturesSyncProvider);
  final prefs = features.contains(WorkspaceFeature.regionalFormats)
      ? ref.watch(personalSettingsProvider).value?.formats(
          ref.watch(myProfileProvider).value?.formatPrefs ?? FormatPrefs.defaults) ??
          ref.watch(myProfileProvider).value?.formatPrefs ?? FormatPrefs.defaults
      : FormatPrefs.defaults;

  final locale = prefs.formatLocale.isNotEmpty &&
          kFormatLocales.contains(prefs.formatLocale)
      ? prefs.formatLocale
      : defaultFormatLocale(uiLanguage, workspace?.countryCode ?? '');

  final region = ref.watch(regionDefaultsProvider);
  Intl.defaultLocale = locale;
  WorkspaceTime.displayMode = prefs.timeZoneMode;
  WorkspaceCurrency.installDefault(region.currency);

  return AppFormat(
    locale: locale,
    currencyCode: workspace?.currencyCode ?? region.currency,
    // The pre-#711 app was 24-hour everywhere; `auto` only takes over
    // once a member has actually chosen it, so nobody's clock flips
    // under them on upgrade.
    clock: prefs.clock,
    timeZoneMode: prefs.timeZoneMode,
  );
}

/// #1150 — the member's formats from a widget that has no `ref`: a
/// StatelessWidget deep in a sheet still has to honour their clock and
/// zone. Reads the scope the widget is already inside.
AppFormat appFormatOf(BuildContext context) {
  try {
    return ProviderScope.containerOf(context, listen: false)
        .read(appFormatProvider);
  } on StateError {
    // No scope above this widget — a sheet pumped on its own in a test,
    // or a surface outside the app root. A preference lookup must never
    // be the reason a sheet fails to build: a 24-hour clock in the
    // workspace's zone is what every screen showed before #1150.
    return const AppFormat(
        locale: SettingDefaults.localeDefaultLocale,
        currencyCode: SettingDefaults.localeDefaultCurrency,
        clock: ClockPref.h24);
  }
}
