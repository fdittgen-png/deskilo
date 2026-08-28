// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'format_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(appFormat)
final appFormatProvider = AppFormatProvider._();

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

final class AppFormatProvider
    extends $FunctionalProvider<AppFormat, AppFormat, AppFormat>
    with $Provider<AppFormat> {
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
  AppFormatProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appFormatProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appFormatHash();

  @$internal
  @override
  $ProviderElement<AppFormat> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppFormat create(Ref ref) {
    return appFormat(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppFormat value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppFormat>(value),
    );
  }
}

String _$appFormatHash() => r'd510e00afa4d70d9cee09f87b2727a8bc7cd7754';
