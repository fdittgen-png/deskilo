// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'personal_shell_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(personalShellEnabled)
final personalShellEnabledProvider = PersonalShellEnabledProvider._();

final class PersonalShellEnabledProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  PersonalShellEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'personalShellEnabledProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$personalShellEnabledHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return personalShellEnabled(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$personalShellEnabledHash() =>
    r'a1102901e076f847f9f64939fb22c79f03313389';
