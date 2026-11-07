// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3331 (of #3328) -- which installed add-on provides a capability for a legal
// context. The first implementation keys on the same fact used today (ADR 0043:
// the workspace's country); a resolution by issuer is a separate, later change.
//
// An unknown, missing or conflicting jurisdiction is an EXPLICIT refusal. This
// file never reads `CountryCatalog.byCode`, whose unknown-code fallback is
// France: a space in a country with no add-on must be told so, not given the
// French file. No user-facing text lives here -- the UI maps [RefusalKind] to
// its own words.
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

/// What a host asks an add-on to do.
enum JurisdictionOperation { vatFiling }

/// The legal facts a capability is chosen by: the workspace's country
/// (ISO 3166-1 alpha-2; null or blank when unknown).
class LegalContext {
  const LegalContext({this.countryCode});

  final String? countryCode;

  /// The country as the registry spells it: trimmed, upper case, `UK` is `GB`.
  String get normalized => switch ((countryCode ?? '').trim().toUpperCase()) {
    'UK' => 'GB',
    final c => c,
  };
}

/// Why no add-on was chosen.
enum RefusalKind {
  /// The context names no country.
  missingJurisdiction,

  /// No installed add-on provides the capability for that country.
  unknownJurisdiction,

  /// More than one installed add-on claims it: the host refuses to guess.
  conflictingJurisdiction,

  /// The add-on was written against another version of the contract.
  contractMismatch,
}

sealed class CapabilityResolution {
  const CapabilityResolution();
}

/// The add-on to use.
class Resolved extends CapabilityResolution {
  const Resolved(this.contribution);

  final VatFilingContribution contribution;

  /// The country the add-on files for (`vat_filing.DE` is `DE`).
  String get country => _countryOf(contribution);
}

/// No add-on, and why.
class Refused extends CapabilityResolution {
  const Refused(this.kind);

  final RefusalKind kind;
}

/// The capability id every VAT filing add-on uses, per country.
String vatFilingCapabilityId(String country) => 'vat_filing.$country';

/// The country a VAT filing [contribution] files for, from its capability id.
String _countryOf(VatFilingContribution contribution) =>
    contribution.descriptor.capabilityId.split('.').last;

/// The add-on of [installed] that provides [operation] for [context], or the
/// reason there is none.
CapabilityResolution resolveCapability(
  JurisdictionOperation operation,
  LegalContext context,
  List<VatFilingContribution> installed,
) {
  final country = context.normalized;
  if (country.isEmpty) return const Refused(RefusalKind.missingJurisdiction);
  final id = switch (operation) {
    JurisdictionOperation.vatFiling => vatFilingCapabilityId(country),
  };
  final matches = [
    for (final c in installed)
      if (c.descriptor.capabilityId == id) c,
  ];
  if (matches.isEmpty) return const Refused(RefusalKind.unknownJurisdiction);
  if (matches.length > 1) {
    return const Refused(RefusalKind.conflictingJurisdiction);
  }
  if (matches.single.descriptor.contractVersion !=
      jurisdictionContractVersion) {
    return const Refused(RefusalKind.contractMismatch);
  }
  return Resolved(matches.single);
}
