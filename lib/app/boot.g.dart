// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'boot.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Warm-up of everything the first screen needs (field request: the
/// user must never watch the form being constructed). The boot splash
/// stays up until this resolves; each step is failure-proof, so boot
/// can be slow but never stuck or fatal.

@ProviderFor(bootReady)
final bootReadyProvider = BootReadyProvider._();

/// Warm-up of everything the first screen needs (field request: the
/// user must never watch the form being constructed). The boot splash
/// stays up until this resolves; each step is failure-proof, so boot
/// can be slow but never stuck or fatal.

final class BootReadyProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Warm-up of everything the first screen needs (field request: the
  /// user must never watch the form being constructed). The boot splash
  /// stays up until this resolves; each step is failure-proof, so boot
  /// can be slow but never stuck or fatal.
  BootReadyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bootReadyProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bootReadyHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return bootReady(ref);
  }
}

String _$bootReadyHash() => r'79f3eafbc32a5b0e0a03187e77bd089725ab36e6';
