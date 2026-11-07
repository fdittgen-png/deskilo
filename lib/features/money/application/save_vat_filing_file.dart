// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2357 — "save the filing file of this return": the UStVA as ELSTER XML
// (Germany), the CA3 as an EDI-TVA interchange (France), written from the
// form boxes and saved where the device keeps downloads. Nothing is
// transmitted; the owner hands the file to the channel that files it.
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

import '../../../core/files/file_saver.dart';
import '../../../core/jurisdiction/jurisdiction_resolver.dart';
import '../domain/vat_declaration.dart';
import '../domain/vat_filing_files.dart';
import 'jurisdiction/filing_context_builder.dart';
import 'jurisdiction/installed_vat_filings.dart';

class SaveVatFilingFile {
  SaveVatFilingFile(
    this._save,
    this._now, {
    required this.party,
    List<VatFilingContribution>? installed,
  }) : _installed = installed ?? installedVatFilings;

  final List<VatFilingContribution> _installed;

  final FileSaver _save;
  final DateTime Function() _now;

  /// The space that files, or null before it is loaded.
  final VatFilingParty? party;

  /// The country whose file this space can save, else null: the add-on the
  /// resolver chooses for the space's country (never a fallback country).
  String? get country {
    final party = this.party;
    if (party == null) return null;
    return switch (_resolve(party)) {
      Resolved(:final country) => country,
      Refused() => null,
    };
  }

  CapabilityResolution _resolve(VatFilingParty party) => resolveCapability(
    JurisdictionOperation.vatFiling,
    LegalContext(countryCode: party.countryCode),
    _installed,
  );

  /// Writes and saves the file; answers where it landed. Throws
  /// [VatFilingFileException] when the period or one of [facts] does not fit.
  Future<String?> call(
    VatDeclaration declaration, {
    VatFilingFacts facts = const VatFilingFacts(),
  }) {
    final party = this.party;
    if (party == null) throw StateError('no workspace loaded');
    final resolution = _resolve(party);
    if (resolution is! Resolved) {
      throw UnsupportedError('no filing file for ${party.countryCode}');
    }
    final contribution = resolution.contribution;
    final checked = contribution.validate(
      filingContextOf(
        declaration: declaration,
        party: party,
        now: _now(),
        facts: facts,
      ),
    );
    final filing = checked.filing;
    if (filing == null) {
      // A code this host does not know is a contract fault, not a problem the
      // person can fix: it takes the generic failure path (with its trace).
      final problem =
          VatFilingFileProblem.values.asNameMap()[checked.result.codes.firstOrNull];
      if (problem == null) {
        throw StateError(
          'the add-on refused with codes ${checked.result.codes}',
        );
      }
      throw VatFilingFileException(problem);
    }
    final artifact = contribution.build(filing);
    return _save(
      bytes: artifact.bytes,
      fileName: artifact.fileName,
    );
  }
}
