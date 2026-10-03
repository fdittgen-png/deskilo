// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1866 — the Word document as a workbench output (#1872).
//
// The same builder the review screen uses, behind the workbench's
// generator contract: pure over the request (recording, language,
// reviewed storyboard, theme), no network and no workspace read. A
// storyboard reviewed for another revision of the recording is refused
// as stale rather than silently ignored; without a storyboard the
// document is text-only. A person's notes stay out, as they do by
// default everywhere.
import 'dart:ui';

import '../../../app/theme.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../l10n/app_localizations.dart';
import '../package/task_output.dart';
import '../storyboard/storyboard_pictures.dart';
import 'docx_export.dart';
import 'task_document.dart';

/// The app localizations for [code], English when the code is not one of
/// the app's languages.
AppLocalizations outputLocalizations(String code) {
  final supported = AppLocalizations.supportedLocales.any(
    (l) => l.languageCode == code,
  );
  return lookupAppLocalizations(Locale(supported ? code : 'en'));
}

/// Generates the `.docx` of a recording.
class DocxOutputGenerator implements TaskOutputGenerator {
  const DocxOutputGenerator();

  @override
  String get id => 'docx';

  @override
  TaskOutputKind get kind => TaskOutputKind.document;

  @override
  String get fileExtension => 'docx';

  @override
  Future<TaskOutputAvailability> availability() async =>
      const TaskOutputAvailable();

  @override
  Future<TaskOutputResult> generate(
    TaskOutputRequest request, {
    void Function(double fraction)? onProgress,
    TaskOutputCancel? cancel,
  }) async {
    final l = outputLocalizations(request.languageCode);
    final recording = request.recording;
    final storyboard = request.storyboard;
    if (storyboard != null &&
        storyboard.sourceRevision != recordingRevision(recording)) {
      return const TaskOutputNotProduced(TaskOutputReason.stale);
    }
    if (cancel?.isCancelled ?? false) return const TaskOutputCancelled();
    final pictures = storyboard == null
        ? null
        : await renderApprovedPictures(
            storyboard,
            colors:
                (request.brightness == Brightness.dark
                        ? DeskiloTheme.dark(animations: false)
                        : DeskiloTheme.light(animations: false))
                    .colorScheme,
            provenance: l.taskExportSceneProvenance,
          );
    if (cancel?.isCancelled ?? false) return const TaskOutputCancelled();
    try {
      final bytes = exportDocx(recording, l, illustrations: pictures);
      onProgress?.call(1);
      return TaskOutputProduced(bytes, docxFileName(recording));
    } on TaskExportException catch (e, st) {
      TraceLogger.instance.warn(
        'recorder',
        'document output refused',
        error: e,
        stackTrace: st,
      );
      return TaskOutputNotProduced(
        e.refusal == TaskExportRefusal.stale
            ? TaskOutputReason.stale
            : TaskOutputReason.refused,
      );
    }
  }
}
