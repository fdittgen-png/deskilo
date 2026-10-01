// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'capture_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #1824 — the ONE capture protection of this app window; every open
/// thread holds it through [CaptureProtection.enable].

@ProviderFor(captureProtection)
final captureProtectionProvider = CaptureProtectionProvider._();

/// #1824 — the ONE capture protection of this app window; every open
/// thread holds it through [CaptureProtection.enable].

final class CaptureProtectionProvider
    extends
        $FunctionalProvider<
          CaptureProtection,
          CaptureProtection,
          CaptureProtection
        >
    with $Provider<CaptureProtection> {
  /// #1824 — the ONE capture protection of this app window; every open
  /// thread holds it through [CaptureProtection.enable].
  CaptureProtectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'captureProtectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$captureProtectionHash();

  @$internal
  @override
  $ProviderElement<CaptureProtection> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CaptureProtection create(Ref ref) {
    return captureProtection(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CaptureProtection value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CaptureProtection>(value),
    );
  }
}

String _$captureProtectionHash() => r'b8674eea556e6efa066ba89cbdd4ae985f28e929';

/// The reader's own name — the faint watermark a web thread carries, so
/// a screenshot shared onwards says whose screen it was taken from.

@ProviderFor(captureReaderName)
final captureReaderNameProvider = CaptureReaderNameProvider._();

/// The reader's own name — the faint watermark a web thread carries, so
/// a screenshot shared onwards says whose screen it was taken from.

final class CaptureReaderNameProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// The reader's own name — the faint watermark a web thread carries, so
  /// a screenshot shared onwards says whose screen it was taken from.
  CaptureReaderNameProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'captureReaderNameProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$captureReaderNameHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return captureReaderName(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$captureReaderNameHash() => r'04f0bea77a31b735dcb989c4edf70ca4443bb78c';
