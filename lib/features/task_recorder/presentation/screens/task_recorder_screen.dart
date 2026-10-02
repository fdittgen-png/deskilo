// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — "Record this task": the start disclosure, the live controls
// and this account's private recordings on this device.
//
// Recording only ever starts from the Start button below the disclosure:
// no auto-start, no remote activation. Starting needs the taskRecorder
// feature in the active workspace; reading, exporting and deleting the
// recordings already on this device never does, so switching the
// feature off never strands a person's own files.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/recorder_controller.dart';
import '../../domain/stored_recording.dart';
import '../../domain/task_recording.dart';
import '../../providers/recorder_providers.dart';
import '../recorder_labels.dart';
import 'recording_review_screen.dart';

class TaskRecorderScreen extends ConsumerStatefulWidget {
  const TaskRecorderScreen({super.key});

  @override
  ConsumerState<TaskRecorderScreen> createState() => _TaskRecorderScreenState();
}

class _TaskRecorderScreenState extends ConsumerState<TaskRecorderScreen> {
  @override
  void initState() {
    super.initState();
    // The indicator starts listening from here on, never before.
    Future.microtask(() {
      if (mounted) ref.read(recorderOpenedProvider.notifier).open();
    });
  }

  Future<void> _start() async {
    final l10n = AppLocalizations.of(context);
    final scope = ref.read(recorderScopeProvider);
    final started = scope != null &&
        await ref.read(recorderControllerProvider).start(
          scope: scope,
          prerequisites: const [Prerequisite('signed_in')],
        );
    if (!mounted || started) return;
    AppSnack.error(context,
        l10n?.taskRecorderStartFailed ??
            'The recording could not start on this device.');
  }

  Future<void> _stop() async {
    await ref.read(recorderControllerProvider).stop();
    ref.invalidate(myRecordingsProvider);
  }

  Future<void> _discard() async {
    await ref.read(recorderControllerProvider).discard();
    ref.invalidate(myRecordingsProvider);
  }

  Future<void> _note() async {
    final note = await showDialog<String>(
      context: context,
      builder: (context) => const _NoteDialog(),
    );
    if (note != null) ref.read(recorderControllerProvider).annotate(note);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.watch(recorderControllerProvider);
    ref.watch(recorderStatusProvider);
    final state = controller.state;
    final signedIn = ref.watch(recorderScopeProvider) != null;
    final available = ref.watch(taskRecorderAvailableProvider);
    final live =
        state == RecorderState.recording || state == RecorderState.paused;
    return Scaffold(
      appBar: AppBar(title: Text(l10n?.taskRecorderTitle ?? 'Task recorder')),
      body: ListView(
        padding: AppSpacing.gutterAll,
        children: [
          if (live)
            _LiveControls(
              paused: state == RecorderState.paused,
              steps: controller.status.stepCount,
              onPause: controller.pause,
              onResume: controller.resume,
              onStop: _stop,
              onDiscard: _discard,
              onNote: _note,
            )
          else
            _Disclosure(
              canStart: signedIn && available,
              reason: !signedIn
                  ? (l10n?.taskRecorderSignedOut ?? 'Sign in to record a task.')
                  : !available
                      ? (l10n?.taskRecorderUnavailable ??
                          'Recording is not switched on in this workspace.')
                      : null,
              onStart: _start,
            ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            l10n?.taskRecorderMyRecordings ?? 'My recordings on this device',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const _RecordingsList(),
        ],
      ),
    );
  }
}

class _Disclosure extends StatelessWidget {
  const _Disclosure({
    required this.canStart,
    required this.reason,
    required this.onStart,
  });

  final bool canStart;
  final String? reason;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const limits = RecordingLimits();
    final title = l10n?.taskRecorderDisclosureTitle ?? 'Before you record';
    final body = l10n?.taskRecorderDisclosureBody ??
        'The recorder notes the steps you take on this workspace\'s '
            'screens on this device only. Nothing is uploaded.';
    final limitText = l10n?.taskRecorderLimits(
          limits.maxSteps,
          limits.maxDuration.inMinutes,
          limits.retention.inDays,
        ) ??
        'Up to ${limits.maxSteps} steps or ${limits.maxDuration.inMinutes} '
            'minutes per recording.';
    final why = reason;
    return Card(
      child: Padding(
        padding: AppSpacing.lgAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(body),
            const SizedBox(height: AppSpacing.sm),
            Text(limitText, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.lg),
            if (why != null) ...[
              Text(why),
              const SizedBox(height: AppSpacing.sm),
            ],
            FilledButton.icon(
              key: const ValueKey('task-recorder-start'),
              onPressed: canStart ? onStart : null,
              icon: const Icon(Icons.fiber_manual_record),
              label: Text(l10n?.taskRecorderStart ?? 'Start recording'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveControls extends StatelessWidget {
  const _LiveControls({
    required this.paused,
    required this.steps,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onDiscard,
    required this.onNote,
  });

  final bool paused;
  final int steps;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback onDiscard;
  final VoidCallback onNote;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final heading = paused
        ? (l10n?.taskRecorderPaused ?? 'Paused')
        : (l10n?.taskRecorderRecording ?? 'Recording');
    final count = l10n?.taskRecorderStepCount(steps) ?? '$steps steps';
    return Card(
      child: Padding(
        padding: AppSpacing.lgAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(heading, style: Theme.of(context).textTheme.titleMedium),
            Text(count),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('task-recorder-pause'),
                  onPressed: paused ? onResume : onPause,
                  icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                  label: Text(paused
                      ? (l10n?.taskRecorderResume ?? 'Resume')
                      : (l10n?.taskRecorderPause ?? 'Pause')),
                ),
                FilledButton.icon(
                  key: const ValueKey('task-recorder-stop'),
                  onPressed: onStop,
                  icon: const Icon(Icons.stop),
                  label: Text(l10n?.taskRecorderStop ?? 'Stop'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('task-recorder-note'),
                  onPressed: onNote,
                  icon: const Icon(Icons.edit_note),
                  label: Text(l10n?.taskRecorderAddNote ?? 'Add a note'),
                ),
                TextButton.icon(
                  key: const ValueKey('task-recorder-discard'),
                  onPressed: onDiscard,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n?.taskRecorderDiscard ?? 'Discard'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingsList extends ConsumerWidget {
  const _RecordingsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final recordings =
        ref.watch(myRecordingsProvider).value ?? const <StoredRecording>[];
    if (recordings.isEmpty) {
      return EmptyState(
        icon: Icons.history,
        title: l10n?.taskRecorderNoRecordings ?? 'No recordings on this device.',
      );
    }
    return Column(
      children: [
        for (final stored in recordings) _RecordingTile(stored: stored),
      ],
    );
  }
}

class _RecordingTile extends ConsumerWidget {
  const _RecordingTile({required this.stored});

  final StoredRecording stored;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final recording = stored.recording;
    final title = recording?.title ?? (l10n?.taskRecorderUntitled ?? 'Untitled task');
    final subtitle = recording == null
        ? (l10n?.taskRecorderUnreadable ??
            'This recording cannot be read. You can delete it.')
        : '${l10n?.taskRecorderStepCount(recording.steps.length) ?? '${recording.steps.length} steps'}'
            ' · ${completenessLabel(l10n, recording.completeness)}';
    return ListTile(
      key: ValueKey('task-recording-${stored.id}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(recording == null ? Icons.error_outline : Icons.list_alt),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => RecordingReviewScreen(stored: stored),
        ));
        ref.invalidate(myRecordingsProvider);
      },
    );
  }
}

/// The note dialog owns its text controller, so the field outlives the
/// closing animation.
class _NoteDialog extends StatefulWidget {
  const _NoteDialog();

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n?.taskRecorderAddNote ?? 'Add a note'),
      content: TextField(
        key: const ValueKey('task-recorder-note-field'),
        controller: _text,
        autofocus: true,
        maxLines: 4,
        maxLength: const RecordingLimits().maxNoteLength,
        decoration: InputDecoration(
          hintText: l10n?.taskRecorderNoteHint ??
              'Your own words, kept as you write them',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(material.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_text.text),
          child: Text(material.okButtonLabel),
        ),
      ],
    );
  }
}
