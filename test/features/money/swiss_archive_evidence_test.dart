// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2377 — what the record-keeping ordinance (GeBüV) asks the interface to
// evidence, on the archive and the audit trail:
//   * art. 3/9 — the archive's manifest names every member with its
//     SHA-256; the archive's own digest is logged with the server's time
//     and the person who made it, so the manifest verifies against the log
//     and an altered member, an added one or a changed archive is found;
//   * art. 8 — the audit trail lists every file handed out, the archive
//     download among them, with its actor and time;
//   * art. 4 — a Swiss archive carries the procedures document, in the
//     exporter's language, with the country's ten-year clock; no other
//     country's does.
// Expectations by hand.
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:deskilo/core/demo/data/book_period_repository.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/application/book_period_commands.dart';
import 'package:deskilo/features/money/domain/archive_bundle.dart';
import 'package:deskilo/features/money/domain/audit_trail.dart';
import 'package:deskilo/features/money/domain/number_sequence.dart';
import 'package:deskilo/features/money/presentation/swiss_procedure_document.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

final _members = <String, List<int>>{
  'register.csv': textBytes('number;integrity\r\nINV-101;verified\r\n'),
  'audit-trail.csv': textBytes('# DesKilo audit trail\n'),
  'invoices/INV-101.pdf': [37, 80, 68, 70],
};

/// The manifest's rows of [zip] that do not match its members, and the
/// members it does not name: empty when the manifest verifies.
List<String> _unverified(List<int> zip) {
  final archive = ZipDecoder().decodeBytes(zip);
  final files = {
    for (final f in archive.files)
      if (f.isFile) f.name: f.content,
  };
  final rows = const LineSplitter()
      .convert(utf8.decode(files[archiveManifestName]!))
      .skip(1);
  final named = <String>{};
  final out = <String>[];
  for (final row in rows) {
    final [path, digest, size] = row.split(';');
    named.add(path);
    final bytes = files[path];
    if (bytes == null ||
        sha256.convert(bytes).toString() != digest ||
        '${bytes.length}' != size) {
      out.add(path);
    }
  }
  for (final path in files.keys) {
    if (path != archiveManifestName && !named.contains(path)) out.add(path);
  }
  return out;
}

List<int> _rezip(Map<String, List<int>> files) => zipBundle(files);

void main() {
  setUpAll(initializeDateFormatting);

  test('the manifest names every member with its digest and size', () {
    final files = withManifest(_members);
    final manifest = utf8.decode(files[archiveManifestName]!);
    expect(manifest.split('\r\n').first, 'path;sha256;bytes');
    expect(
      manifest
          .split('\r\n')
          .skip(1)
          .where((l) => l.isNotEmpty)
          .map((l) => l.split(';').first),
      ['audit-trail.csv', 'invoices/INV-101.pdf', 'register.csv'],
    );
    expect(
      manifest,
      contains(
        'invoices/INV-101.pdf;'
        '${sha256.convert(_members['invoices/INV-101.pdf']!)};4',
      ),
    );
  });

  test('the archive verifies against the export log; an altered, added or '
      'changed one does not', () async {
    final log = FakeBookPeriodRepository(
      today: DateTime(2027, 1, 5, 9),
      actorMemberId: 'm-owner',
    );
    final zip = zipBundle(withManifest(_members));
    await BookPeriodCommands(log).logExportBytes(
      'ws',
      formatId: 'bundle',
      year: 2026,
      bytes: zip,
      rows: _members.length,
      documents: 1,
    );
    final logged = (await BookPeriodCommands(log).exportLog('ws', 2026)).single;
    expect(logged.sha256, sha256.convert(zip).toString());
    expect(logged.exportedByMemberId, 'm-owner');
    expect(_unverified(zip), isEmpty);

    // A member altered after the download: the manifest finds it, and the
    // archive no longer has the logged digest.
    final files = withManifest(_members);
    final altered = _rezip({
      ...files,
      'register.csv': textBytes('number;integrity\r\nINV-101;altered\r\n'),
    });
    expect(_unverified(altered), ['register.csv']);
    expect(sha256.convert(altered).toString(), isNot(logged.sha256));
    expect(
      _unverified(
        _rezip({
          ...files,
          'extra.txt': [1],
        }),
      ),
      ['extra.txt'],
    );
  });

  test('the audit trail lists every file handed out, the archive download '
      'among them, with who made it and when', () async {
    final log = FakeBookPeriodRepository(
      today: DateTime.utc(2027, 1, 5, 9, 7),
      actorMemberId: 'm-owner',
    );
    final commands = BookPeriodCommands(log);
    await commands.logExport(
      'ws',
      formatId: 'ch_kmu',
      year: 2026,
      content: 'Datum;Beleg\r\n',
      documents: 3,
    );
    await commands.logExportBytes(
      'ws',
      formatId: 'bundle',
      year: 2026,
      bytes: [1, 2, 3],
      rows: 3,
      documents: 3,
    );
    final events = buildAuditEvents(
      invoices: const [],
      matches: const {},
      exports: await commands.exportLog('ws', 2026),
      memberNames: const {'m-owner': 'Flo Owner'},
    );
    expect(
      [for (final e in events) (e.kind, e.reference, e.actor, e.at)],
      [
        ('export', 'ch_kmu', 'Flo Owner', DateTime.utc(2027, 1, 5, 9, 7)),
        ('archive', 'bundle', 'Flo Owner', DateTime.utc(2027, 1, 5, 9, 7)),
      ],
    );
    expect(events.last.description, 'sha256 ${sha256.convert([1, 2, 3])}');
    final csv = buildAuditTrailCsv(
      events: events,
      generatedAt: DateTime.utc(2027, 1, 6),
      workspaceName: 'Cowork Lausanne SA',
    );
    expect(csv, contains('archive'));
    expect(csv, contains('Flo Owner'));
    expect(
      await commands.exportLog('ws', 2025),
      isEmpty,
      reason: 'a file of 2026 is not an access to the books of 2025',
    );
  });

  test('a Swiss archive carries the procedures document in the exporter\'s '
      'language, with its ten-year clock; no other country\'s does', () {
    expect(archiveCarriesProcedures('CH'), isTrue);
    expect(archiveCarriesProcedures('ch'), isTrue);
    expect(archiveCarriesProcedures('DE'), isFalse);
    expect(archiveCarriesProcedures('FR'), isFalse);
    for (final (locale, heading) in [
      ('de', 'Integrität (Art. 3 und 9)'),
      ('fr', 'Intégrité (art. 3 et 9)'),
      ('it', 'Integrità (art. 3 e 9)'),
    ]) {
      final l10n = lookupAppLocalizations(Locale(locale));
      final doc = buildSwissProcedureDocument(l10n, (
        workspace: 'Cowork Lausanne SA',
        country: 'CH',
        reference: ActiveTaxReference.current,
        from: DateTime(2026),
        to: DateTime(2026, 12, 31),
        generatedAt: DateTime(2027, 1, 5),
        fiscalYearStart: null,
        serverSchema: 9999,
        sequences: [NumberSequence.defaultsFor('invoice')],
      ));
      expect(
        doc,
        startsWith('# ${l10n.gebuevProcedureTitle('Cowork Lausanne SA')}'),
      );
      expect(doc, contains('## $heading'));
      expect(doc, contains('## ${l10n.gebuevProcedureAccessHeading}'));
      expect(doc, contains('## ${l10n.gebuevProcedureCarriersHeading}'));
      expect(doc, contains(l10n.gebuevProcedureSystemBody));
      expect(doc, contains('## ${l10n.retentionTitle}'));
      // A document of 31 December 2026 kept ten years from the year's end.
      expect(doc, contains('2036'), reason: locale);
    }
  });
}
