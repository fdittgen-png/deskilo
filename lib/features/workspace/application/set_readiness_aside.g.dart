// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_readiness_aside.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #1636 (0307) — setting readiness sections aside, and taking them back.

@ProviderFor(readinessAside)
final readinessAsideProvider = ReadinessAsideProvider._();

/// #1636 (0307) — setting readiness sections aside, and taking them back.

final class ReadinessAsideProvider
    extends $FunctionalProvider<ReadinessAside, ReadinessAside, ReadinessAside>
    with $Provider<ReadinessAside> {
  /// #1636 (0307) — setting readiness sections aside, and taking them back.
  ReadinessAsideProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'readinessAsideProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$readinessAsideHash();

  @$internal
  @override
  $ProviderElement<ReadinessAside> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ReadinessAside create(Ref ref) {
    return readinessAside(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReadinessAside value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReadinessAside>(value),
    );
  }
}

String _$readinessAsideHash() => r'1e8fbe5d069a77c54f08358d1a7089212f1ddcc7';
