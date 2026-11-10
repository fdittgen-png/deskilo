// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3334 (of #3328) -- what an accounting export format declares about itself:
// the writer family the export run dispatches on and the sources it needs. They
// are fields of [AccountingFormat] (the one list of formats), not a second
// registry: a format's id, claim, extension, flags, family and sources are
// typed in exactly one place. The host reads one consistent snapshot for the
// requirements of the format it was asked for (`AccountingExportSource`).
//
// This is domain code, not a package: what the writers consume (`Invoice`,
// `LedgerEntry`, `BookProfile`, the snapshot) is the money domain itself, which
// is not packaged (ADR 0051).

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

/// The family of writer a format runs through. The export run switches on this
/// (exhaustively, so a new family cannot be forgotten), never on a format id:
/// the id of a format appears only in its registration.
enum ExportKind {
  fec,
  datev,
  sage,
  xeroInvoices,
  swissKmu,
  swissBanana,
  saft,
  saftPortugal,
  accountantCsv,
  archiveBundle,
  gobd,
  frEReporting,
  auditTrail,
  bookReport,
  saftFinancial,
  genericJournal,
  bcJournal,
  sage50CaJournal,
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

  /// Written from the documents: no postings read.
  static const documents = SourceRequirements();

  /// Posted from a local book when the issuer keeps one, unnamed.
  static const postedWhenLocalBook = SourceRequirements(
    posting: ExportPosting.whenLocalBook,
  );

  /// Posted from a local book when the issuer keeps one, naming accounts and
  /// parties.
  static const namedWhenLocalBook = SourceRequirements(
    posting: ExportPosting.whenLocalBook,
    named: true,
  );

  /// The posted journal is the only source, naming accounts and parties.
  static const postedOnlyNamed = SourceRequirements(
    posting: ExportPosting.only,
    named: true,
  );

  /// The posted journal is the only source and the opening balances are read
  /// with it (the SAF-T Financial files).
  static const postedOnlyWithOpening = SourceRequirements(
    posting: ExportPosting.only,
    named: true,
    withOpening: true,
  );

  /// The posted journal is the only source, unnamed.
  static const postedOnly = SourceRequirements(posting: ExportPosting.only);

  /// The year archive: every fiscal year its calendar year overlaps, for a
  /// country whose archive carries the FEC.
  static const archiveYears = SourceRequirements(
    posting: ExportPosting.whenLocalBook,
    named: true,
    archive: true,
  );
}
