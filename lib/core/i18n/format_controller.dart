// SPDX-License-Identifier: 0BSD
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/profile/providers/profile_providers.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../locale/locale_controller.dart';
import '../time/workspace_time.dart';
import 'app_format.dart';
import 'format_prefs.dart';

part 'format_controller.g.dart';

/// THE resolved [AppFormat] for the signed-in member in the active
/// workspace (#711): their format locale (or the derived default), the
/// workspace's currency, their clock and zone preference.
///
/// TWO SIDE EFFECTS, both deliberate and both documented here because a
/// provider with side effects is a thing to be suspicious of:
///
///  1. `Intl.defaultLocale` is set to the resolved locale. That is what
///     makes the two dozen `DateFormat.MMMd()` calls the app grew before
///     this seam existed (#701) stop formatting in `en_US`. It is a
///     global, and this is the one place that writes it.
///  2. [WorkspaceTime.displayMode] follows the member's zone preference,
///     so `WorkspaceTime.display()` — the helper the older screens
///     already call — honours it without each of them changing.
///
/// Under the `regionalFormats` feature OFF, the member's stored
/// preferences are ignored and everything reads as it did before: the
/// UI language's home region, 24-hour clock, workspace zone.
@riverpod
AppFormat appFormat(Ref ref) {
  final uiLanguage = ref.watch(localeControllerProvider).value?.languageCode ??
      Intl.systemLocale.split('_').first;
  final workspace = ref.watch(currentWorkspaceProvider).value;
  final features = ref.watch(enabledFeaturesSyncProvider);
  final prefs = features.contains(WorkspaceFeature.regionalFormats)
      ? ref.watch(myProfileProvider).value?.formatPrefs ?? FormatPrefs.defaults
      : FormatPrefs.defaults;

  final locale = prefs.formatLocale.isNotEmpty &&
          kFormatLocales.contains(prefs.formatLocale)
      ? prefs.formatLocale
      : defaultFormatLocale(uiLanguage, workspace?.countryCode ?? '');

  Intl.defaultLocale = locale;
  WorkspaceTime.displayMode = prefs.timeZoneMode;

  return AppFormat(
    locale: locale,
    currencyCode: workspace?.currencyCode ?? 'EUR',
    // The pre-#711 app was 24-hour everywhere; `auto` only takes over
    // once a member has actually chosen it, so nobody's clock flips
    // under them on upgrade.
    clock: prefs.clock,
    timeZoneMode: prefs.timeZoneMode,
  );
}
