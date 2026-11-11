// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'format_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The surface of the route on top, set by the router from the route's
/// class (`route_classes.dart`) whenever the person arrives somewhere. No
/// screen chooses its format: [appFormatProvider] follows this.

@ProviderFor(FormatSurfaceOfRoute)
final formatSurfaceOfRouteProvider = FormatSurfaceOfRouteProvider._();

/// The surface of the route on top, set by the router from the route's
/// class (`route_classes.dart`) whenever the person arrives somewhere. No
/// screen chooses its format: [appFormatProvider] follows this.
final class FormatSurfaceOfRouteProvider
    extends $NotifierProvider<FormatSurfaceOfRoute, FormatSurface> {
  /// The surface of the route on top, set by the router from the route's
  /// class (`route_classes.dart`) whenever the person arrives somewhere. No
  /// screen chooses its format: [appFormatProvider] follows this.
  FormatSurfaceOfRouteProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'formatSurfaceOfRouteProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$formatSurfaceOfRouteHash();

  @$internal
  @override
  FormatSurfaceOfRoute create() => FormatSurfaceOfRoute();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FormatSurface value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FormatSurface>(value),
    );
  }
}

String _$formatSurfaceOfRouteHash() =>
    r'e9c990b3fb8d154c24550613e5b5dd038b20adf0';

/// The surface of the route on top, set by the router from the route's
/// class (`route_classes.dart`) whenever the person arrives somewhere. No
/// screen chooses its format: [appFormatProvider] follows this.

abstract class _$FormatSurfaceOfRoute extends $Notifier<FormatSurface> {
  FormatSurface build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<FormatSurface, FormatSurface>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FormatSurface, FormatSurface>,
              FormatSurface,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The language the app is shown in (`MaterialApp`'s own resolution of the
/// account's language over the device's languages): the LANGUAGE of every
/// derived format locale.

@ProviderFor(shownLanguageCode)
final shownLanguageCodeProvider = ShownLanguageCodeProvider._();

/// The language the app is shown in (`MaterialApp`'s own resolution of the
/// account's language over the device's languages): the LANGUAGE of every
/// derived format locale.

final class ShownLanguageCodeProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// The language the app is shown in (`MaterialApp`'s own resolution of the
  /// account's language over the device's languages): the LANGUAGE of every
  /// derived format locale.
  ShownLanguageCodeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shownLanguageCodeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shownLanguageCodeHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return shownLanguageCode(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$shownLanguageCodeHash() => r'4f9c6a8fcaea6c5e97e1abb41f17befc1072431f';

/// THE [AppFormat] a screen reads: the person's on a personal surface, the
/// business's on a business screen, as [FormatSurfaceOfRoute] says.

@ProviderFor(appFormat)
final appFormatProvider = AppFormatProvider._();

/// THE [AppFormat] a screen reads: the person's on a personal surface, the
/// business's on a business screen, as [FormatSurfaceOfRoute] says.

final class AppFormatProvider
    extends $FunctionalProvider<AppFormat, AppFormat, AppFormat>
    with $Provider<AppFormat> {
  /// THE [AppFormat] a screen reads: the person's on a personal surface, the
  /// business's on a business screen, as [FormatSurfaceOfRoute] says.
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

String _$appFormatHash() => r'cccbeb138d1e9d5db13a517a7eb75c214af86dd8';

/// The person's own format, the same whichever business is open: their
/// account's format preferences ALWAYS (a business's `regionalFormats`
/// switch and its per-business exceptions do not reach a personal
/// surface), else the shown language with the DEVICE's region, else the
/// operator's default. Times read on the device's clock: a personal surface
/// lists several businesses and has no business clock of its own. Amounts
/// name their record's currency (`moneyNamed`); [AppFormat.currencyCode] is
/// the platform's default, never the open business's.

@ProviderFor(personalFormat)
final personalFormatProvider = PersonalFormatProvider._();

/// The person's own format, the same whichever business is open: their
/// account's format preferences ALWAYS (a business's `regionalFormats`
/// switch and its per-business exceptions do not reach a personal
/// surface), else the shown language with the DEVICE's region, else the
/// operator's default. Times read on the device's clock: a personal surface
/// lists several businesses and has no business clock of its own. Amounts
/// name their record's currency (`moneyNamed`); [AppFormat.currencyCode] is
/// the platform's default, never the open business's.

final class PersonalFormatProvider
    extends $FunctionalProvider<AppFormat, AppFormat, AppFormat>
    with $Provider<AppFormat> {
  /// The person's own format, the same whichever business is open: their
  /// account's format preferences ALWAYS (a business's `regionalFormats`
  /// switch and its per-business exceptions do not reach a personal
  /// surface), else the shown language with the DEVICE's region, else the
  /// operator's default. Times read on the device's clock: a personal surface
  /// lists several businesses and has no business clock of its own. Amounts
  /// name their record's currency (`moneyNamed`); [AppFormat.currencyCode] is
  /// the platform's default, never the open business's.
  PersonalFormatProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'personalFormatProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$personalFormatHash();

  @$internal
  @override
  $ProviderElement<AppFormat> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppFormat create(Ref ref) {
    return personalFormat(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppFormat value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppFormat>(value),
    );
  }
}

String _$personalFormatHash() => r'64de719409f556dc4f4bf969c07da394d38e261a';

/// The open business's format for the signed-in member (#711): their
/// format locale (or the shown language with the business's country), the
/// business's currency, their clock and zone preference.
///
/// Under the `regionalFormats` feature OFF, the member's stored
/// preferences are ignored and everything reads as it did before: the
/// derived locale, the format region's clock, the business's zone. With no
/// business open, the region is the device's, as on a personal surface.

@ProviderFor(businessFormat)
final businessFormatProvider = BusinessFormatProvider._();

/// The open business's format for the signed-in member (#711): their
/// format locale (or the shown language with the business's country), the
/// business's currency, their clock and zone preference.
///
/// Under the `regionalFormats` feature OFF, the member's stored
/// preferences are ignored and everything reads as it did before: the
/// derived locale, the format region's clock, the business's zone. With no
/// business open, the region is the device's, as on a personal surface.

final class BusinessFormatProvider
    extends $FunctionalProvider<AppFormat, AppFormat, AppFormat>
    with $Provider<AppFormat> {
  /// The open business's format for the signed-in member (#711): their
  /// format locale (or the shown language with the business's country), the
  /// business's currency, their clock and zone preference.
  ///
  /// Under the `regionalFormats` feature OFF, the member's stored
  /// preferences are ignored and everything reads as it did before: the
  /// derived locale, the format region's clock, the business's zone. With no
  /// business open, the region is the device's, as on a personal surface.
  BusinessFormatProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'businessFormatProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$businessFormatHash();

  @$internal
  @override
  $ProviderElement<AppFormat> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppFormat create(Ref ref) {
    return businessFormat(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppFormat value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppFormat>(value),
    );
  }
}

String _$businessFormatHash() => r'e1d48a3a0c1223f9a0825152a743d5751ea60db0';
