// SPDX-License-Identifier: AGPL-3.0-or-later
import '../domain/company_lookup.dart';

/// "Ask a registry about this identifier": the decision behind the
/// supplier form's Find company details. The provider is chosen by what
/// it can do, never by the country alone; a request no provider covers is
/// answered as unsupported without a network call. One attempt per call:
/// the person retries a transient failure, the app never retries a
/// verdict on the identifier.
class LookupCompany {
  const LookupCompany(
    this._repository, {
    List<CompanyLookupCapability>? providers,
  }) : _overridden = providers;

  final CompanyLookupRepository _repository;

  /// A fixed list, for a test; the app reads the capabilities as data.
  final List<CompanyLookupCapability>? _overridden;

  List<CompanyLookupCapability> get providers =>
      _overridden ?? companyLookupCapabilities();

  /// The provider that would answer [request], or null.
  CompanyLookupCapability? providerFor(CompanyLookupRequest request) =>
      selectCompanyLookupProvider(providers, request);

  /// Throws [CompanyLookupRefused] when the server refuses the caller;
  /// everything the registry said, an outage included, is a result.
  Future<CompanyLookupResult> call(
    String workspaceId,
    CompanyLookupRequest request,
  ) async {
    final provider = providerFor(request);
    if (provider == null) {
      return CompanyLookupResult.failure('', LookupRetrieval.unsupported);
    }
    return _repository.lookup(workspaceId, provider.providerId, request);
  }
}
