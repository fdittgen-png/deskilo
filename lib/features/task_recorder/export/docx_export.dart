// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1866 — the one Word export entry point.
//
// The review screen (and, through #1872, a recording file opened on a
// device with no account) calls [TaskDocxExporter.save]. It builds the
// document from the frozen recording, hands the bytes to the local
// FileSaver and reports what really happened: saved (with the handle the
// saver returned), refused (empty, too large, not a recording) or failed
// (the save did not happen). The recording itself is never written, so
// a refused or failed export leaves the source exactly as it was. No
// network, account or business command is involved.
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/files/file_names.dart';
import '../../../core/files/file_saver.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/task_recording.dart';
import '../domain/task_recording_codec.dart';
import 'docx/docx_writer.dart';
import 'task_document.dart';

part 'docx_export.g.dart';

/// The `.docx` bytes for [recording] in the language of [l]. Throws
/// [TaskExportException] when the recording cannot become a document.
Uint8List exportDocx(
  TaskRecording recording,
  AppLocalizations l, {
  TaskDocumentOptions options = const TaskDocumentOptions(),
  RecordingLimits limits = const RecordingLimits(),
}) {
  final doc = buildTaskDocument(recording, l, options: options, limits: limits);
  try {
    return buildDocx(doc);
  } on DocxException catch (e, st) {
    TraceLogger.instance.warn(
      'recorder',
      'task export refused',
      error: e,
      stackTrace: st,
    );
    throw const TaskExportException(TaskExportRefusal.tooLarge);
  }
}

/// The file name of [recording]'s document: a slug of its title and its
/// content revision, never an id.
String docxFileName(TaskRecording recording) {
  final title = recording.title?.trim() ?? '';
  final stem = title.isEmpty ? 'task' : safeFileSlug(title);
  final short = stem.length > 40 ? stem.substring(0, 40) : stem;
  return 'procedure-$short-${recordingRevision(recording)}.docx';
}

/// What an export produced.
sealed class TaskDocxResult {
  const TaskDocxResult();
}

/// Written by the saver; [handle] is what it returned.
class TaskDocxSaved extends TaskDocxResult {
  const TaskDocxSaved(this.handle, this.fileName);

  final String handle;
  final String fileName;
}

/// Not exported, and why.
class TaskDocxRefused extends TaskDocxResult {
  const TaskDocxRefused(this.refusal);

  final TaskExportRefusal refusal;
}

/// Built, but the save did not happen (cancelled, refused, failed).
class TaskDocxSaveFailed extends TaskDocxResult {
  const TaskDocxSaveFailed();
}

/// Exports recordings as Word documents through the local file saver.
class TaskDocxExporter {
  const TaskDocxExporter(this._save);

  final FileSaver _save;

  /// Exports [recording] and saves it.
  Future<TaskDocxResult> save(
    TaskRecording recording,
    AppLocalizations l, {
    TaskDocumentOptions options = const TaskDocumentOptions(),
  }) async {
    final Uint8List bytes;
    try {
      bytes = exportDocx(recording, l, options: options);
    } on TaskExportException catch (e, st) {
      TraceLogger.instance.warn(
        'recorder',
        'task export refused',
        error: e,
        stackTrace: st,
      );
      return TaskDocxRefused(e.refusal);
    }
    final name = docxFileName(recording);
    try {
      final handle = await _save(bytes: bytes, fileName: name);
      return handle == null
          ? const TaskDocxSaveFailed()
          : TaskDocxSaved(handle, name);
    } catch (e, st) {
      TraceLogger.instance.warn(
        'recorder',
        'task export save failed',
        error: e,
        stackTrace: st,
      );
      return const TaskDocxSaveFailed();
    }
  }

  /// Exports a recording FILE (an import): it goes through the one codec
  /// first, and a file the codec refuses is refused here too.
  Future<TaskDocxResult> saveFromText(
    String text,
    AppLocalizations l, {
    TaskDocumentOptions options = const TaskDocumentOptions(),
  }) {
    final decoded = decodeRecordingText(text);
    final recording = decoded.recording;
    if (recording == null) {
      return Future.value(const TaskDocxRefused(TaskExportRefusal.rejected));
    }
    return save(recording, l, options: options);
  }
}

/// The Word exporter, over the app's local file saver.
@riverpod
TaskDocxExporter taskDocxExporter(Ref ref) =>
    TaskDocxExporter(ref.watch(fileSaverProvider));
