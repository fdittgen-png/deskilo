// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/settings/setting_defaults.g.dart';
import '../../../core/settings/settings.dart';
import '../domain/company_lookup.dart';

/// The server setting that bounds one registry question.
const String _timeoutKey = 'purchase.supplier_lookup_timeout_seconds';

/// What the app adds to the server's registry wait before it gives up on
/// the function itself: the function's start and the round trip. Not a
/// choice — the registry's wait is the setting.
const Duration _transportMargin = Duration(seconds: 10);

/// How long the app waits for one lookup: the server's registry wait
/// (`purchase.supplier_lookup_timeout_seconds` of [settings]) plus the
/// transport margin. Before the settings load, or on a server whose
/// registry predates the key, the registry default stands.
Duration supplierLookupWait(SettingsSet? settings) {
  final seconds =
      settings != null && settings.definitions.containsKey(_timeoutKey)
      ? settings.read<int>(_timeoutKey)
      : SettingDefaults.purchaseSupplierLookupTimeoutSeconds;
  return Duration(seconds: seconds) + _transportMargin;
}

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
    this._wait,
  }) : _overridden = providers;

  final CompanyLookupRepository _repository;

  final Duration? _wait;

  /// How long one question is waited for ([supplierLookupWait]).
  Duration get wait => _wait ?? supplierLookupWait(null);

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
    return _repository.lookup(
      workspaceId,
      provider.providerId,
      request,
      wait: wait,
    );
  }
}
