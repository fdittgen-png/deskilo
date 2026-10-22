// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

import '../../../core/files/xlsx.dart';
import '../../../core/i18n/currencies.dart';
import '../../../core/time/workspace_time.dart';

/// #1310 S2 — the workspace export describes itself.
///
/// The Excel workbook (#395) was the whole export: a file that says what
/// it holds only to somebody who opens every tab and counts. An operator
/// restoring from it, or an auditor asked "is this all of it", had no way
/// to tell a complete export from a short one — and #1406 showed exports
/// had been short, silently, whenever a table outgrew one API page.
///
/// So the export is one ZIP:
///
///   * `workspace.xlsx` — the workbook, unchanged;
///   * `manifest.json` — what the file claims about itself: its format,
///     the schema version of the server it came from (#1312), the
///     workspace, when, how many rows each sheet holds, and every stored
///     file with its size and SHA-256;
///   * `files/<path>` — the workspace's own files from storage (plan
///     backgrounds, plan images, the report-image library), under the
///     path they have in the bucket minus the workspace prefix.
///
/// Pure Dart: no Flutter, no Supabase. The caller fetches, this packs.
@visibleForTesting
const int workspaceExportFormatVersion = 1;

/// One stored file of the workspace, as it will sit under `files/`.
typedef ExportedFile = ({String path, Uint8List bytes});

/// What `manifest.json` says, built from exactly what goes in the ZIP.
Map<String, Object?> _workspaceExportManifest({
  required String workspaceId,
  required int? schemaVersion,
  required DateTime createdAt,
  required List<XlsxSheet> sheets,
  required List<ExportedFile> files,
}) =>
    {
      'format_version': workspaceExportFormatVersion,
      'schema_version': schemaVersion,
      'workspace_id': workspaceId,
      'created_at': createdAt.toUtc().toIso8601String(),
      'rows': {
        for (final sheet in sheets) sheet.name: _dataRows(sheet),
      },
      'files': [
        for (final f in files)
          {
            'path': 'files/${f.path}',
            'bytes': f.bytes.length,
            'sha256': sha256.convert(f.bytes).toString(),
          },
      ],
    };

/// The header row is not a row of data.
int _dataRows(XlsxSheet sheet) => sheet.rows.isEmpty ? 0 : sheet.rows.length - 1;

/// #1636 — what a completed export leaves as recovery evidence: the
/// SHA-256 of the saved ZIP and the data rows its manifest counts.
typedef WorkspaceExportEvidence = ({String sha256, int rowCount});

/// The evidence for [zip], built from [sheets] by the manifest's own rule.
WorkspaceExportEvidence workspaceExportEvidence({
  required Uint8List zip,
  required List<XlsxSheet> sheets,
}) =>
    (
      sha256: sha256.convert(zip).toString(),
      rowCount: sheets.fold(0, (sum, sheet) => sum + _dataRows(sheet)),
    );

/// The export ZIP's bytes.
Uint8List buildWorkspaceExportZip({
  required String workspaceId,
  required int? schemaVersion,
  required DateTime createdAt,
  required List<XlsxSheet> sheets,
  List<ExportedFile> files = const [],
}) {
  final archive = Archive();
  void add(String path, List<int> bytes) =>
      archive.addFile(ArchiveFile(path, bytes.length, bytes));

  add('workspace.xlsx', buildXlsx(sheets));
  final manifest = _workspaceExportManifest(
    workspaceId: workspaceId,
    schemaVersion: schemaVersion,
    createdAt: createdAt,
    sheets: sheets,
    files: files,
  );
  add('manifest.json',
      utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest)));
  for (final f in files) {
    add('files/${f.path}', f.bytes);
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// The workspace's own files in storage — plan backgrounds, plan images,
/// the report-image library — everything under `<workspace id>/` of the
/// `floor-plans` bucket.
///
/// Avatars are not here: a photo belongs to a person's profile, which is
/// global across workspaces, and leaves with that person's subject-access
/// export rather than with a space.
/// #2860 — one table of the export: its columns in schema order and its
/// rows, as `export_workspace_records` (0540) answers them.
typedef ExportedTable = ({
  String table,
  List<String> columns,
  List<List<Object?>> rows,
});

/// The tables of [json] (0540's answer), in the server's order.
List<ExportedTable> exportedTablesFromJson(Object? json) => [
  for (final t in json is List ? json : const <Object?>[])
    if (t is Map)
      (
        table: '${t['table']}',
        columns: [for (final c in t['columns'] as List? ?? const []) '$c'],
        rows: [
          for (final r in t['rows'] as List? ?? const [])
            [for (final v in r as List) v],
        ],
      ),
];

/// One sheet per exported table: the column names, then the rows. A nested
/// value (a jsonb object or list) is written as its JSON text; #2861 — a
/// timestamp as a real date at the workspace's wall-clock time, a day as a
/// date, and a `*_cents` column as an amount in [currencyCode].
List<XlsxSheet> exportedTableSheets(
  List<ExportedTable> tables, {
  required String currencyCode,
}) => [
  for (final t in tables)
    XlsxSheet(name: t.table, rows: [
      t.columns,
      for (final r in t.rows)
        [
          for (final (i, v) in r.indexed)
            _recordCell(
              i < t.columns.length ? t.columns[i] : '',
              v,
              currencyCode,
            ),
        ],
    ]),
];

final _instant = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}');
final _day = RegExp(r'^\d{4}-\d{2}-\d{2}$');

Object? _recordCell(String column, Object? value, String currencyCode) =>
    switch (value) {
      final Map<Object?, Object?> _ || final List<Object?> _ => jsonEncode(value),
      final int cents when column.endsWith('_cents') =>
        XlsxAmount(cents / Currencies.minorPerMajor(currencyCode)),
      final String text when _instant.hasMatch(text) =>
        switch (DateTime.tryParse(text)) {
          final instant? => WorkspaceTime.wall(instant),
          null => text,
        },
      final String text when _day.hasMatch(text) =>
        switch (DateTime.tryParse(text)) {
          final day? => XlsxDate(day),
          null => text,
        },
      _ => value,
    };

abstract interface class WorkspaceFilesRepository {
  /// Every file path under the workspace's prefix, relative to it,
  /// sorted. Folders are walked, never returned.
  Future<List<String>> listFiles(String workspaceId);

  /// The file at [path] (relative to the workspace prefix).
  Future<Uint8List> download(String workspaceId, String path);

  /// #1636 — records a COMPLETED export as the workspace's recovery
  /// evidence (record_workspace_export, 0301). Called only once the file
  /// was saved; a failed or cancelled export records nothing.
  Future<void> recordExport(
    String workspaceId, {
    required String sha256,
    required int rowCount,
  });

  /// #2860 — every row of the tables the app has no model of: the
  /// configuration, the purchase, lease, asset and accounting side and the
  /// member-account records (`export_workspace_records`, 0540).
  Future<List<ExportedTable>> fetchRecords(String workspaceId);
}
