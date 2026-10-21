// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1661 — templates as an offline workbook: the inspected settings
// (#1655) of up to [maxTemplates] templates, compared (#1659), in typed
// rows. Configuration only: never members, bookings, invoices or
// credentials — this is not the operational Excel export and never calls
// it. Every cell is data (inline strings or numbers); nothing becomes a
// formula, link or macro.
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../core/files/file_types.dart';
import '../../../core/files/xlsx.dart';
import '../../../core/time/date_text.dart';
import '../domain/template_inspection.dart';
import '../domain/workbook_origin.dart';
import '../domain/workspace_repository.dart';
import 'template_sheets.dart';

export 'template_sheets.dart' show WorkbookLabels;

/// The largest named batch one workbook carries; more is refused, never
/// cut short.
const maxTemplates = 50;

/// The workbook's sheets for [inspections], captured at [capturedAt].
@visibleForTesting
List<XlsxSheet> templateWorkbook(
  List<TemplateInspection> inspections, {
  required DateTime capturedAt,
  WorkbookLabels? labels,
  WorkbookOrigin? origin,
}) {
  final words = labels ?? WorkbookLabels.english();
  if (inspections.isEmpty) throw ArgumentError('no template to export');
  if (inspections.length > maxTemplates) {
    throw ArgumentError('at most $maxTemplates templates per workbook');
  }
  return TemplateSheets(
    inspections,
    capturedAt: capturedAt,
    words: words,
    origin: origin,
  ).sheets();
}

/// The file name: no template name, no person, just the date.
@visibleForTesting
String templateWorkbookName(DateTime capturedAt) {
  final d = capturedAt.toUtc();
  return 'deskilo-templates-${ymd(d)}.xlsx';
}

/// #1661 — where an export stands: reading template [done] of [total],
/// building the workbook, or waiting on the save dialog. No ETA: only
/// what has actually happened.
enum WorkbookStage { reading, building, saving }

class WorkbookProgress {
  const WorkbookProgress(this.stage, this.done, this.total);
  final WorkbookStage stage;
  final int done;
  final int total;
}

/// Asked between steps. Once the save dialog is open the export can no
/// longer be cancelled from here; the dialog's own cancel answers.
class WorkbookCancel {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// Thrown when [WorkbookCancel] was asked before the save: nothing was
/// saved, and nothing is left behind.
class WorkbookCancelled implements Exception {
  const WorkbookCancelled();
}

/// Reads each template's inspection and saves the workbook.
class TemplateWorkbookExport {
  const TemplateWorkbookExport(this._workspaces, this._save,
      {required this.origin, this.isCurrent});
  final WorkspaceRepository _workspaces;
  final FileSaver _save;
  final WorkbookOriginRepository origin;
  final bool Function()? isCurrent;

  /// The saved location, or null when the person cancelled the save
  /// dialog. Throws [WorkbookCancelled] when [cancel] was asked first.
  Future<String?> export(
    List<String> templateIds, {
    required DateTime now,
    WorkbookLabels? labels,
    void Function(WorkbookProgress progress)? onProgress,
    WorkbookCancel? cancel,
  }) async {
    final ids = List<String>.unmodifiable(templateIds);
    if (ids.isEmpty || ids.toSet().length != ids.length || ids.length > maxTemplates) {
      throw ArgumentError('at most $maxTemplates templates per workbook');
    }
    void check() {
      if (cancel?.isCancelled ?? false) throw const WorkbookCancelled();
      if (!(isCurrent?.call() ?? true)) throw StateError('workbook_source_changed');
    }
    check();
    final capturedOrigin = await origin.read();
    check();
    final total = ids.length;
    final inspections = <TemplateInspection>[];
    for (final id in ids) {
      check();
      onProgress?.call(
        WorkbookProgress(WorkbookStage.reading, inspections.length, total),
      );
      final inspection = await _workspaces.inspectWorkspaceTemplate(id);
      check();
      if (inspection.templateId != id || !inspection.usable) {
        throw StateError('workbook_inspection_changed');
      }
      inspections.add(inspection);
    }
    if (!capturedOrigin.sameContext(await origin.read())) throw StateError('workbook_source_changed');
    check();
    onProgress?.call(WorkbookProgress(WorkbookStage.building, total, total));
    final Uint8List bytes = buildXlsx(
      templateWorkbook(inspections, capturedAt: now, labels: labels, origin: capturedOrigin),
    );
    check();
    onProgress?.call(WorkbookProgress(WorkbookStage.saving, total, total));
    check();
    return _save(bytes: bytes, fileName: templateWorkbookName(now));
  }
}
