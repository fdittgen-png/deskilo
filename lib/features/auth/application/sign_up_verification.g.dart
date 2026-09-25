// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sign_up_verification.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(signUpVerification)
final signUpVerificationProvider = SignUpVerificationProvider._();

final class SignUpVerificationProvider
    extends
        $FunctionalProvider<
          SignUpVerification,
          SignUpVerification,
          SignUpVerification
        >
    with $Provider<SignUpVerification> {
  SignUpVerificationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'signUpVerificationProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$signUpVerificationHash();

  @$internal
  @override
  $ProviderElement<SignUpVerification> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SignUpVerification create(Ref ref) {
    return signUpVerification(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SignUpVerification value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SignUpVerification>(value),
    );
  }
}

String _$signUpVerificationHash() =>
    r'7d1fd9b3408675617082e9c162a6bc1a215af66f';
