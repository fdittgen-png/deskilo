// SPDX-License-Identifier: AGPL-3.0-or-later

/// The version of the VAT filing contract. An implementation declares the one it was
/// written against; the host refuses (and a lint pins) a mismatch. Bumped
/// when a type of this package changes in a way an implementation can see.
///
/// 2 (#3332): the context carries the filled form boxes, which an extracted
/// add-on reads instead of reaching for the tax reference of the application.
const String jurisdictionContractVersion = '2';

/// The version of the invoice profile contract (`InvoiceProfileContribution`,
/// `InvoiceDocumentContext`), versioned apart from the VAT filing contract: a
/// new capability is additive and must not make the compatible VAT add-ons
/// refuse (ADR 0050 §4: a version moves for breaking changes only).
const String invoiceProfileContractVersion = '1';

/// Who provides a capability and at which versions. Data, not behaviour: it
/// travels with every artifact as provenance.
class CapabilityDescriptor {
  const CapabilityDescriptor({
    required this.moduleId,
    required this.implementationVersion,
    required this.contractVersion,
    required this.formatVersion,
    required this.capabilityId,
  });

  /// The add-on that implements it (`fr.vat_filing`).
  final String moduleId;

  /// The implementation's own version: bumped when what it writes changes.
  final String implementationVersion;

  /// The [jurisdictionContractVersion] it was written against.
  final String contractVersion;

  /// The version of the file format or profile it writes (the authority's
  /// schema, a form layout year).
  final String formatVersion;

  /// The EXISTING identifier of the capability or format it provides
  /// (`vat_filing.FR`): never a new name for something already named.
  final String capabilityId;

  /// The facts a [GeneratedArtifact] records about its producer.
  Map<String, String> toProvenance() => {
    'module_id': moduleId,
    'implementation_version': implementationVersion,
    'contract_version': contractVersion,
    'format_version': formatVersion,
    'capability_id': capabilityId,
  };
}
