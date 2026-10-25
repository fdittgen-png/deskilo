// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'personal_return_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(personalReturn)
final personalReturnProvider = PersonalReturnProvider._();

final class PersonalReturnProvider
    extends $FunctionalProvider<PersonalReturn, PersonalReturn, PersonalReturn>
    with $Provider<PersonalReturn> {
  PersonalReturnProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'personalReturnProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$personalReturnHash();

  @$internal
  @override
  $ProviderElement<PersonalReturn> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PersonalReturn create(Ref ref) {
    return personalReturn(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PersonalReturn value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PersonalReturn>(value),
    );
  }
}

String _$personalReturnHash() => r'304bd6671b35d754dccb59d5589a6d9c3e564eb1';
