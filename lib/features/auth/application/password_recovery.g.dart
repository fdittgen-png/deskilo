// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'password_recovery.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One flow per sheet: the provider is not kept alive, so a sheet opened
/// later starts at the request step again.

@ProviderFor(passwordRecovery)
final passwordRecoveryProvider = PasswordRecoveryProvider._();

/// One flow per sheet: the provider is not kept alive, so a sheet opened
/// later starts at the request step again.

final class PasswordRecoveryProvider
    extends
        $FunctionalProvider<
          PasswordRecovery,
          PasswordRecovery,
          PasswordRecovery
        >
    with $Provider<PasswordRecovery> {
  /// One flow per sheet: the provider is not kept alive, so a sheet opened
  /// later starts at the request step again.
  PasswordRecoveryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'passwordRecoveryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$passwordRecoveryHash();

  @$internal
  @override
  $ProviderElement<PasswordRecovery> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PasswordRecovery create(Ref ref) {
    return passwordRecovery(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PasswordRecovery value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PasswordRecovery>(value),
    );
  }
}

String _$passwordRecoveryHash() => r'92663c47ebc9fcf847dab1529dd557e04f9dbeb6';
