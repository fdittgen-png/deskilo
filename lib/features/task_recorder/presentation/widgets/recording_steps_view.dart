// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865/#1872 — a recording's steps as the person reads them, with a
// "leave out" toggle per step. One widget for the private review and the
// workbench, so a step reads the same wherever it is shown.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/action_registry.dart';
import '../../domain/task_recording.dart';
import '../../guide/guide_compiler.dart';
import '../../guide/guide_session.dart';
import '../../guide/task_guide.dart';
import '../recorder_labels.dart';
import '../guide_host/guide_step_text.dart' show guideDestinationLabel;

class RecordingStepsView extends StatelessWidget {
  const RecordingStepsView({
    super.key,
    required this.recording,
    required this.leftOut,
    required this.onToggle,
  });

  final TaskRecording recording;
  final Set<int> leftOut;
  final void Function(int seq) onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final steps = recording.steps;
    final answered = {
      for (final s in steps)
        if (s.kind == StepKind.observation && s.op != null) s.op,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0 && steps[i - 1].segment != steps[i].segment)
            _Gap(label: l10n?.taskRecorderSegmentGap ?? 'Paused here'),
          _StepTile(
            step: steps[i],
            answered: !steps[i].isAttempt || answered.contains(steps[i].op),
            leftOut: leftOut.contains(steps[i].seq),
            onToggle: () => onToggle(steps[i].seq),
          ),
        ],
        if (leftOut.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n?.taskRecorderEditedNote(leftOut.length) ??
                'Edited copy: ${leftOut.length} steps left out.',
            key: const ValueKey('task-recording-edited-note'),
          ),
        ],
      ],
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

class _StepTile extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detail.isNotEmpty) Text(detail, style: style),
          if (step.page != null)
            TextButton.icon(
              key: ValueKey('task-step-reference-${step.seq}'),
              onPressed: GoRouter.maybeOf(context) == null
                  ? null
                  : () {
                      final compiled = compileGuide(
                        TaskRecording(
                          actionContractVersion: actionContractVersion,
                          platform: RecordingPlatform.unknown,
                          steps: [step],
                          segments: const [],
                        ),
                      );
                      // A result or window event still has a form reference.
                      final guide = compiled.steps.isNotEmpty
                          ? compiled
                          : TaskGuide(
                              actionContractVersion: actionContractVersion,
                              steps: [
                                GuideStep(
                                  id: 'g1',
                                  kind: GuideStepKind.instruction,
                                  text: text.title,
                                  destination: step.page,
                                ),
                              ],
                            );
                      ref.read(guideSessionProvider.notifier).start(guide);
                      GoRouter.of(context).go(step.page!);
                    },
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(guideDestinationLabel(l10n, step.page!)),
            ),
        ],
      ),
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
