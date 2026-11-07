// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3334 (of #3328) -- an accounting export format as a registered
// contribution: its stable format id (the wire id, the l10n key suffix, the
// test anchor) and the sources it DECLARES it needs. The host reads one
// consistent snapshot for the requirements of the format it was asked for
// (`AccountingExportSource`); no format-id set lives anywhere else.
//
// The contribution lives in the application layer, not in a package: what the
// writers consume (`Invoice`, `LedgerEntry`, `BookProfile`, the snapshot) is
// the money domain itself, which is not packaged (ADR 0051).

/// Where a format's postings come from.
enum ExportPosting {
  /// Written from the documents: no postings read.
  none,

  /// Written from the posting engine when the issuer keeps a local book, from
  /// the documents otherwise.
  whenLocalBook,

  /// Written from the posting engine only: the posted journal has no other
  /// source.
  only,
}

/// What an export format reads, declared once by the format.
class SourceRequirements {
  const SourceRequirements({
    this.posting = ExportPosting.none,
    this.named = false,
    this.withOpening = false,
    this.archive = false,
  });

  /// Where the postings come from.
  final ExportPosting posting;

  /// The postings name the accounts and the parties (the FEC, the books
  /// printed from the postings, the Swiss journal, DATEV's Kreditor, Sage 50's
  /// customer or supplier).
  final bool named;

  /// The accounts' opening balances are stated, so the book's postings before
  /// the year are read with it (the SAF-T Financial files).
  final bool withOpening;

  /// The format is the year archive: it reads the posted journal of every
  /// fiscal year its calendar year overlaps, and only for a country whose
  /// archive carries the FEC.
  final bool archive;
}

/// One export format, registered with the sources it declares.
class AccountingExportContribution {
  const AccountingExportContribution(this.formatId, this.requirements);

  /// The format's stable id (`fec`, `datev`, `sage50`, ...): unchanged by the
  /// registry.
  final String formatId;

  final SourceRequirements requirements;
}
