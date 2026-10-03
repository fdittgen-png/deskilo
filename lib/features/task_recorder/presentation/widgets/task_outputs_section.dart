// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1872 — the outputs a recording can be made into (Word, storyboard,
// video, captions), from the generator registry. Each is offered only
// where its generator says the platform can make it — never by a
// workspace feature — and its result is saved through the typed saver.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/task_recording.dart';
import '../../package/task_output.dart';
import '../../providers/recorder_providers.dart';
import '../recording_export.dart';

class TaskOutputsSection extends ConsumerStatefulWidget {
  const TaskOutputsSection({
    super.key,
    required this.recording,
    this.assets = const {},
  });

  /// The recording as it is when an output is asked for: the job keeps
  /// that copy, later edits do not change what it makes.
  final TaskRecording Function() recording;
  final Map<String, Uint8List> assets;

  @override
  ConsumerState<TaskOutputsSection> createState() => _TaskOutputsSectionState();
}

class _TaskOutputsSectionState extends ConsumerState<TaskOutputsSection> {
  final Set<String> _busy = {};

  Future<void> _generate(TaskOutputGenerator generator) async {
    if (_busy.contains(generator.id)) return;
    final l10n = AppLocalizations.of(context);
    final request = TaskOutputRequest(
      recording: widget.recording(),
      languageCode: Localizations.localeOf(context).languageCode,
      assets: widget.assets,
    );
    setState(() => _busy.add(generator.id));
    TaskOutputResult result;
    try {
      result = await generator.generate(request);
    } catch (e, st) {
      TraceLogger.instance.warn(
        'recorder',
        'output ${generator.id} failed (${e.runtimeType})',
        stackTrace: st,
      );
      result = const TaskOutputFailed(TaskOutputReason.failed);
    }
    if (!mounted) return;
    setState(() => _busy.remove(generator.id));
    switch (result) {
      case TaskOutputProduced(:final bytes, :final suggestedName):
        await saveAndTell(context, ref, bytes: bytes, fileName: suggestedName);
      case TaskOutputNotProduced(:final reason):
      case TaskOutputFailed(:final reason):
        AppSnack.error(context, outputReasonText(l10n, reason));
      case TaskOutputCancelled():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final generators = ref.watch(taskOutputGeneratorsProvider);
    if (generators.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in generators)
          FutureBuilder<TaskOutputAvailability>(
            future: g.availability(),
            builder: (context, snapshot) {
              final l10n = AppLocalizations.of(context);
              final availability = snapshot.data;
              final why = availability is TaskOutputUnsupported
                  ? outputReasonText(l10n, availability.reason)
                  : null;
              return ListTile(
                key: ValueKey('task-output-${g.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(outputKindLabel(l10n, g.kind)),
                subtitle: why == null ? null : Text(why),
                trailing: FilledButton(
                  key: ValueKey('task-output-make-${g.id}'),
                  onPressed:
                      availability is TaskOutputAvailable &&
                          !_busy.contains(g.id)
                      ? () => _generate(g)
                      : null,
                  child: Text(l10n?.taskOutputMake ?? 'Make'),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// The words for an output's kind.
String outputKindLabel(AppLocalizations? l10n, TaskOutputKind kind) =>
    switch (kind) {
      TaskOutputKind.document => l10n?.taskOutputDocument ?? 'Word document',
      TaskOutputKind.storyboard => l10n?.taskOutputStoryboard ?? 'Storyboard',
      TaskOutputKind.video => l10n?.taskOutputVideo ?? 'Video',
      TaskOutputKind.captions => l10n?.taskOutputCaptions ?? 'Captions',
    };

/// The words for why an output was not made.
String outputReasonText(AppLocalizations? l10n, TaskOutputReason reason) =>
    switch (reason) {
      TaskOutputReason.unsupportedPlatform =>
        l10n?.taskOutputUnsupportedPlatform ?? 'Not available on this device.',
      TaskOutputReason.missingMedia =>
        l10n?.taskOutputMissingMedia ??
            'This task has no images or video to use.',
      TaskOutputReason.tooLong =>
        l10n?.taskOutputTooLong ?? 'This task is too long for this output.',
      TaskOutputReason.failed =>
        l10n?.taskOutputFailed ?? 'The output could not be made.',
    };
