// SPDX-License-Identifier: AGPL-3.0-or-later
//
// One offerable export file format and what it claims about itself. Split out
// of `accounting_format.dart` (the registry of formats and targets) so that
// file stays within its length budget; `accounting_format.dart` re-exports it.
import 'accounting_export_sources.dart';

/// What a produced file claims about itself. Never widen one of these
/// without the authority's own spec in hand.
enum FormatClaim { regulatory, exchange, subset }

/// One offerable export.
class AccountingFormat {
  const AccountingFormat({
    required this.id,
    required this.claim,
    required this.extension,
    required this.kind,
    this.sources = SourceRequirements.documents,
    this.needsAccounts = false,
    this.needsLegalId = false,
    this.uncertifiedSoftware = false,
  });

  /// Stable wire id — also the l10n key suffix and the test anchor.
  final String id;

  final FormatClaim claim;

  final String extension;

  /// #3334 -- the writer family the export run dispatches on (switched
  /// exhaustively; the run never names a format id).
  final ExportKind kind;

  /// #3334 -- what the format reads, declared once here: the host reads one
  /// snapshot for the requirements of the format it was asked for.
  final SourceRequirements sources;

  /// The format posts to a chart of accounts DesKilo does not own, so
  /// the export must ASK for the numbers and show them before writing.
  /// Never invent them: every wrong code is unbooked by hand.
  final bool needsAccounts;

  /// The file is named after, or must carry, the company's registration
  /// number — refusing early beats producing a file the authority will
  /// reject on its name alone.
  final bool needsLegalId;

  /// The jurisdiction operates a software CERTIFICATION scheme and
  /// DesKilo is not certified under it.
  ///
  /// Portugal is the case that forced this field. Its spec is public and
  /// the file this app produces is true to it — but Portuguese
  /// taxpayers above the statutory threshold must use *certified*
  /// invoicing software, and a structurally perfect file from
  /// uncertified software does not satisfy that obligation. The file
  /// declares `SoftwareCertificateNumber` 0, which is the defined value
  /// for "not certified", and the export sheet says so out loud.
  ///
  /// Producing the file quietly and letting the owner assume it settles
  /// their obligation would be exactly the overclaim this whole registry
  /// exists to prevent.
  final bool uncertifiedSoftware;
}
