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

@ProviderFor(appFormat)
final appFormatProvider = AppFormatProvider._();

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

final class AppFormatProvider
    extends $FunctionalProvider<AppFormat, AppFormat, AppFormat>
    with $Provider<AppFormat> {
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

String _$appFormatHash() => r'7e7f1b11ea54ef4dc7506a0baf9f1f94299ef2bf';
