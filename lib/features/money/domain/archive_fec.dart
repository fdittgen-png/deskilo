// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The FEC of the year archive. A closed fiscal year's FEC is FINAL: it is
// written once, its sha256 logged with the export log (`book_exports`),
// and an archive made later must carry the same bytes, or it is not made.
// A year not yet closed travels as PROVISIONAL, under a name that says so,
// and is never logged as final. Neither status is written inside the FEC:
// its first record stays the field-name header, and the qualification
// lives in the manifest beside it, with the import-contract result and the
// scope of what DesKilo posts.
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/time/date_text.dart';
import 'book_period.dart';
import 'fec_import_contract.dart';
import 'fiscal_year.dart';

/// The format id a final FEC is logged under.
const String archiveFecFormatId = 'fec';

/// The archive member that qualifies its FECs.
const String _manifestName = 'fec-manifest.txt';

/// What the archive does with its FEC.
sealed class ArchiveFecPlan {
  const ArchiveFecPlan();
}

/// The members to add, and whether the FEC is logged now as final.
final class ArchiveFecWrite extends ArchiveFecPlan {
  const ArchiveFecWrite(
    this.members, {
    required this.sha256,
    required this.logNow,
  });
  final Map<String, List<int>> members;
  final String sha256;

  /// A final FEC no earlier export logged: log it with this archive.
  final bool logNow;
}

/// The closed year's FEC differs from the one [logged] recorded: the
/// books of a closed year changed, and no archive is made over them.
final class ArchiveFecChanged extends ArchiveFecPlan {
  const ArchiveFecChanged(this.logged);
  final BookExport logged;
}

/// The archive's FEC [fec], named [fileName] (`<SIREN>FEC<closing>.txt`),
/// for [year], [closed] or not, against the export log [exports], with
/// its import-contract [contract] quoted in the manifest.
ArchiveFecPlan archiveFecPlan({
  required String fec,
  required String fileName,
  required FiscalYear year,
  required bool closed,
  required List<BookExport> exports,
  required FecContractReport contract,
}) {
  final bytes = utf8.encode(fec);
  final digest = sha256.convert(bytes).toString();
  final logged = closed ? _loggedFinal(exports, year) : null;
  if (logged != null && logged.sha256 != digest) {
    return ArchiveFecChanged(logged);
  }
  final name = closed ? fileName : 'PROVISOIRE-$fileName';
  return ArchiveFecWrite(
    {
      name: bytes,
      _manifestName: utf8.encode(
        _manifest(
          name: name,
          year: year,
          closed: closed,
          sha256: digest,
          logged: logged,
          contract: contract,
        ),
      ),
    },
    sha256: digest,
    logNow: closed && logged == null,
  );
}

/// The archive members of [writes], one per fiscal year, oldest first:
/// every FEC under its own name, and one manifest that qualifies each of
/// them in the same order, a blank line between two years.
Map<String, List<int>> archiveFecMembers(List<ArchiveFecWrite> writes) {
  final members = <String, List<int>>{};
  final manifests = <List<int>>[];
  for (final write in writes) {
    for (final MapEntry(:key, :value) in write.members.entries) {
      if (key == _manifestName) {
        manifests.add(value);
      } else {
        members[key] = value;
      }
    }
  }
  if (manifests.isEmpty) return members;
  return {
    ...members,
    _manifestName: [
      for (var i = 0; i < manifests.length; i++) ...[
        if (i > 0) ...utf8.encode('\r\n'),
        ...manifests[i],
      ],
    ],
  };
}

/// The earliest final FEC logged for exactly [year].
BookExport? _loggedFinal(List<BookExport> exports, FiscalYear year) {
  final finals = [
    for (final e in exports)
      if (e.formatId == archiveFecFormatId &&
          e.closedPeriod &&
          FiscalYear(e.from, e.to) == year)
        e,
  ]..sort((a, b) => a.exportedAt.compareTo(b.exportedAt));
  return finals.firstOrNull;
}

String _manifest({
  required String name,
  required FiscalYear year,
  required bool closed,
  required String sha256,
  required BookExport? logged,
  required FecContractReport contract,
}) => [
  'file: $name',
  'fiscal_year: ${isoDay(year.from)}..${isoDay(year.to)}',
  'status: ${closed ? 'final' : 'provisional'}',
  'sha256: $sha256',
  if (logged != null) 'logged: ${isoDay(logged.exportedAt)}',
  'import_contract: ${contract.passed ? 'passed' : 'failed (${contract.failedRules.map((r) => r.name).join(', ')})'}, '
      '${contract.records} records',
  'scope: the entries DesKilo posts for this issuer; the company FEC also '
      'needs every entry kept in other books',
  '',
].join('\r\n');
