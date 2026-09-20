// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1310 S2 — the workspace export describes itself: one ZIP holding the
// workbook, a manifest whose row counts equal the rows actually written,
// and the space's stored files, each with a SHA-256 an operator can check.
// Counting from what went INTO the archive is the point — a manifest that
// counted from somewhere else could agree with a short export.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:deskilo/core/files/xlsx.dart';
import 'package:deskilo/features/workspace/domain/workspace_export_bundle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sheets = [
    XlsxSheet(name: 'Reservations', rows: [
      ['id', 'starts'],
      for (var i = 0; i < 2500; i++) ['r$i', '2026-09-01'],
    ]),
    const XlsxSheet(name: 'Invoices', rows: [
      ['number'],
    ]),
  ];
  final background = Uint8List.fromList(utf8.encode('png bytes'));

  Archive build({int? schema = 226}) => ZipDecoder().decodeBytes(
        buildWorkspaceExportZip(
          workspaceId: 'ws-1',
          schemaVersion: schema,
          createdAt: DateTime.utc(2026, 9, 16, 12),
          sheets: sheets,
          files: [(path: 'level-1', bytes: background)],
        ),
      );

  Map<String, Object?> manifestOf(Archive a) => jsonDecode(
      utf8.decode(a.findFile('manifest.json')!.content as List<int>))
      as Map<String, Object?>;

  test('one ZIP: the workbook, the manifest, the files', () {
    final a = build();
    expect(a.findFile('workspace.xlsx'), isNotNull);
    expect(a.findFile('manifest.json'), isNotNull);
    expect(a.findFile('files/level-1')!.content, background);
  });

  test('the manifest counts the data rows each sheet holds — 2 500, not a '
      'page of 1 000, and never the header', () {
    final m = manifestOf(build());
    expect(m['rows'], {'Reservations': 2500, 'Invoices': 0});
  });

  test('it names its format, the schema, the workspace and the time', () {
    final m = manifestOf(build());
    expect(m['format_version'], workspaceExportFormatVersion);
    expect(m['schema_version'], 226);
    expect(m['workspace_id'], 'ws-1');
    expect(m['created_at'], '2026-09-16T12:00:00.000Z');
  });

  test('an unreadable schema version is recorded as null, not guessed', () {
    expect(manifestOf(build(schema: null))['schema_version'], isNull);
  });

  test('every file carries its size and SHA-256', () {
    final files = manifestOf(build())['files']! as List<Object?>;
    expect(files, [
      {
        'path': 'files/level-1',
        'bytes': background.length,
        // printf 'png bytes' | shasum -a 256
        'sha256':
            'd013614dc14a37ee20fe92005737ab7d3427e7e93580ad56ef8a42205e7f7a4e',
      },
    ]);
  });
}
