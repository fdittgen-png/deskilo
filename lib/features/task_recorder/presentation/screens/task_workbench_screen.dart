// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1872 — the local task workbench: open a saved task file, see what it
// is, work on a private copy, save it again or make an output from it.
//
// No account, no workspace and no server: this screen reads no
// repository and calls nothing remote. The file is chosen by the person
// and read on this device; the formats and the size limit are shown
// BEFORE anything is read, and a file over the limit is refused by its
// size, unread. What the file says about itself is shown as its claims.
// Outputs (Word, storyboard, video) come from the generator registry
// and are offered only where the platform can make them.

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/files/file_picker.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/workbench_import.dart';
import '../../domain/recording_edit.dart';
import '../../domain/task_recording.dart';
import '../../guide/guide_compiler.dart';
import 'guide_draft_screen.dart';
import '../../package/task_package.dart';
import '../recorder_labels.dart';
import '../recording_export.dart';
import '../widgets/recording_steps_view.dart';
import '../widgets/task_outputs_section.dart';
import '../../package/task_output.dart';
import '../../storyboard/storyboard.dart';
import '../../storyboard/storyboard_builder.dart';
import '../../storyboard/storyboard_pictures.dart';
import '../../export/task_document.dart' show recordingRevision;
import '../../package/storyboard_review.dart';
import '../../storyboard/storyboard_preview.dart';

class TaskWorkbenchScreen extends ConsumerStatefulWidget {
  const TaskWorkbenchScreen({super.key});

  @override
  ConsumerState<TaskWorkbenchScreen> createState() =>
      _TaskWorkbenchScreenState();
}

class _TaskWorkbenchScreenState extends ConsumerState<TaskWorkbenchScreen> {
  WorkbenchOpened? _opened;

  /// The reviewed storyboard (#1876) of the current copy; null until the
  /// person reviews it, and again whenever the copy changes.
  Storyboard? _storyboard;
  final Set<int> _leftOut = {};

  TaskRecording? get _copy {
    final opened = _opened;
    return opened == null ? null : editedCopy(opened.recording, _leftOut);
  }

  Future<void> _choose() async {
    final l10n = AppLocalizations.of(context);
    final XFile? file;
    try {
      file = await ref.read(filePickerProvider)(
        XTypeGroup(
          label: l10n?.taskWorkbenchFileType ?? 'Task file',
          extensions: workbenchExtensions,
        ),
      );
    } catch (e, st) {
      TraceLogger.instance.warn('recorder', 'picker failed', stackTrace: st);
      return;
    }
    if (file == null || !mounted) return;
    WorkbenchImport result;
    try {
      // The size first: a file over the limit is refused unread.
      if (await file.length() > workbenchMaxBytes) {
        result = const WorkbenchRefused(WorkbenchRefusal.tooLarge);
      } else {
        result = openTaskFile(await file.readAsBytes());
      }
    } catch (e, st) {
      TraceLogger.instance.warn(
        'recorder',
        'task file not read (${e.runtimeType})',
        stackTrace: st,
      );
      result = const WorkbenchRefused(WorkbenchRefusal.unsupported);
    }
    if (!mounted) return;
    switch (result) {
      case final WorkbenchOpened opened:
        final restored = _restoredStoryboard(opened);
        setState(() {
          _opened = opened;
          _leftOut.clear();
          _storyboard = restored;
        });
      case WorkbenchRefused(:final reason):
        AppSnack.error(context, refusalText(l10n, reason));
    }
  }

  void _toggle(int seq) => setState(() {
    final opened = _opened;
    if (opened == null) return;
    final group = dependentsOf(opened.recording, seq);
    _storyboard = null;
    if (_leftOut.contains(seq)) {
      _leftOut.removeAll(group);
    } else {
      _leftOut.addAll(group);
    }
  });

  Future<void> _reviewIllustrations() async {
    final copy = _copy;
    final l10n = AppLocalizations.of(context);
    if (copy == null || l10n == null) return;
    Storyboard board;
    try {
      board = _storyboard ?? buildStoryboard(copy, l10n);
    } catch (e, st) {
      TraceLogger.instance.warn(
        'recorder',
        'storyboard not built (${e.runtimeType})',
        stackTrace: st,
      );
      AppSnack.error(context, outputReasonText(l10n, TaskOutputReason.refused));
      return;
    }
    setState(() => _storyboard = board);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _StoryboardPage(
          initial: board,
          onChanged: (next) {
            if (mounted) setState(() => _storyboard = next);
          },
        ),
      ),
    );
  }

  /// #1876 — the package's reviewed storyboard, replayed on one derived
  /// again from its recording. Said aloud when it cannot be used.
  Storyboard? _restoredStoryboard(WorkbenchOpened opened) {
    final review = opened.storyboard;
    final l10n = AppLocalizations.of(context);
    if (review == null || l10n == null) return null;
    try {
      final result = applyReview(
        buildStoryboard(opened.recording, l10n),
        review,
      );
      if (result.outcome == ReviewOutcome.applied) {
        AppSnack.info(context, l10n.taskWorkbenchStoryboardRestored);
        return result.storyboard;
      }
    } catch (e, st) {
      TraceLogger.instance.warn(
        'recorder',
        'storyboard not restored (${e.runtimeType})',
        stackTrace: st,
      );
    }
    AppSnack.info(context, outputReasonText(l10n, TaskOutputReason.stale));
    return null;
  }

  Future<void> _saveTask({required bool package}) async {
    final copy = _copy;
    final opened = _opened;
    if (copy == null || opened == null) return;
    final l10n = AppLocalizations.of(context);
    // #1876 — a package keeps the reviewed storyboard of THIS copy and the
    // pictures of its approved frames.
    final board = _storyboard;
    final keep =
        package &&
        board != null &&
        board.sourceRevision == recordingRevision(copy);
    var assets = opened.assets;
    if (keep) {
      final pictures = await renderApprovedPictures(
        board,
        colors: Theme.of(context).colorScheme,
        provenance: l10n?.taskExportSceneProvenance ?? 'Illustration',
      );
      assets = [
        ...opened.assets.where((a) => !a.path.startsWith('media/frame-')),
        for (final p in pictures.pictures.entries)
          TaskPackageAsset('media/frame-${p.key}.png', p.value),
      ];
      if (!mounted) return;
    }
    await saveAndTell(
      context,
      ref,
      bytes: recordingExportBytes(
        l10n,
        copy,
        package: package,
        assets: assets,
        storyboard: keep ? StoryboardReview.of(board) : null,
      ),
      fileName: package
          ? 'deskilo-task$taskPackageExtension'
          : 'deskilo-task.json',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final opened = _opened;
    final copy = _copy;
    return Scaffold(
      appBar: AppBar(title: Text(l10n?.taskWorkbenchTitle ?? 'Task workbench')),
      body: ListView(
        padding: AppSpacing.gutterAll,
        children: [
          Text(
            l10n?.taskWorkbenchIntro ??
                'Open a saved task file. It is read on this device only; '
                    'nothing is uploaded and no sign-in is needed.',
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n?.taskWorkbenchAccepted(workbenchMaxBytes ~/ (1024 * 1024)) ??
                'Accepted: .json and .deskilo-task.zip, up to '
                    '${workbenchMaxBytes ~/ (1024 * 1024)} MB.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            key: const ValueKey('workbench-choose'),
            onPressed: _choose,
            icon: const Icon(Icons.file_open_outlined),
            label: Text(l10n?.taskWorkbenchChoose ?? 'Choose a task file'),
          ),
          if (opened != null && copy != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _Summary(opened: opened),
            const SizedBox(height: AppSpacing.sm),
            RecordingStepsView(
              recording: opened.recording,
              leftOut: _leftOut,
              onToggle: _toggle,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.icon(
                  key: const ValueKey('workbench-save-json'),
                  onPressed: () => _saveTask(package: false),
                  icon: const Icon(Icons.download),
                  label: Text(l10n?.taskRecorderExport ?? 'Export a file'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('workbench-save-package'),
                  onPressed: () => _saveTask(package: true),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: Text(
                    l10n?.taskRecorderExportPackage ?? 'Export a task package',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              key: const ValueKey('workbench-review-illustrations'),
              onPressed: _reviewIllustrations,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                l10n?.taskWorkbenchReviewIllustrations ??
                    'Review the illustrations',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              key: const ValueKey('workbench-create-guide'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => GuideDraftScreen(guide: compileGuide(copy)),
                ),
              ),
              icon: const Icon(Icons.route_outlined),
              label: Text(l10n?.taskGuideCreate ?? 'Create a guide draft'),
            ),
            const SizedBox(height: AppSpacing.md),
            TaskOutputsSection(
              recording: () => _copy!,
              assets: {for (final a in opened.assets) a.path: a.bytes},
              storyboard: () => _storyboard,
            ),
          ],
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.opened});

  final WorkbenchOpened opened;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final r = opened.recording;
    final lines = <String>[
      r.title ?? (l10n?.taskRecorderUntitled ?? 'Untitled task'),
      '${completenessLabel(l10n, r.completeness)} · '
          '${endReasonLabel(l10n, r.endReason)}',
      if (r.kind == RecordingKind.edited)
        l10n?.taskWorkbenchEdited ?? 'An edited copy of a recording.',
      if (!opened.runnable)
        l10n?.taskWorkbenchTranscriptOnly ??
            'Some steps come from a newer version: shown as a transcript only.',
      l10n?.taskWorkbenchUntrusted ??
          'A private draft from a file: nothing in it is trusted or sent.',
      for (final claim in opened.claims.entries)
        l10n?.taskWorkbenchClaim(claim.key, claim.value) ??
            'The file says ${claim.key}: ${claim.value}',
    ];
    return Card(
      child: Padding(
        padding: AppSpacing.lgAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final line in lines) Text(line)],
        ),
      ),
    );
  }
}

/// The words for a refused file.
String refusalText(AppLocalizations? l10n, WorkbenchRefusal reason) =>
    switch (reason) {
      WorkbenchRefusal.tooLarge =>
        l10n?.taskWorkbenchRefusedTooLarge ??
            'This file is larger than the workbench reads.',
      WorkbenchRefusal.unsupported =>
        l10n?.taskWorkbenchRefusedUnsupported ?? 'This is not a task file.',
      WorkbenchRefusal.unsafe =>
        l10n?.taskWorkbenchRefusedUnsafe ??
            'This file is built in a way that is not safe to open.',
      WorkbenchRefusal.damaged =>
        l10n?.taskWorkbenchRefusedDamaged ??
            'This file is damaged or was changed after it was made.',
      WorkbenchRefusal.newer =>
        l10n?.taskWorkbenchRefusedNewer ??
            'This file was made by a newer version of the app.',
      WorkbenchRefusal.invalid =>
        l10n?.taskWorkbenchRefusedInvalid ??
            'This file does not hold a valid task.',
    };

/// The storyboard review on its own page: it scrolls by itself.
class _StoryboardPage extends StatefulWidget {
  const _StoryboardPage({required this.initial, required this.onChanged});

  final Storyboard initial;
  final ValueChanged<Storyboard> onChanged;

  @override
  State<_StoryboardPage> createState() => _StoryboardPageState();
}

class _StoryboardPageState extends State<_StoryboardPage> {
  late Storyboard _board = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n?.taskWorkbenchReviewIllustrations ?? 'Review the illustrations',
        ),
      ),
      body: StoryboardPreview(
        storyboard: _board,
        onChanged: (next) {
          setState(() => _board = next);
          widget.onChanged(next);
        },
      ),
    );
  }
}
