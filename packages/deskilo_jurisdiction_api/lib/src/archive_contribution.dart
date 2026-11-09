// SPDX-License-Identifier: AGPL-3.0-or-later
import 'capability_descriptor.dart';

/// What a country's law asks the yearly archive of a space to carry, beyond the
/// documents themselves. Data, not behaviour: the host builds the archive and
/// adds the members this declares. The country is the one in the capability id
/// (`archive.FR`).
abstract class ArchiveContribution {
  const ArchiveContribution();

  CapabilityDescriptor get descriptor;

  /// The extra members the archive carries, by id: `fec` (the French
  /// regulatory accounting file), `procedures` (the documentation of the
  /// procedures a Swiss record-keeping ordinance asks for). Empty when the
  /// country asks none.
  Set<String> get archiveMembers => const {};

  /// Whether the archive carries the readable handover: the tables and their
  /// README in English, for countries that prescribe no national audit file.
  bool get readableHandover => false;

  /// The notice the country's law adds about WHERE the records are kept, given
  /// what the installation declared; null when the law asks nothing of the
  /// location (or the declared location satisfies it). Additive: the contract
  /// stays at version 1.
  RecordsNotice? recordsNotice(RecordsFacts facts) => null;
}

/// What the installation declared about where a space's records are kept.
class RecordsFacts {
  const RecordsFacts({
    required this.hostingCountry,
    required this.hostingInEu,
    required this.authorisationReference,
  });

  /// The declared hosting country (ISO 3166-1 alpha-2), null when nothing is
  /// declared.
  final String? hostingCountry;

  /// Whether that country is an EU member state.
  final bool hostingInEu;

  /// The authorisation the space recorded to keep its records elsewhere
  /// (Canada's CRA reference); empty when none.
  final String authorisationReference;
}

/// A country's records-location notice: its id (`cra`, `ao`) and the lines the
/// archive README states, in English, exactly as printed.
class RecordsNotice {
  const RecordsNotice({required this.id, required this.readmeLines});

  final String id;
  final List<String> readmeLines;
}
