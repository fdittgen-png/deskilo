// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'oauth_consent_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(oauthConsentRepository)
final oauthConsentRepositoryProvider = OauthConsentRepositoryProvider._();

final class OauthConsentRepositoryProvider
    extends
        $FunctionalProvider<
          OAuthConsentRepository,
          OAuthConsentRepository,
          OAuthConsentRepository
        >
    with $Provider<OAuthConsentRepository> {
  OauthConsentRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'oauthConsentRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$oauthConsentRepositoryHash();

  @$internal
  @override
  $ProviderElement<OAuthConsentRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OAuthConsentRepository create(Ref ref) {
    return oauthConsentRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OAuthConsentRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OAuthConsentRepository>(value),
    );
  }
}

String _$oauthConsentRepositoryHash() =>
    r'9da663755c63147eeedc4a4d8c44ba9076fcfabe';

@ProviderFor(oauthConsent)
final oauthConsentProvider = OauthConsentFamily._();

final class OauthConsentProvider
    extends
        $FunctionalProvider<
          AsyncValue<OAuthConsentRequest>,
          OAuthConsentRequest,
          FutureOr<OAuthConsentRequest>
        >
    with
        $FutureModifier<OAuthConsentRequest>,
        $FutureProvider<OAuthConsentRequest> {
  OauthConsentProvider._({
    required OauthConsentFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'oauthConsentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$oauthConsentHash();

  @override
  String toString() {
    return r'oauthConsentProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<OAuthConsentRequest> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<OAuthConsentRequest> create(Ref ref) {
    final argument = this.argument as String;
    return oauthConsent(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is OauthConsentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$oauthConsentHash() => r'fb242cae4499168245f9972cf709093e6abac9b7';

final class OauthConsentFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<OAuthConsentRequest>, String> {
  OauthConsentFamily._()
    : super(
        retry: null,
        name: r'oauthConsentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  OauthConsentProvider call(String authorizationId) =>
      OauthConsentProvider._(argument: authorizationId, from: this);

  @override
  String toString() => r'oauthConsentProvider';
}
