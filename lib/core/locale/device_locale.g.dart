// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_locale.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #1303 S1 — the locale the DEVICE reports, not the app's language
/// override: where the person creating a workspace most likely is.
///
/// A provider so a test can set it; the app reads the platform.

@ProviderFor(deviceLocale)
final deviceLocaleProvider = DeviceLocaleProvider._();

/// #1303 S1 — the locale the DEVICE reports, not the app's language
/// override: where the person creating a workspace most likely is.
///
/// A provider so a test can set it; the app reads the platform.

final class DeviceLocaleProvider
    extends $FunctionalProvider<Locale, Locale, Locale>
    with $Provider<Locale> {
  /// #1303 S1 — the locale the DEVICE reports, not the app's language
  /// override: where the person creating a workspace most likely is.
  ///
  /// A provider so a test can set it; the app reads the platform.
  DeviceLocaleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceLocaleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceLocaleHash();

  @$internal
  @override
  $ProviderElement<Locale> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Locale create(Ref ref) {
    return deviceLocale(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Locale value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Locale>(value),
    );
  }
}

String _$deviceLocaleHash() => r'81c58216a195cb37feb814f03b5e99bbd2099aab';
