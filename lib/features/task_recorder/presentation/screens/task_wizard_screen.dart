// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The task wizard: where a person records what they do, turns it into a
// guide, and follows guides step by step on the real app.
//
// One screen for the whole journey, so nothing is hidden behind an icon:
//   * Guides   — "My guides" (kept on this device) and the guides that
//                ship with the app, each with a Start button; a guide of
//                the person's own can be edited or deleted. "Add a guide"
//                offers the two ways in: from one of the recordings, or
//                from a task file or package.
//   * Recordings — Record a task, and the list of this account's
//                recordings, each with a one-tap "Make a guide".
//   * Tools    — open a task file in the local workbench (no account).
// Starting a guide needs the task recorder in this workspace and a
// signed-in account, as it always did; the screen says so when it cannot.

import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/files/file_picker.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/workbench_import.dart';
import '../../domain/stored_guide.dart';
import '../../domain/stored_recording.dart';
import '../../guide/builtin_guides.dart';
import '../../guide/guide_codec.dart';
import '../../guide/guide_destination.dart';
import '../../guide/guide_compiler.dart';
import '../../guide/guide_session.dart';
import '../../guide/task_guide.dart';
import '../../providers/recorder_providers.dart';
import '../recorder_labels.dart';
import '../route_classification.dart';
import 'guide_draft_screen.dart';
import 'recording_review_screen.dart';
import 'task_workbench_screen.dart' show refusalText;

class TaskWizardScreen extends ConsumerWidget {
  const TaskWizardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final available = ref.watch(taskRecorderAvailableProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n?.taskWizardTitle ?? 'Task wizard')),
      body: ListView(
        key: const ValueKey('task-wizard'),
        padding: AppSpacing.gutterAll,
        children: [
          Text(
            l10n?.taskWizardIntro ??
                'Record what you do, turn it into a guide, and follow guides '
                    'step by step on the real app.',
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(
            key: const ValueKey('task-wizard-guides'),
            title: l10n?.taskWizardGuides ?? 'Guides',
            action: FilledButton.tonalIcon(
              key: const ValueKey('task-wizard-add-guide'),
              onPressed: () => _addGuide(context, ref),
              icon: const Icon(Icons.library_add_outlined),
              label: Text(l10n?.taskWizardAddGuide ?? 'Add a guide'),
            ),
          ),
          const _MyGuides(),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(
              l10n?.taskWizardBuiltIn ?? 'Guides that come with the app',
              style: text.titleSmall,
            ),
          ),
          for (final g in BuiltinGuide.values)
            ListTile(
              key: ValueKey('task-wizard-builtin-${g.name}'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.assistant_navigation),
              title: Text(builtinGuideTitle(l10n, g)),
              trailing: FilledButton(
                key: ValueKey('task-wizard-start-builtin-${g.name}'),
                onPressed: () => _start(context, ref, builtinGuide(l10n, g)),
                child: Text(l10n?.guideStart ?? 'Start the guide'),
              ),
            ),
          if (!available)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                l10n?.taskWizardUnavailable ??
                    'The task recorder is turned off in this workspace: '
                        'guides can be read and edited here, but not '
                        'followed.',
                key: const ValueKey('task-wizard-unavailable'),
                style: text.bodySmall,
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(
            key: const ValueKey('task-wizard-recordings'),
            title: l10n?.taskWizardRecordings ?? 'Recordings',
            action: FilledButton.icon(
              key: const ValueKey('task-wizard-record'),
              onPressed: () => context.push(taskRecorderRoute),
              icon: const Icon(Icons.fiber_manual_record_outlined),
              label: Text(l10n?.taskRecorderRecordATask ?? 'Record a task'),
            ),
          ),
          const _Recordings(),
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(title: l10n?.taskWizardTools ?? 'Tools'),
          ListTile(
            key: const ValueKey('task-wizard-open-file'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.file_open_outlined),
            title: Text(l10n?.taskWorkbenchOpen ?? 'Open a task file'),
            subtitle: Text(
              l10n?.taskWizardOpenFileHint ??
                  'Read, edit and export a recording or task package, '
                      'without an account.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(taskWorkbenchRoute),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: AppSpacing.xs,
        spacing: AppSpacing.sm,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Starts [guide] on the live app, or says why it cannot.
void _start(BuildContext context, WidgetRef ref, TaskGuide guide) {
  final l10n = AppLocalizations.of(context);
  final decoded = decodeGuideText(encodeGuideText(guide));
  final messenger = ScaffoldMessenger.of(context);
  if (!decoded.runnable) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n?.guideStartNotRunnable ??
              'This guide names steps this version of the app does not '
                  'know; it can be read, not followed.',
        ),
      ),
    );
    return;
  }
  if (!ref.read(guideSessionProvider.notifier).start(decoded.guide!)) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n?.guideStartRefused ??
              'This guide cannot start here: sign in and turn the task '
                  'recorder on in this workspace.',
        ),
      ),
    );
    return;
  }
  // Back to the app, where the guide is followed.
  Navigator.of(context).popUntil((route) => route.isFirst);
}

/// The two ways to add a guide.
Future<void> _addGuide(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final choice = await showModalBottomSheet<_AddChoice>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const ValueKey('task-wizard-add-from-recording'),
            leading: const Icon(Icons.list_alt),
            title: Text(
              l10n?.taskWizardFromRecording ?? 'From one of my recordings',
            ),
            subtitle: Text(
              l10n?.taskWizardFromRecordingHint ??
                  'Pick a recording; it becomes a guide at once.',
            ),
            onTap: () => Navigator.of(sheet).pop(_AddChoice.recording),
          ),
          ListTile(
            key: const ValueKey('task-wizard-add-from-file'),
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(
              l10n?.taskWizardFromFile ?? 'From a task file or package',
            ),
            subtitle: Text(
              l10n?.taskWizardFromFileHint ??
                  'A recording, a task package or a guide file from '
                      'someone else.',
            ),
            onTap: () => Navigator.of(sheet).pop(_AddChoice.file),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case _AddChoice.recording:
      await _pickRecording(context, ref);
    case _AddChoice.file:
      await _addFromFile(context, ref);
  }
}

enum _AddChoice { recording, file }

Future<void> _pickRecording(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final recordings =
      (ref.read(myRecordingsProvider).value ?? const <StoredRecording>[])
          .where((r) => r.recording != null)
          .toList();
  if (recordings.isEmpty) {
    AppSnack.error(
      context,
      l10n?.taskRecorderNoRecordings ?? 'No recordings on this device.',
    );
    return;
  }
  final picked = await showModalBottomSheet<StoredRecording>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: AppSpacing.gutterH,
            child: Text(
              l10n?.taskWizardFromRecording ?? 'From one of my recordings',
              style: Theme.of(sheet).textTheme.titleMedium,
            ),
          ),
          for (final r in recordings)
            ListTile(
              key: ValueKey('task-wizard-pick-${r.id}'),
              leading: const Icon(Icons.list_alt),
              title: Text(
                r.recording!.title ??
                    (l10n?.taskRecorderUntitled ?? 'Untitled task'),
              ),
              subtitle: Text(
                l10n?.taskRecorderStepCount(r.recording!.steps.length) ??
                    '${r.recording!.steps.length} steps',
              ),
              onTap: () => Navigator.of(sheet).pop(r),
            ),
        ],
      ),
    ),
  );
  if (picked == null || !context.mounted) return;
  await _makeGuide(context, ref, picked);
}

/// A recording becomes a guide in the library at once; the person can edit
/// it from the library whenever they like.
Future<void> _makeGuide(
  BuildContext context,
  WidgetRef ref,
  StoredRecording stored,
) async {
  final l10n = AppLocalizations.of(context);
  final recording = stored.recording;
  final store = ref.read(guideStoreProvider);
  if (recording == null || store == null) return;
  try {
    final guide = compileGuide(recording);
    final id = await store.add(guide);
    ref.invalidate(myGuidesProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const ValueKey('task-wizard-guide-added'),
        content: Text(l10n?.taskWizardGuideAdded ?? 'Added to My guides.'),
        action: SnackBarAction(
          key: const ValueKey('task-wizard-guide-added-edit'),
          label: l10n?.taskWizardEdit ?? 'Edit',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => GuideDraftScreen(guide: guide, libraryId: id),
            ),
          ),
        ),
      ),
    );
  } on Object catch (e, st) {
    TraceLogger.instance.warn(
      'recorder',
      'guide not made (${e.runtimeType})',
      stackTrace: st,
    );
    if (!context.mounted) return;
    AppSnack.error(
      context,
      l10n?.taskWizardGuideNotSaved ?? 'The guide could not be kept.',
    );
  }
}

Future<void> _addFromFile(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final store = ref.read(guideStoreProvider);
  if (store == null) return;
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
  if (file == null || !context.mounted) return;
  TaskGuide? guide;
  WorkbenchRefusal? refusal;
  try {
    if (await file.length() > workbenchMaxBytes) {
      refusal = WorkbenchRefusal.tooLarge;
    } else {
      final bytes = await file.readAsBytes();
      // A guide file first (the format marker is on its first line), else
      // a recording or package, compiled the same way a recording is.
      guide = _guideOf(bytes);
      if (guide == null) {
        switch (openTaskFile(bytes)) {
          case final WorkbenchOpened opened:
            guide = compileGuide(opened.recording);
          case WorkbenchRefused(:final reason):
            refusal = reason;
        }
      }
    }
  } on Object catch (e, st) {
    TraceLogger.instance.warn(
      'recorder',
      'task file not read (${e.runtimeType})',
      stackTrace: st,
    );
    refusal = WorkbenchRefusal.unsupported;
  }
  if (!context.mounted) return;
  if (guide == null) {
    AppSnack.error(
      context,
      refusalText(l10n, refusal ?? WorkbenchRefusal.unsupported),
    );
    return;
  }
  // Opened as a draft first: the person names it and keeps it.
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => GuideDraftScreen(guide: guide!)),
  );
  ref.invalidate(myGuidesProvider);
}

TaskGuide? _guideOf(List<int> bytes) {
  try {
    final text = utf8.decode(bytes);
    if (!text.contains(taskGuideFormat)) return null;
    return decodeGuideText(text).guide;
  } on FormatException {
    return null;
  }
}

class _MyGuides extends ConsumerWidget {
  const _MyGuides();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final guides = ref.watch(myGuidesProvider).value ?? const <StoredGuide>[];
    if (guides.isEmpty) {
      return EmptyState(
        key: const ValueKey('task-wizard-no-guides'),
        icon: Icons.route_outlined,
        title: l10n?.taskWizardNoGuides ?? 'No guide of your own yet. Add one from a recording or a task file.',
      );
    }
    return Column(
      children: [for (final stored in guides) _GuideTile(stored: stored)],
    );
  }
}

class _GuideTile extends ConsumerWidget {
  const _GuideTile({required this.stored});

  final StoredGuide stored;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final guide = stored.guide;
    return ListTile(
      key: ValueKey('task-wizard-guide-${stored.id}'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.route_outlined),
      title: Text(guide.title ?? (l10n?.guideHostTitle ?? 'Guided task')),
      subtitle: Text(
        l10n?.taskRecorderStepCount(guide.steps.length) ??
            '${guide.steps.length} steps',
      ),
      onTap: () => _edit(context, ref),
      trailing: Wrap(
        spacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton(
            key: ValueKey('task-wizard-start-${stored.id}'),
            onPressed: () =>
                guide.steps.any(
                  (step) => guideStepRoute(guide.steps, step) == null,
                )
                ? _edit(context, ref)
                : _start(context, ref, guide),
            child: Text(l10n?.guideStart ?? 'Start the guide'),
          ),
          PopupMenuButton<String>(
            key: ValueKey('task-wizard-menu-${stored.id}'),
            onSelected: (v) {
              if (v == 'edit') _edit(context, ref);
              if (v == 'delete') _delete(context, ref);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: Text(l10n?.taskWizardEdit ?? 'Edit'),
              ),
              PopupMenuItem(
                key: ValueKey('task-wizard-delete-${stored.id}'),
                value: 'delete',
                child: Text(l10n?.taskWizardDeleteGuide ?? 'Delete this guide'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            GuideDraftScreen(guide: stored.guide, libraryId: stored.id),
      ),
    );
    ref.invalidate(myGuidesProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n?.taskWizardDeleteGuide ?? 'Delete this guide'),
        content: Text(
          l10n?.taskWizardDeleteGuideBody ??
              'The guide is removed from this device. The recording it came '
                  'from is not touched.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('task-wizard-delete-cancel'),
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(material.cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('task-wizard-delete-confirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(material.deleteButtonTooltip),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(guideStoreProvider)?.delete(stored.id);
    ref.invalidate(myGuidesProvider);
  }
}

class _Recordings extends ConsumerWidget {
  const _Recordings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final recordings =
        ref.watch(myRecordingsProvider).value ?? const <StoredRecording>[];
    if (recordings.isEmpty) {
      return EmptyState(
        key: const ValueKey('task-wizard-no-recordings'),
        icon: Icons.history,
        title:
            l10n?.taskRecorderNoRecordings ?? 'No recordings on this device.',
      );
    }
    return Column(
      children: [
        for (final stored in recordings)
          ListTile(
            key: ValueKey('task-wizard-recording-${stored.id}'),
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              stored.recording == null ? Icons.error_outline : Icons.list_alt,
            ),
            title: Text(
              stored.recording?.title ??
                  (l10n?.taskRecorderUntitled ?? 'Untitled task'),
            ),
            subtitle: Text(
              stored.recording == null
                  ? (l10n?.taskRecorderUnreadable ??
                        'This recording cannot be read. You can delete it.')
                  : '${l10n?.taskRecorderStepCount(stored.recording!.steps.length) ?? ''}'
                        ' · ${completenessLabel(l10n, stored.recording!.completeness)}',
            ),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RecordingReviewScreen(stored: stored),
                ),
              );
              ref.invalidate(myRecordingsProvider);
            },
            trailing: stored.recording == null
                ? null
                : TextButton.icon(
                    key: ValueKey('task-wizard-make-guide-${stored.id}'),
                    onPressed: () => _makeGuide(context, ref, stored),
                    icon: const Icon(Icons.route_outlined),
                    label: Text(l10n?.taskWizardMakeGuide ?? 'Make a guide'),
                  ),
          ),
      ],
    );
  }
}
