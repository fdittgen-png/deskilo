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
}
