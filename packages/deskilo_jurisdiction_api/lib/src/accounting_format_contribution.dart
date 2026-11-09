// SPDX-License-Identifier: AGPL-3.0-or-later
import 'capability_descriptor.dart';

/// One journal of a regulatory journal file: the code the file writes and the
/// label next to it.
class AccountingJournal {
  const AccountingJournal({required this.code, required this.label});

  final String code;
  final String label;
}

/// What a country's accounting export format declares about itself, beyond the
/// file's layout: the country whose chart of accounts its defaults are rows of
/// (`tax_reference` `account_map` rows) and, for a regulatory journal file, the
/// journals it writes. Data, not behaviour: the host's writer reads it. The
/// capability id names the format (`accounting_format.fec`,
/// `accounting_format.datev`).
abstract class AccountingFormatContribution {
  const AccountingFormatContribution();

  CapabilityDescriptor get descriptor;

  /// The format's own id (`fec`, `datev`), the last part of the capability id.
  String get formatId;

  /// The country (ISO 3166-1 alpha-2) whose chart of accounts the format posts
  /// to: the rows of the tax reference the export's default accounts read.
  String get chartCountry;

  /// The journals of a journal file, by role (`sales`, `bank`, `purchases`,
  /// `misc`); empty for a format that carries none.
  Map<String, AccountingJournal> get journals => const {};
}
