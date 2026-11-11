// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/profile/providers/personal_appearance_providers.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../locale/device_locale.dart';
import '../settings/region_defaults.dart';
import '../settings/setting_defaults.g.dart';
import 'app_format.dart';
import 'format_prefs.dart';
import 'shown_language.dart';
import 'workspace_currency.dart';

part 'format_controller.g.dart';

/// Which format a surface reads: the PERSON's (Me and every page of the
/// person's own layer) or the open BUSINESS's (a space's screens).
enum FormatSurface { personal, business }

/// The surface of the route on top, set by the router from the route's
/// class (`route_classes.dart`) whenever the person arrives somewhere. No
/// screen chooses its format: [appFormatProvider] follows this.
@Riverpod(keepAlive: true)
class FormatSurfaceOfRoute extends _$FormatSurfaceOfRoute {
  @override
  FormatSurface build() => FormatSurface.business;

  void set(FormatSurface surface) {
    if (state != surface) state = surface;
  }
}

/// THE [AppFormat] a screen reads: the person's on a personal surface, the
/// business's on a business screen, as [FormatSurfaceOfRoute] says.
@riverpod
AppFormat appFormat(Ref ref) =>
    switch (ref.watch(formatSurfaceOfRouteProvider)) {
      FormatSurface.personal => ref.watch(personalFormatProvider),
      FormatSurface.business => ref.watch(businessFormatProvider),
    };

/// The person's own format, the same whichever business is open: their
/// account's format preferences ALWAYS (a business's `regionalFormats`
/// switch and its per-business exceptions do not reach a personal
/// surface), else the shown language with the DEVICE's region, else the
/// operator's default. Times read on the device's clock: a personal surface
/// lists several businesses and has no business clock of its own. Amounts
/// name their record's currency (`moneyNamed`); [AppFormat.currencyCode] is
/// the platform's default, never the open business's.
@riverpod
AppFormat personalFormat(Ref ref) {
  final prefs = ref.watch(personalFormatPrefsProvider(accountOnly: true));
  final region = _regionDefaults(ref);
  return AppFormat(
    locale: _chosenLocale(prefs) ??
        personalDefaultFormatLocale(
          language: ref.watch(shownLanguageCodeProvider),
          deviceRegion: ref.watch(deviceLocaleProvider).countryCode,
          operatorLocale: region.locale,
        ),
    currencyCode: region.currency,
    clock: prefs.clock,
    timeZoneMode: TimeZoneMode.device,
  );
}

/// The open business's format for the signed-in member (#711): their
/// format locale (or the shown language with the business's country), the
/// business's currency, their clock and zone preference.
///
/// Under the `regionalFormats` feature OFF, the member's stored
/// preferences are ignored and everything reads as it did before: the
/// derived locale, the format region's clock, the business's zone. With no
/// business open, the region is the device's, as on a personal surface.
@riverpod
AppFormat businessFormat(Ref ref) {
  final workspace = ref.watch(currentWorkspaceProvider).value;
  final features = ref.watch(enabledFeaturesSyncProvider);
  final prefs = features.contains(WorkspaceFeature.regionalFormats)
      ? ref.watch(personalFormatPrefsProvider(accountOnly: false))
      : FormatPrefs.defaults;
  final region = _regionDefaults(ref);
  final language = ref.watch(shownLanguageCodeProvider);
  final country = workspace?.countryCode ?? '';
  return AppFormat(
    locale: _chosenLocale(prefs) ??
        (country.isEmpty
            ? personalDefaultFormatLocale(
                language: language,
                deviceRegion: ref.watch(deviceLocaleProvider).countryCode,
                operatorLocale: region.locale,
              )
            : defaultFormatLocale(language, country)),
    currencyCode: workspace?.currencyCode ?? region.currency,
    // The pre-#711 app was 24-hour everywhere; `auto` only takes over
    // once a member has actually chosen it, so nobody's clock flips
    // under them on upgrade.
    clock: prefs.clock,
    timeZoneMode: prefs.timeZoneMode,
  );
}

/// The person's chosen format locale, when it is one the app formats in.
String? _chosenLocale(FormatPrefs prefs) =>
    prefs.formatLocale.isNotEmpty && kFormatLocales.contains(prefs.formatLocale)
        ? prefs.formatLocale
        : null;

/// The platform's region defaults, with ONE SIDE EFFECT, deliberate and
/// documented here because a provider with side effects is a thing to be
/// suspicious of: [WorkspaceCurrency] learns the platform's default
/// currency, so the ambient grain of a screen with no workspace follows the
/// operator's `locale.default_currency` and not the compile-time copy
/// (#2488). Nothing here writes a locale: everything that formats names one.
RegionDefaults _regionDefaults(Ref ref) {
  final region = ref.watch(regionDefaultsProvider);
  WorkspaceCurrency.installDefault(region.currency);
  return region;
}

/// #1150 — the member's formats from a widget that has no `ref`: a
/// StatelessWidget deep in a sheet still has to honour their clock and
/// zone. Reads the scope the widget is already inside.
AppFormat appFormatOf(BuildContext context) =>
    _formatOf(context, appFormatProvider);

/// [personalFormatProvider] from a widget that has no `ref`: what every
/// file of a personal surface reads.
AppFormat personalFormatOf(BuildContext context) =>
    _formatOf(context, personalFormatProvider);

AppFormat _formatOf(
  BuildContext context,
  ProviderListenable<AppFormat> format,
) {
  try {
    return ProviderScope.containerOf(context, listen: false).read(format);
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
