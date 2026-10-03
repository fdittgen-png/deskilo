// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1872 — saving a recording, its package or a generated output, and
// saying truthfully what the save achieved. Shared by the review screen
// and the workbench, so both name a saved file, a private copy, a
// browser request and a failure the same way.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files/file_saver.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/task_recording.dart';
import '../domain/task_recording_codec.dart';
import '../package/storyboard_review.dart';
import '../package/task_package.dart';
import 'recorder_labels.dart';

/// The bytes of [recording] as plain JSON or as a package; null when the
/// validator would refuse them (never offered then).
Uint8List? recordingExportBytes(
  AppLocalizations? l10n,
  TaskRecording recording, {
  required bool package,
  List<TaskPackageAsset> assets = const [],
  StoryboardReview? storyboard,
}) {
  final text = encodeRecordingText(recording);
  if (!decodeRecordingText(text).accepted) return null;
  return package
      ? writeTaskPackage(
          recording,
          transcript: recordingTranscript(l10n, recording),
          assets: assets,
          storyboard: storyboard,
        )
      : Uint8List.fromList(utf8.encode(text));
}

/// Saves [bytes] as [fileName] and tells the person what happened.
Future<void> saveAndTell(
  BuildContext context,
  WidgetRef ref, {
  required Uint8List? bytes,
  required String fileName,
}) async {
  final l10n = AppLocalizations.of(context);
  final failed = l10n?.taskRecorderSaveFailed ?? 'The file could not be saved.';
  if (bytes == null) {
    AppSnack.error(context, failed);
    return;
  }
  final SaveOutcome outcome;
  try {
    outcome = await ref.read(typedFileSaverProvider)(
      bytes: bytes,
      fileName: fileName,
    );
  } catch (e, st) {
    TraceLogger.instance.warn('recorder', 'export not saved', stackTrace: st);
    if (context.mounted) AppSnack.error(context, failed);
    return;
  }
  if (!context.mounted) return;
  switch (outcome) {
    case SavedFile(:final path):
      AppSnack.success(
        context,
        l10n?.taskRecorderSaved(path) ?? 'Saved: $path',
      );
    case SavedPrivately(:final path):
      AppSnack.info(
        context,
        l10n?.taskRecorderSavedPrivately(path) ??
            'Kept only inside the app: $path',
      );
    case DownloadRequested():
      AppSnack.info(
        context,
        l10n?.taskRecorderSaveNoPath ??
            'The file was handed to your browser or device; it did not '
                'say where it went.',
      );
    case SaveFailed():
      AppSnack.error(context, failed);
  }
}
