// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2863 — the company-lookup contract: an identifier is normalised the
// same way whatever a person typed, a provider is chosen by capability,
// an answer is read without inventing a field, a verdict on the
// identifier is never retried as a network error, a duplicate is found by
// the identifier and never by the name, and the demo twin answers the
// same question the same way, offline.
import 'package:deskilo/core/demo/data/company_lookup_repository.dart';
import 'package:deskilo/core/demo/data/fixture_clock.dart';
import 'package:deskilo/features/money/application/lookup_company.dart';
import 'package:deskilo/features/money/data/supabase_company_lookup_repository.dart';
import 'package:deskilo/features/money/domain/company_lookup.dart';
import 'package:deskilo/features/money/domain/supplier.dart';
import 'package:deskilo/features/money/domain/supplier_prefill.dart';
import 'package:flutter_test/flutter_test.dart';

CompanyLookupRequest _request(String raw, {String country = ''}) =>
    CompanyLookupRequest(
      identifier: normalizeCompanyIdentifier(raw, country: country)!,
    );

void main() {
  group('identifier normalisation', () {
    test('separators, case and a typed prefix', () {
      final id = normalizeCompanyIdentifier(' fr 12.345-678/901 ')!;
      expect(id.prefix, 'FR');
      expect(id.countryCode, 'FR');
      expect(id.body, '12345678901');
      expect(id.canonical, 'FR12345678901');
      expect(id.display, 'fr 12.345-678/901', reason: 'what was typed stays');
    });

    test('a missing prefix comes from the country, and is shown', () {
      final id = normalizeCompanyIdentifier('123456789', country: 'de')!;
      expect(id.canonical, 'DE123456789');
      expect(id.display, 'DE 123456789');
    });

    test('Greece is asked for as EL and kept as GR', () {
      final typed = normalizeCompanyIdentifier('EL123456789')!;
      expect(typed.countryCode, 'GR');
      expect(typed.prefix, 'EL');
      final inferred = normalizeCompanyIdentifier('123456789', country: 'GR')!;
      expect(inferred.prefix, 'EL');
      expect(inferred.canonical, 'EL123456789');
    });

    test(
      'empty, malformed, bodiless and unprefixed-without-country are null',
      () {
        expect(normalizeCompanyIdentifier(''), isNull);
        expect(normalizeCompanyIdentifier('  . - '), isNull);
        expect(normalizeCompanyIdentifier('FR12;DROP', country: 'FR'), isNull);
        expect(normalizeCompanyIdentifier('FR'), isNull, reason: 'no body');
        expect(normalizeCompanyIdentifier('FR1'), isNull, reason: 'too short');
        expect(normalizeCompanyIdentifier('FR${'1' * 21}'), isNull);
        expect(
          normalizeCompanyIdentifier('123456789'),
          isNull,
          reason: 'no prefix and no country: the country must be explicit',
        );
      },
    );
  });

  group('provider selection by capability', () {
    final providers = companyLookupCapabilities();

    test('an EU VAT number goes to VIES', () {
      final p = selectCompanyLookupProvider(
        providers,
        _request('FR12345678901'),
      );
      expect(p?.providerId, viesProviderId);
      expect(p!.validatesIdentifier, isTrue);
      expect(p.fields, contains(CompanyField.legalName));
    });

    test(
      'a country outside the EU, another kind or name search is unsupported',
      () {
        expect(
          selectCompanyLookupProvider(providers, _request('US123456789')),
          isNull,
        );
        expect(
          selectCompanyLookupProvider(
            providers,
            CompanyLookupRequest(
              identifier: normalizeCompanyIdentifier('FR12345678901')!,
              kind: CompanyIdentifierKind.registration,
            ),
          ),
          isNull,
        );
        expect(
          selectCompanyLookupProvider(
            providers,
            CompanyLookupRequest(
              identifier: normalizeCompanyIdentifier('FR12345678901')!,
              mode: CompanyLookupMode.companyName,
            ),
          ),
          isNull,
        );
      },
    );

    test(
      'the command answers unsupported without asking the repository',
      () async {
        final repo = FakeCompanyLookupRepository();
        final result = await LookupCompany(repo)('ws', _request('US123456789'));
        expect(result.retrieval, LookupRetrieval.unsupported);
        expect(result.isRetryable, isFalse);
        expect(repo.requests, isEmpty);
      },
    );

    test('the wire carries the registry code and the bare body', () {
      final wire = _request('el 123 456 789').toWire(viesProviderId);
      expect(wire, {
        'provider': 'vies',
        'kind': 'vat',
        'mode': 'identifier',
        'country_code': 'EL',
        'identifier': '123456789',
      });
    });
  });

  group('reading an answer', () {
    test('a complete answer keeps every known field', () {
      final r = CompanyLookupResult.fromJson({
        'provider': 'vies',
        'looked_up_at': '2026-05-13T08:00:00Z',
        'retrieval': 'retrieved',
        'validation': 'validated',
        'fields': {
          'name': 'ACME SARL',
          'street': '1 rue A',
          'postal_code': '75001',
          'city': 'Paris',
          'country_code': 'FR',
          'iban': 'FR76 never',
        },
        'reference': 'WAPI1',
      });
      expect(r.retrieval, LookupRetrieval.retrieved);
      expect(r.validation, IdentifierValidation.validated);
      expect(r.fields.keys, hasLength(5), reason: 'no bank field exists');
      expect(r.lookedUpAt, isNotNull);
      expect(r.reference, 'WAPI1');
      expect(r.canReview, isTrue);
    });

    test('a partial or empty answer invents nothing', () {
      final partial = CompanyLookupResult.fromJson({
        'provider': 'vies',
        'retrieval': 'not_returned',
        'validation': 'validated',
        'fields': {'name': '   ', 'city': 'Berlin', 'country_code': ''},
      });
      expect(partial.fields, {CompanyField.city: 'Berlin'});
      expect(partial.canReview, isTrue);
      final empty = CompanyLookupResult.fromJson({
        'provider': 'vies',
        'retrieval': 'not_found',
        'validation': 'invalid',
      });
      expect(empty.fields, isEmpty);
      expect(empty.canReview, isFalse);
      expect(empty.lookedUpAt, isNull);
    });

    test('an unknown status word is a malformed answer, never a verdict', () {
      final r = CompanyLookupResult.fromJson({
        'provider': 'vies',
        'retrieval': 'definitely_fine',
        'validation': 'validated',
      });
      expect(r.retrieval, LookupRetrieval.malformed);
      expect(r.validation, IdentifierValidation.unavailable);
    });

    test('only transient failures are retryable', () {
      const transient = {
        LookupRetrieval.timeout,
        LookupRetrieval.throttled,
        LookupRetrieval.unavailable,
        LookupRetrieval.malformed,
      };
      for (final r in LookupRetrieval.values) {
        expect(r.isTransient, transient.contains(r), reason: r.name);
      }
      expect(
        CompanyLookupResult.failure(
          'vies',
          LookupRetrieval.notFound,
        ).validation,
        IdentifierValidation.notValidated,
      );
      expect(
        CompanyLookupResult.failure('vies', LookupRetrieval.timeout).validation,
        IdentifierValidation.unavailable,
      );
    });

    test(
      'the function\'s HTTP statuses map to outcomes; a refusal is none',
      () {
        expect(lookupFailureForStatus(400), LookupRetrieval.invalidInput);
        expect(lookupFailureForStatus(401), isNull);
        expect(lookupFailureForStatus(403), isNull);
        expect(lookupFailureForStatus(408), LookupRetrieval.timeout);
        expect(lookupFailureForStatus(429), LookupRetrieval.throttled);
        expect(lookupFailureForStatus(500), LookupRetrieval.unavailable);
        expect(lookupFailureForStatus(0), LookupRetrieval.unavailable);
      },
    );
  });

  group('the review step', () {
    final capability = companyLookupCapabilities().single;

    test(
      'returned fields replace typed ones and are marked; the rest stays',
      () {
        final request = _request('FR11223344556');
        const result = CompanyLookupResult(
          providerId: viesProviderId,
          retrieval: LookupRetrieval.retrieved,
          validation: IdentifierValidation.validated,
          fields: {
            CompanyField.legalName: 'Atelier SAS',
            CompanyField.city: 'Montpellier',
          },
        );
        final prefill = prefillFromLookup(
          request: request,
          result: result,
          capability: capability,
          base: const SupplierDraft(
            name: 'typed name',
            street: 'typed street',
            contact: 'typed contact',
            number: '42',
          ),
        );
        expect(prefill.draft.name, 'Atelier SAS');
        expect(prefill.draft.city, 'Montpellier');
        expect(prefill.draft.street, 'typed street');
        expect(prefill.draft.contact, 'typed contact');
        expect(prefill.draft.number, '42');
        expect(prefill.draft.taxId, 'FR11223344556');
        expect(
          prefill.draft.countryCode,
          'FR',
          reason: 'the request\'s country when none was returned',
        );
        expect(prefill.provenance, {
          'taxId': FieldProvenance.validated,
          'name': FieldProvenance.retrieved,
          'city': FieldProvenance.retrieved,
          'street': FieldProvenance.notReturned,
          'postalCode': FieldProvenance.notReturned,
          'countryCode': FieldProvenance.notReturned,
        });
      },
    );

    test('an unvalidated identifier carries no validated mark', () {
      final prefill = prefillFromLookup(
        request: _request('FR11223344556'),
        result: const CompanyLookupResult(
          providerId: 'registry-x',
          retrieval: LookupRetrieval.retrieved,
          validation: IdentifierValidation.notValidated,
          fields: {CompanyField.legalName: 'X'},
        ),
        capability: capability,
      );
      expect(prefill.provenance.containsKey('taxId'), isFalse);
    });
  });

  group('duplicates', () {
    const existing = [
      Supplier(
        id: 's1',
        number: '1',
        name: 'ACME',
        taxIdEntered: 'fr 12 345 678 901',
        taxIdentifier: 'FR12345678901',
      ),
      Supplier(
        id: 's2',
        number: '2',
        name: 'Beta',
        taxIdEntered: 'DE 1234 56789',
      ),
      Supplier(
        id: 's3',
        number: '3',
        name: 'Group',
        taxIdEntered: 'NL123456789B01',
        taxIdentifier: 'NL123456789B01',
        taxIdKind: SupplierIdKind.vatGroup,
      ),
    ];

    test('the same identifier in another spelling is the same supplier', () {
      expect(
        supplierWithIdentifier(
          existing,
          normalizeCompanyIdentifier('FR-12345678901')!,
        )?.id,
        's1',
      );
      expect(
        supplierWithIdentifier(
          existing,
          normalizeCompanyIdentifier('123456789', country: 'DE')!,
        )?.id,
        's2',
        reason: 'the typed text counts when the server verified nothing',
      );
    });

    test('a name alone, another number, or a VAT group never matches', () {
      expect(
        supplierWithIdentifier(
          existing,
          normalizeCompanyIdentifier('FR99999999999')!,
        ),
        isNull,
        reason: 'ACME exists, but with another identifier',
      );
      expect(
        supplierWithIdentifier(
          existing,
          normalizeCompanyIdentifier('NL123456789B01')!,
        ),
        isNull,
        reason: 'a group identifier is shared by several parties',
      );
    });
  });

  group('the demo twin', () {
    test('answers the same question the same way, offline', () async {
      final repo = FakeCompanyLookupRepository();
      final lookup = LookupCompany(repo);
      final a = await lookup('ws', _request('FR 11 223 344 556'));
      final b = await lookup('ws', _request('fr11223344556'));
      expect(a.fields, b.fields);
      expect(a.lookedUpAt, kTestNow);
      expect(a.fields[CompanyField.legalName], 'Atelier des Arceaux SAS');
      final none = await lookup('ws', _request('DE123456789'));
      expect(none.retrieval, LookupRetrieval.notReturned);
      expect(none.validation, IdentifierValidation.validated);
      final down = await lookup('ws', _request('IT00000000000'));
      expect(down.retrieval, LookupRetrieval.unavailable);
      expect(down.isRetryable, isTrue);
      final unknown = await lookup('ws', _request('FR99999999999'));
      expect(unknown.retrieval, LookupRetrieval.notFound);
      expect(unknown.validation, IdentifierValidation.invalid);
      expect(repo.requests, hasLength(5));
    });
  });
}
