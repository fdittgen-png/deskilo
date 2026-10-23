// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Looking a supplier up in a company registry: the provider-neutral
// contract between the supplier form and whichever registry answers. The
// form asks with a country and an identifier and reads back normalised
// fields, who answered and when, and TWO separate verdicts — whether a
// record came back and whether the identifier itself was validated — so a
// registry that only validates a number (VIES for most member states) is
// never presented as a company profile, and a profile without validation
// is never presented as a verified identifier.
//
// A registry's own response shape never reaches this file: the edge
// function's adapter speaks it and answers in these terms.
import '../../../core/data/json_reader.dart';
import '../../../core/vat/place_of_supply.dart';
import '../../../core/vat/tax_reference.dart';
import '../../../core/vat/tax_reference_active.dart';

/// What kind of identifier a person typed.
enum CompanyIdentifierKind {
  /// A VAT identification number, prefixed by the member state's code.
  vat('vat'),

  /// A national business-register number (a SIREN, a Handelsregister
  /// number): no provider answers these yet, the seam is for them.
  registration('registration');

  const CompanyIdentifierKind(this.wire);

  final String wire;
}

/// How a provider is asked.
enum CompanyLookupMode {
  /// By identifier: the only mode every registry supports.
  identifier('identifier'),

  /// By company name, where a registry offers it. Not universal.
  companyName('name');

  const CompanyLookupMode(this.wire);

  final String wire;
}

/// The supplier fields a registry can fill. Only what the supplier model
/// stores: no payment terms, no bank account, no contact a registry does
/// not hold.
enum CompanyField {
  legalName('name'),
  street('street'),
  postalCode('postal_code'),
  city('city'),
  countryCode('country_code');

  const CompanyField(this.wire);

  final String wire;

  static CompanyField? ofWire(String? wire) {
    for (final f in values) {
      if (f.wire == wire) return f;
    }
    return null;
  }
}

/// Whether a record came back — distinct from whether the identifier is
/// valid ([IdentifierValidation]).
enum LookupRetrieval {
  /// The registry returned at least one profile field.
  retrieved('retrieved'),

  /// The registry answered but holds (or discloses) no profile fields for
  /// this record: nothing to prefill beyond what the person typed.
  notReturned('not_returned'),

  /// The registry knows no such record.
  notFound('not_found'),

  /// The registry rejected the identifier's shape before looking.
  invalidInput('invalid_input'),

  /// No provider answers this country, identifier kind or mode.
  unsupported('unsupported'),

  /// The registry did not answer in time.
  timeout('timeout'),

  /// The registry (or this installation) is refusing more requests for now.
  throttled('throttled'),

  /// The registry is down, or the member state behind it is.
  unavailable('unavailable'),

  /// The registry answered something the adapter could not read.
  malformed('malformed');

  const LookupRetrieval(this.wire);

  final String wire;

  static LookupRetrieval ofWire(String? wire) {
    for (final r in values) {
      if (r.wire == wire) return r;
    }
    return malformed;
  }

  /// Whether asking again can change the answer. A verdict on the
  /// identifier (not found, rejected) is never retried as if it were a
  /// network error.
  bool get isTransient => switch (this) {
    timeout || throttled || unavailable || malformed => true,
    retrieved ||
    notReturned ||
    notFound ||
    invalidInput ||
    unsupported => false,
  };

  /// Whether the person can go on to the review step with this answer.
  bool get canReview => this == retrieved || this == notReturned;
}

/// What the registry said about the identifier itself.
enum IdentifierValidation {
  /// The registry confirms the identifier is registered.
  validated('validated'),

  /// The registry says the identifier is not registered.
  invalid('invalid'),

  /// The registry does not validate identifiers, or was not asked.
  notValidated('not_validated'),

  /// The registry could not say (outage, timeout, throttling).
  unavailable('unavailable');

  const IdentifierValidation(this.wire);

  final String wire;

  static IdentifierValidation ofWire(String? wire) {
    for (final v in values) {
      if (v.wire == wire) return v;
    }
    return notValidated;
  }
}

/// A typed identifier, normalised for a lookup and kept as typed for the
/// person. The registry code ([prefix]) and the ISO country differ for
/// Greece (`EL` / `GR`): the lookup speaks the registry's code, the
/// supplier's address keeps the ISO one.
class CompanyIdentifier {
  const CompanyIdentifier({
    required this.countryCode,
    required this.prefix,
    required this.body,
    required this.display,
  });

  /// ISO 3166-1 alpha-2 of the registry's country.
  final String countryCode;

  /// The code the registry uses for that country (`EL` for Greece).
  final String prefix;

  /// Letters and digits only, upper case, separators removed.
  final String body;

  /// What the person typed, trimmed, with the prefix added when missing.
  final String display;

  /// The comparison key: prefix and body, nothing else.
  String get canonical => '$prefix$body';
}

/// The separators a person may type inside an identifier.
final _separators = RegExp(r'[\s.\-/]');
final _identifierBody = RegExp(r'^[A-Z0-9]+$');

/// [raw] without the permitted separators, upper case: the form two
/// spellings of one identifier are compared in.
String compactIdentifier(String raw) =>
    raw.replaceAll(_separators, '').toUpperCase();
final _twoLetters = RegExp(r'^[A-Z]{2}');

/// The shortest and longest identifier body any registry accepts — a
/// protocol bound of the lookup, not a business value.
const int _minBodyLength = 2;
const int _maxBodyLength = 20;

/// Normalises what a person typed: trims, drops the permitted separators,
/// upper-cases, reads a two-letter prefix off the front or takes it from
/// [country] (ISO). Null when nothing usable remains: empty, a character
/// no identifier holds, no country to infer the prefix from, or a body
/// outside the bounds.
CompanyIdentifier? normalizeCompanyIdentifier(
  String raw, {
  String country = '',
  TaxReferenceSet? reference,
}) {
  final typed = raw.trim();
  var compact = compactIdentifier(typed);
  if (compact.isEmpty || !_identifierBody.hasMatch(compact)) return null;
  String prefix;
  if (_twoLetters.hasMatch(compact)) {
    prefix = compact.substring(0, 2);
    compact = compact.substring(2);
  } else {
    final iso = country.trim().toUpperCase();
    if (iso.isEmpty) return null;
    prefix = _registryCountryCode(iso, reference: reference);
  }
  if (compact.length < _minBodyLength || compact.length > _maxBodyLength) {
    return null;
  }
  final hadPrefix = typed.toUpperCase().startsWith(prefix);
  return CompanyIdentifier(
    countryCode: euCountryCode(prefix, reference: reference),
    prefix: prefix,
    body: compact,
    display: hadPrefix ? typed : '$prefix $typed',
  );
}

/// The code a registry uses for ISO country [iso]: the alias row of the
/// `eu_member` reference (`GR` is asked for as `EL`), else the code itself.
String _registryCountryCode(String iso, {TaxReferenceSet? reference}) {
  final code = iso.trim().toUpperCase();
  final set = (reference ?? ActiveTaxReference.current).resolved(null);
  for (final row in set.where(TaxDomain.euMember)) {
    final value = row.value as EuMemberValue;
    if (value.isAlias && value.aliasOf == code) return row.country;
  }
  return code;
}

/// One question to a registry.
class CompanyLookupRequest {
  const CompanyLookupRequest({
    required this.identifier,
    this.kind = CompanyIdentifierKind.vat,
    this.mode = CompanyLookupMode.identifier,
  });

  final CompanyIdentifier identifier;
  final CompanyIdentifierKind kind;
  final CompanyLookupMode mode;

  /// ISO country of the registry asked.
  String get countryCode => identifier.countryCode;

  /// What the edge function reads: the registry's own country code and
  /// the bare body, never the typed text.
  Map<String, Object?> toWire(String providerId) => {
    'provider': providerId,
    'kind': kind.wire,
    'mode': mode.wire,
    'country_code': identifier.prefix,
    'identifier': identifier.body,
  };
}

/// What a registry answered, in neutral terms.
class CompanyLookupResult {
  const CompanyLookupResult({
    required this.providerId,
    required this.retrieval,
    required this.validation,
    this.fields = const {},
    this.lookedUpAt,
    this.reference = '',
    this.detail = '',
  });

  /// A failure before or instead of an answer; [validation] follows the
  /// kind of failure unless given.
  CompanyLookupResult.failure(
    this.providerId,
    this.retrieval, {
    IdentifierValidation? validation,
    this.lookedUpAt,
    this.detail = '',
  }) : fields = const {},
       reference = '',
       validation =
           validation ??
           (retrieval.isTransient
               ? IdentifierValidation.unavailable
               : IdentifierValidation.notValidated);

  /// The edge function's answer. Only known fields with text survive: an
  /// empty value is "not returned", never a blank prefill; an unknown
  /// status word is a malformed answer, never a verdict.
  factory CompanyLookupResult.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'supplier-lookup');
    final fields = <CompanyField, String>{};
    for (final entry in r.objectOrEmpty('fields').entries) {
      final field = CompanyField.ofWire(entry.key);
      final value = entry.value;
      if (field == null || value is! String) continue;
      final text = value.trim();
      if (text.isNotEmpty) fields[field] = text;
    }
    final retrieval = LookupRetrieval.ofWire(r.stringOrNull('retrieval'));
    final at = r.stringOrNull('looked_up_at');
    return CompanyLookupResult(
      providerId: r.stringOr('provider'),
      retrieval: retrieval,
      validation: retrieval == LookupRetrieval.malformed
          ? IdentifierValidation.unavailable
          : IdentifierValidation.ofWire(r.stringOrNull('validation')),
      fields: fields,
      lookedUpAt: at == null ? null : DateTime.tryParse(at)?.toLocal(),
      reference: r.stringOr('reference'),
      detail: r.stringOr('detail'),
    );
  }

  final String providerId;
  final LookupRetrieval retrieval;
  final IdentifierValidation validation;

  /// Only the fields the registry actually returned.
  final Map<CompanyField, String> fields;
  final DateTime? lookedUpAt;

  /// The registry's own reference for this answer (a VIES consultation
  /// number), when it gave one.
  final String reference;

  /// The registry's own words for a failure; never shown as such.
  final String detail;

  bool get canReview => retrieval.canReview;
  bool get isRetryable => retrieval.isTransient;
}

/// What one provider can do, so the app picks it by capability and never
/// by a hard-coded condition on a country.
class CompanyLookupCapability {
  const CompanyLookupCapability({
    required this.providerId,
    required this.countries,
    required this.identifierKinds,
    required this.modes,
    required this.fields,
    required this.validatesIdentifier,
  });

  final String providerId;

  /// ISO countries the provider answers for.
  final Set<String> countries;
  final Set<CompanyIdentifierKind> identifierKinds;
  final Set<CompanyLookupMode> modes;

  /// The fields it may return — may, not will: a member state is free to
  /// withhold them.
  final Set<CompanyField> fields;
  final bool validatesIdentifier;

  bool supports(CompanyLookupRequest request) =>
      countries.contains(request.countryCode) &&
      identifierKinds.contains(request.kind) &&
      modes.contains(request.mode);
}

/// The EU's VAT Information Exchange System: validates a VAT number and
/// returns the name and address when the member state discloses them.
const String viesProviderId = 'vies';

/// The providers this installation can ask, each described by what it
/// does. VIES covers every EU member state of the tax reference store
/// (the `eu_member` rows: data, never a list in code), VAT numbers only,
/// by identifier only. A national register joins this list with its own
/// capability and its own adapter in the edge function.
List<CompanyLookupCapability> companyLookupCapabilities({
  TaxReferenceSet? reference,
}) => [
  CompanyLookupCapability(
    providerId: viesProviderId,
    countries: (reference ?? ActiveTaxReference.current).euMembers(),
    identifierKinds: const {CompanyIdentifierKind.vat},
    modes: const {CompanyLookupMode.identifier},
    fields: const {
      CompanyField.legalName,
      CompanyField.street,
      CompanyField.postalCode,
      CompanyField.city,
      CompanyField.countryCode,
    },
    validatesIdentifier: true,
  ),
];

/// The first provider whose capability covers [request]; null = unsupported.
CompanyLookupCapability? selectCompanyLookupProvider(
  Iterable<CompanyLookupCapability> providers,
  CompanyLookupRequest request,
) {
  for (final p in providers) {
    if (p.supports(request)) return p;
  }
  return null;
}

/// Where the lookups are made. The server decides who may ask (the same
/// guard as saving a supplier, plus the verification flag) and talks to
/// the registry; nothing is stored by a lookup.
abstract interface class CompanyLookupRepository {
  /// Asks [providerId] about [request] on behalf of [workspaceId]. What the
  /// registry answered — an outage included — is a result; only the
  /// server's refusal of the caller is thrown, as [CompanyLookupRefused].
  Future<CompanyLookupResult> lookup(
    String workspaceId,
    String providerId,
    CompanyLookupRequest request,
  );
}

/// The server refused the caller: no permission, or the flag is off.
class CompanyLookupRefused implements Exception {
  const CompanyLookupRefused(this.reason);

  final String reason;

  @override
  String toString() => 'CompanyLookupRefused($reason)';
}
