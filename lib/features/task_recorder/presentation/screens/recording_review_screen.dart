// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — review one private recording, leave steps out of the export,
// preview the exact file, save it, or delete the recording.
//
// The export is the plain JSON of task_recording_codec.dart — the same
// text the preview shows, byte for byte, re-read through the validator
// before it is offered. Saving goes through the app's file saver, which
// may hand the file to a browser or a system dialog: when it does not
// say where the file went, the screen says exactly that and never claims
// a confirmed file. Nothing is sent anywhere.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/files/file_saver.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/stored_recording.dart';
import '../../domain/action_registry.dart';
import '../../domain/recording_edit.dart';
import '../../domain/task_recording.dart';
import '../../domain/task_recording_codec.dart';
import '../../export/docx_export.dart';
import '../../package/task_package.dart';
import '../../providers/recorder_providers.dart';
import '../recorder_labels.dart';

class RecordingReviewScreen extends ConsumerStatefulWidget {
  const RecordingReviewScreen({super.key, required this.stored});

  final StoredRecording stored;

  @override
  ConsumerState<RecordingReviewScreen> createState() =>
      _RecordingReviewScreenState();
}

class _RecordingReviewScreenState extends ConsumerState<RecordingReviewScreen> {
  final Set<int> _leftOut = {};

  TaskRecording? get _source => widget.stored.recording;

  TaskRecording? get _export {
    final source = _source;
    return source == null ? null : editedCopy(source, _leftOut);
  }

  void _toggle(int seq) => setState(() {
    final source = _source;
    if (source == null) return;
    final group = dependentsOf(source, seq);
    if (_leftOut.contains(seq)) {
      _leftOut.removeAll(group);
    } else {
      _leftOut.addAll(group);
    }
  });

  Future<void> _save({bool package = false}) async {
    final l10n = AppLocalizations.of(context);
    final export = _export;
    if (export == null) return;
    final text = encodeRecordingText(export);
    // The file offered is the file the validator accepts, or none.
    if (!decodeRecordingText(text).accepted) {
      AppSnack.error(
        context,
        l10n?.taskRecorderSaveFailed ?? 'The file could not be saved.',
      );
      return;
    }
    final stem = 'deskilo-task-${widget.stored.id.substring(0, 8)}';
    final bytes = package
        ? writeTaskPackage(
            export,
            transcript: recordingTranscript(l10n, export),
          )
        : Uint8List.fromList(utf8.encode(text));
    final SaveOutcome outcome;
    try {
      outcome = await ref.read(typedFileSaverProvider)(
        bytes: bytes,
        fileName: package ? '$stem$taskPackageExtension' : '$stem.json',
      );
    } catch (e, st) {
      TraceLogger.instance.warn('recorder', 'export not saved', stackTrace: st);
      if (mounted) {
        AppSnack.error(
          context,
          l10n?.taskRecorderSaveFailed ?? 'The file could not be saved.',
        );
      }
      return;
    }
    if (!mounted) return;
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
        AppSnack.error(
          context,
          l10n?.taskRecorderSaveFailed ?? 'The file could not be saved.',
        );
    }
  }

  /// #1866 — the same edited copy as a Word document; the saver's
  /// answer is reported as it is, and a refusal saves nothing.
  Future<void> _saveWord() async {
    final l10n = AppLocalizations.of(context);
    final export = _export;
    if (export == null || l10n == null) return;
    final result = await ref.read(taskDocxExporterProvider).save(export, l10n);
    if (!mounted) return;
    switch (result) {
      case TaskDocxSaved(outcome: SavedFile(:final path)):
        AppSnack.success(context, l10n.taskExportSaved(path));
      case TaskDocxSaved(outcome: SavedPrivately(:final path)):
        AppSnack.info(context, l10n.taskRecorderSavedPrivately(path));
      case TaskDocxSaved():
        AppSnack.info(context, l10n.taskRecorderSaveNoPath);
      case TaskDocxRefused():
        AppSnack.error(context, l10n.taskExportRefused);
      case TaskDocxSaveFailed():
        AppSnack.error(context, l10n.taskExportSaveFailed);
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(
          l10n?.taskRecorderDeleteConfirm ??
              'Delete this recording from this device? Files you exported are '
                  'not affected, and nothing in the workspace changes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('task-recording-delete-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n?.taskRecorderDelete ?? 'Delete from this device'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(recorderStoreProvider)?.delete(widget.stored.id);
    } catch (e, st) {
      TraceLogger.instance.warn(
        'recorder',
        'recording not deleted',
        stackTrace: st,
      );
    }
    ref.invalidate(myRecordingsProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final source = _source;
    final export = _export;
    final title =
        source?.title ?? (l10n?.taskRecorderUntitled ?? 'Untitled task');
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            key: const ValueKey('task-recording-delete'),
            tooltip: l10n?.taskRecorderDelete ?? 'Delete from this device',
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: source == null || export == null
          ? Padding(
              padding: AppSpacing.gutterAll,
              child: Text(
                l10n?.taskRecorderUnreadable ??
                    'This recording cannot be read. You can delete it.',
              ),
            )
          : ListView(
              padding: AppSpacing.gutterAll,
              children: [
                Text(
                  '${completenessLabel(l10n, source.completeness)} · '
                  '${endReasonLabel(l10n, source.endReason)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final step in source.steps) ...[
                  if (step.seq > 1 &&
                      source.steps[step.seq - 2].segment != step.segment)
                    _Gap(label: l10n?.taskRecorderSegmentGap ?? 'Paused here'),
                  _StepTile(
                    step: step,
                    answered:
                        !step.isAttempt ||
                        source.steps.any(
                          (s) =>
                              s.kind == StepKind.observation && s.op == step.op,
                        ),
                    leftOut: _leftOut.contains(step.seq),
                    onToggle: () => _toggle(step.seq),
                  ),
                ],
                if (_leftOut.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n?.taskRecorderEditedNote(_leftOut.length) ??
                        'Edited copy: ${_leftOut.length} steps left out.',
                    key: const ValueKey('task-recording-edited-note'),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                ExpansionTile(
                  key: const ValueKey('task-recording-preview'),
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    l10n?.taskRecorderExportPreview ??
                        'What the file will contain',
                  ),
                  children: [
                    SelectableText(
                      encodeRecordingText(export),
                      key: const ValueKey('task-recording-preview-text'),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(fontFamily: 'monospace'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  key: const ValueKey('task-recording-export'),
                  onPressed: _save,
                  icon: const Icon(Icons.download),
                  label: Text(l10n?.taskRecorderExport ?? 'Export a file'),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  key: const ValueKey('task-recording-export-package'),
                  onPressed: () => _save(package: true),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: Text(
                    l10n?.taskRecorderExportPackage ?? 'Export a task package',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  key: const ValueKey('task-recording-export-word'),
                  onPressed: _saveWord,
                  icon: const Icon(Icons.description_outlined),
                  label: Text(
                    l10n?.taskExportWordButton ?? 'Export as Word document',
                  ),
                ),
              ],
            ),
    );
  }
}

class _Gap extends StatelessWidget {
  const _Gap({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      children: [
        const Expanded(child: Divider()),
        Padding(padding: AppSpacing.smH, child: Text(label)),
        const Expanded(child: Divider()),
      ],
    ),
  );
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.step,
    required this.answered,
    required this.leftOut,
    required this.onToggle,
  });

  final RecordedStep step;
  final bool answered;
  final bool leftOut;
  final VoidCallback onToggle;

  IconData get _icon => switch (step.kind) {
    StepKind.action => step.isAttempt ? Icons.send : Icons.touch_app,
    StepKind.observation => switch (step.state) {
      ObservationState.confirmed => Icons.check_circle_outline,
      ObservationState.refused => Icons.block,
      ObservationState.pending => Icons.hourglass_empty,
      _ => Icons.help_outline,
    },
    StepKind.annotation => Icons.edit_note,
    StepKind.excluded => Icons.lock_outline,
    StepKind.unrecorded => Icons.more_horiz,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = stepText(l10n, step);
    final unanswered = answered
        ? null
        : (l10n?.taskRecorderNoOutcome ?? 'No answer recorded');
    final detail = [?text.detail, ?unanswered].join(' · ');
    final style = leftOut
        ? TextStyle(
            decoration: TextDecoration.lineThrough,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          )
        : null;
    return ListTile(
      key: ValueKey('task-step-${step.seq}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(_icon),
      title: Text(text.title, style: style),
      subtitle: detail.isEmpty ? null : Text(detail, style: style),
      trailing: IconButton(
        key: ValueKey('task-step-toggle-${step.seq}'),
        tooltip: leftOut
            ? (l10n?.taskRecorderPutBack ?? 'Put back')
            : (l10n?.taskRecorderLeaveOut ?? 'Leave out of the export'),
        icon: Icon(leftOut ? Icons.undo : Icons.remove_circle_outline),
        onPressed: onToggle,
      ),
    );
  }
}
