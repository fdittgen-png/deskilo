// SPDX-License-Identifier: 0BSD
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import '../../../core/files/xlsx.dart';

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
const int workspaceExportFormatVersion = 1;

/// One stored file of the workspace, as it will sit under `files/`.
typedef ExportedFile = ({String path, Uint8List bytes});

/// What `manifest.json` says, built from exactly what goes in the ZIP.
Map<String, Object?> workspaceExportManifest({
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
      // The header row is not a row of data.
      'rows': {
        for (final sheet in sheets)
          sheet.name: sheet.rows.isEmpty ? 0 : sheet.rows.length - 1,
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
  final manifest = workspaceExportManifest(
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
abstract interface class WorkspaceFilesRepository {
  /// Every file path under the workspace's prefix, relative to it,
  /// sorted. Folders are walked, never returned.
  Future<List<String>> listFiles(String workspaceId);

  /// The file at [path] (relative to the workspace prefix).
  Future<Uint8List> download(String workspaceId, String path);
}
