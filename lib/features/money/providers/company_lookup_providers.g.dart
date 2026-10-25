// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'company_lookup_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(companyLookupRepository)
final companyLookupRepositoryProvider = CompanyLookupRepositoryProvider._();

final class CompanyLookupRepositoryProvider
    extends
        $FunctionalProvider<
          CompanyLookupRepository,
          CompanyLookupRepository,
          CompanyLookupRepository
        >
    with $Provider<CompanyLookupRepository> {
  CompanyLookupRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'companyLookupRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$companyLookupRepositoryHash();

  @$internal
  @override
  $ProviderElement<CompanyLookupRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CompanyLookupRepository create(Ref ref) {
    return companyLookupRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CompanyLookupRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CompanyLookupRepository>(value),
    );
  }
}

String _$companyLookupRepositoryHash() =>
    r'202ee121cff254d83381d2fff24a7599f2bb16ea';

/// Asking a registry now (the decision the supplier form asks for), waited
/// for the server's own registry wait plus the round trip.

@ProviderFor(lookupCompany)
final lookupCompanyProvider = LookupCompanyProvider._();

/// Asking a registry now (the decision the supplier form asks for), waited
/// for the server's own registry wait plus the round trip.

final class LookupCompanyProvider
    extends $FunctionalProvider<LookupCompany, LookupCompany, LookupCompany>
    with $Provider<LookupCompany> {
  /// Asking a registry now (the decision the supplier form asks for), waited
  /// for the server's own registry wait plus the round trip.
  LookupCompanyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lookupCompanyProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lookupCompanyHash();

  @$internal
  @override
  $ProviderElement<LookupCompany> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LookupCompany create(Ref ref) {
    return lookupCompany(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LookupCompany value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LookupCompany>(value),
    );
  }
}

String _$lookupCompanyHash() => r'1bf194499d31feeda7af887d7c5c9fd62a73fe0e';
