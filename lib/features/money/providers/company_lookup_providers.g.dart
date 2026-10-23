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

/// Asking a registry now (the decision the supplier form asks for).

@ProviderFor(lookupCompany)
final lookupCompanyProvider = LookupCompanyProvider._();

/// Asking a registry now (the decision the supplier form asks for).

final class LookupCompanyProvider
    extends $FunctionalProvider<LookupCompany, LookupCompany, LookupCompany>
    with $Provider<LookupCompany> {
  /// Asking a registry now (the decision the supplier form asks for).
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

String _$lookupCompanyHash() => r'f3f8f4687d7ec71bf1e340c7c08fa24934f26216';
