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
import 'package:meta/meta.dart';

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

  /// No installed add-on provides the invoice profile of that format.
  unknownProfile,

  /// More than one installed add-on claims the invoice profile.
  conflictingProfile,

  /// More than one installed add-on claims the mentions of that country.
  conflictingMentions,
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

/// The capability id every VAT filing add-on uses, per country. An add-on
/// declares it in its own descriptor; the resolver and the tests build it here.
@visibleForTesting
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

/// The capability id of the invoice profile that renders [formatId] (the
/// EXISTING name of the format: `EInvoiceFormat.fatturaPa.name`).
@visibleForTesting
String invoiceProfileCapabilityId(String formatId) =>
    'invoice_profile.$formatId';

sealed class ProfileResolution {
  const ProfileResolution();
}

/// The invoice profile to use.
class ResolvedProfile extends ProfileResolution {
  const ResolvedProfile(this.profile);

  final InvoiceProfileContribution profile;
}

/// No invoice profile, and why.
class RefusedProfile extends ProfileResolution {
  const RefusedProfile(this.kind);

  final RefusalKind kind;
}

/// The installed invoice profile that renders [formatId], or the reason there
/// is none. The format is chosen by the channel, never by a country switch
/// here; an unknown format is an explicit refusal, never a default.
ProfileResolution resolveInvoiceProfile(
  String formatId,
  List<InvoiceProfileContribution> installed,
) {
  final id = invoiceProfileCapabilityId(formatId);
  final matches = [
    for (final c in installed)
      if (c.descriptor.capabilityId == id) c,
  ];
  if (matches.isEmpty) return const RefusedProfile(RefusalKind.unknownProfile);
  if (matches.length > 1) {
    return const RefusedProfile(RefusalKind.conflictingProfile);
  }
  if (matches.single.descriptor.contractVersion !=
      invoiceProfileContractVersion) {
    return const RefusedProfile(RefusalKind.contractMismatch);
  }
  return ResolvedProfile(matches.single);
}

/// The capability id of the national invoice mentions of [country].
@visibleForTesting
String invoiceMentionsCapabilityId(String country) =>
    'invoice_mentions.$country';

sealed class MentionsResolution {
  const MentionsResolution();
}

/// The country's own law adds lines, and the add-on that states them.
@visibleForTesting
class ResolvedMentions extends MentionsResolution {
  const ResolvedMentions(this.contribution);

  final InvoiceMentionsContribution contribution;
}

/// No installed add-on states mentions for the country. That is NOT a fault
/// (most countries add nothing): it is the empty answer, never a fallback to
/// another country's lines.
@visibleForTesting
class NoMentions extends MentionsResolution {
  const NoMentions();
}

/// An installed composition that cannot answer, and why.
@visibleForTesting
class RefusedMentions extends MentionsResolution {
  const RefusedMentions(this.kind);

  final RefusalKind kind;
}

/// The installed mentions add-on of [context]'s country, none, or the reason
/// the composition is wrong. Test-only until the add-ons implement the
/// contract and `report_data.dart` asks it (#3429, the next change).
@visibleForTesting
MentionsResolution resolveInvoiceMentions(
  LegalContext context,
  List<InvoiceMentionsContribution> installed,
) {
  final country = context.normalized;
  if (country.isEmpty) return const NoMentions();
  final id = invoiceMentionsCapabilityId(country);
  final matches = [
    for (final c in installed)
      if (c.descriptor.capabilityId == id) c,
  ];
  if (matches.isEmpty) return const NoMentions();
  if (matches.length > 1) {
    return const RefusedMentions(RefusalKind.conflictingMentions);
  }
  if (matches.single.descriptor.contractVersion !=
      invoiceMentionsContractVersion) {
    return const RefusedMentions(RefusalKind.contractMismatch);
  }
  return ResolvedMentions(matches.single);
}
