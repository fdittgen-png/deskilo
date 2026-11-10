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
/// ONE SIDE EFFECT, deliberate and documented here because a provider with
/// side effects is a thing to be suspicious of: [WorkspaceCurrency] learns
/// the platform's default currency, so the ambient grain of a screen with no
/// workspace follows the operator's `locale.default_currency` and not the
/// compile-time copy (#2488). Since #3484 it writes no locale: everything
/// that formats names one (this [AppFormat]'s, or a document's).
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
/// ONE SIDE EFFECT, deliberate and documented here because a provider with
/// side effects is a thing to be suspicious of: [WorkspaceCurrency] learns
/// the platform's default currency, so the ambient grain of a screen with no
/// workspace follows the operator's `locale.default_currency` and not the
/// compile-time copy (#2488). Since #3484 it writes no locale: everything
/// that formats names one (this [AppFormat]'s, or a document's).
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
  /// ONE SIDE EFFECT, deliberate and documented here because a provider with
  /// side effects is a thing to be suspicious of: [WorkspaceCurrency] learns
  /// the platform's default currency, so the ambient grain of a screen with no
  /// workspace follows the operator's `locale.default_currency` and not the
  /// compile-time copy (#2488). Since #3484 it writes no locale: everything
  /// that formats names one (this [AppFormat]'s, or a document's).
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

String _$appFormatHash() => r'6f0a815fa80bfa470d843b6edea53e503b151f7c';
