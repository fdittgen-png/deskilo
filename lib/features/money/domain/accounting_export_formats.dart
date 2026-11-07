// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3334 (of #3328) -- the export formats this build offers, read from the ONE
// list: the file formats of [accountingTargets]. A format declares its writer
// family and its sources where it is defined (`AccountingFormat.kind`,
// `.sources`); there is no second registry to keep equal, and no format id is
// typed twice. Nothing is generated for SQL or TS: neither holds a list of
// export format ids (`book_exports.format_id` is free text).
import 'package:meta/meta.dart';

import 'accounting_export_sources.dart';
import 'accounting_format.dart';

/// Every export format, once, in the order the targets registry lists them.
@visibleForTesting
final List<AccountingFormat> exportFormats = () {
  final seen = <String>{};
  return [
    for (final t in accountingTargets)
      if (t.format case final f? when seen.add(f.id)) f,
  ];
}();

/// The format registered under [formatId], or null for an id nobody offers.
@visibleForTesting
AccountingFormat? exportFormatOf(String formatId) {
  for (final f in exportFormats) {
    if (f.id == formatId) return f;
  }
  return null;
}

/// What [formatId] reads; a format nobody offers reads the documents only.
SourceRequirements sourcesOf(String formatId) =>
    exportFormatOf(formatId)?.sources ?? SourceRequirements.documents;
