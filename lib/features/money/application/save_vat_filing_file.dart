// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2357 — "save the filing file of this return": the UStVA as ELSTER XML
// (Germany), the CA3 as an EDI-TVA interchange (France), written from the
// form boxes and saved where the device keeps downloads. Nothing is
// transmitted; the owner hands the file to the channel that files it.
import 'dart:convert' show utf8;

import '../../../core/files/file_saver.dart';
import '../domain/vat_declaration.dart';
import '../domain/vat_filing_files.dart';

class SaveVatFilingFile {
  const SaveVatFilingFile(this._save, this._now, {required this.party});

  final FileSaver _save;
  final DateTime Function() _now;

  /// The space that files, or null before it is loaded.
  final VatFilingParty? party;

  /// The country whose file this space can save, else null.
  String? get country => party?.fileCountry;

  /// Writes and saves the file; answers where it landed. Throws
  /// [VatFilingFileException] when the period or [taxNumber] does not fit.
  Future<String?> call(VatDeclaration declaration, {String taxNumber = ''}) {
    final party = this.party;
    if (party == null) throw StateError('no workspace loaded');
    final file = vatFilingFile(
      declaration: declaration,
      party: party,
      now: _now(),
      taxNumber: taxNumber,
    );
    return _save(bytes: utf8.encode(file.text), fileName: file.fileName);
  }
}
