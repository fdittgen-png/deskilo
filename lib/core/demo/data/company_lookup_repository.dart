// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/money/domain/company_lookup.dart';
import 'fixture_clock.dart';

/// #2863 — company lookups in memory. Demo never reaches a registry: the
/// answers are fixtures, one per outcome the form must show, and an
/// identifier no fixture names is one the registry does not know. The
/// same question always gets the same answer.
class FakeCompanyLookupRepository implements CompanyLookupRepository {
  FakeCompanyLookupRepository({DateTime? now}) : _now = now ?? kTestNow;

  final DateTime _now;

  /// Canonical identifier (registry code + body) → the answer. Tests and
  /// the demo seed add to it.
  late final Map<String, CompanyLookupResult> answers = {
    // A member state that discloses name and address.
    'FR11223344556': CompanyLookupResult(
      providerId: viesProviderId,
      retrieval: LookupRetrieval.retrieved,
      validation: IdentifierValidation.validated,
      lookedUpAt: _now,
      reference: 'DEMO-CONSULTATION-1',
      fields: const {
        CompanyField.legalName: 'Atelier des Arceaux SAS',
        CompanyField.street: '7 rue des Arceaux',
        CompanyField.postalCode: '34000',
        CompanyField.city: 'Montpellier',
        CompanyField.countryCode: 'FR',
      },
    ),
    // A member state that validates the number and discloses nothing else.
    'DE123456789': CompanyLookupResult(
      providerId: viesProviderId,
      retrieval: LookupRetrieval.notReturned,
      validation: IdentifierValidation.validated,
      lookedUpAt: _now,
      reference: 'DEMO-CONSULTATION-2',
      fields: const {CompanyField.countryCode: 'DE'},
    ),
    // A member state whose registry is not answering.
    'IT00000000000': CompanyLookupResult.failure(
      viesProviderId,
      LookupRetrieval.unavailable,
      lookedUpAt: _now,
      detail: 'MS_UNAVAILABLE',
    ),
  };

  /// Every question asked, in order.
  final List<CompanyLookupRequest> requests = [];

  @override
  Future<CompanyLookupResult> lookup(
    String workspaceId,
    String providerId,
    CompanyLookupRequest request,
  ) async {
    requests.add(request);
    return answers[request.identifier.canonical] ??
        CompanyLookupResult(
          providerId: providerId,
          retrieval: LookupRetrieval.notFound,
          validation: IdentifierValidation.invalid,
          lookedUpAt: _now,
        );
  }
}
