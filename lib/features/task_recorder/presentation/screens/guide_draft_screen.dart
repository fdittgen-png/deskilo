// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1867 — the guide draft editor, inside the local workbench.
//
// The author sees each step as the reader will, writes the words of
// instructions and manual steps, marks steps optional, and saves the
// guide as a file. Actions, expected outcomes and recovery come from the
// compiler and are not editable here: a draft cannot be made to expect
// an outcome its action does not have, or to skip a command silently.
// Showing a guide on a live form (the help host, tankstellen#4480) and
// publishing it (#1859) are not part of this screen.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../guide/guide_codec.dart';
import '../../guide/task_guide.dart';
import '../recorder_labels.dart';
import '../recording_export.dart';

class GuideDraftScreen extends ConsumerStatefulWidget {
  const GuideDraftScreen({super.key, required this.guide});

  final TaskGuide guide;

  @override
  ConsumerState<GuideDraftScreen> createState() => _GuideDraftScreenState();
}

class _GuideDraftScreenState extends ConsumerState<GuideDraftScreen> {
  late List<GuideStep> _steps = widget.guide.steps;

  TaskGuide get _guide => TaskGuide(
    actionContractVersion: widget.guide.actionContractVersion,
    title: widget.guide.title,
    sourceDigest: widget.guide.sourceDigest,
    steps: _steps,
  );

  void _replace(GuideStep step) => setState(() {
    _steps = [for (final s in _steps) s.id == step.id ? step : s];
  });

  Future<void> _editText(GuideStep step) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(initial: step.text ?? ''),
    );
    if (text == null) return;
    final clean = text.trim();
    _replace(
      GuideStep(
        id: step.id,
        kind: step.kind,
        action: step.action,
        expectedOutcomes: step.expectedOutcomes,
        text: clean.isEmpty ? null : clean,
        optional: step.optional,
        recovery: step.recovery,
        manualCategory: step.manualCategory,
      ),
    );
  }

  Future<void> _save() async {
    final text = encodeGuideText(_guide);
    final valid = decodeGuideText(text).accepted;
    await saveAndTell(
      context,
      ref,
      bytes: valid ? Uint8List.fromList(utf8.encode(text)) : null,
      fileName: 'deskilo-guide.json',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n?.taskGuideTitle ?? 'Guide draft')),
      body: ListView(
        padding: AppSpacing.gutterAll,
        children: [
          Text(
            l10n?.taskGuideIntro ??
                'Each step as a reader will follow it. A step that books '
                    'waits for the real answer; nothing here is done for '
                    'the reader.',
          ),
          const SizedBox(height: AppSpacing.md),
          for (final step in _steps)
            _StepCard(
              step: step,
              onEdit: step.kind == GuideStepKind.perform
                  ? null
                  : () => _editText(step),
              onOptional: (v) => _replace(step.copyWith(optional: v)),
            ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            key: const ValueKey('guide-save'),
            onPressed: _save,
            icon: const Icon(Icons.download),
            label: Text(l10n?.taskGuideSave ?? 'Save the guide'),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.onEdit,
    required this.onOptional,
  });

  final GuideStep step;
  final VoidCallback? onEdit;
  final ValueChanged<bool> onOptional;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = guideStepTitle(l10n, step);
    final waits = step.isCommand
        ? l10n?.taskGuideWaitsFor(
                step.expectedOutcomes
                    .map((o) => outcomeLabel(l10n, o) ?? o)
                    .join(' / '),
              ) ??
              'Waits for: ${step.expectedOutcomes.join(' / ')}'
        : null;
    final recovery = step.recovery.isEmpty
        ? null
        : l10n?.taskGuideRecovery ??
              'If it is refused: choose another place, day or period, then '
                  'confirm again.';
    return Card(
      key: ValueKey('guide-step-${step.id}'),
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    key: ValueKey('guide-edit-${step.id}'),
                    tooltip: l10n?.taskGuideEditText ?? 'Write the words',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: onEdit,
                  ),
              ],
            ),
            if (step.kind == GuideStepKind.perform && step.text != null)
              Text(step.text!),
            ?(waits == null ? null : Text(waits)),
            ?(recovery == null ? null : Text(recovery)),
            SwitchListTile(
              key: ValueKey('guide-optional-${step.id}'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n?.taskGuideOptional ?? 'The reader may skip it'),
              value: step.optional,
              onChanged: onOptional,
            ),
          ],
        ),
      ),
    );
  }
}

/// A guide step as the reader reads it.
String guideStepTitle(AppLocalizations? l10n, GuideStep step) =>
    switch (step.kind) {
      GuideStepKind.perform =>
        actionLabel(l10n, step.action) ??
            (l10n?.taskRecorderStepUnrecorded ??
                'A step the recorder cannot describe'),
      GuideStepKind.instruction =>
        step.text ??
            (l10n?.taskGuideNoText ?? 'An instruction still to be written'),
      GuideStepKind.manual =>
        step.text ??
            (step.manualCategory == null
                ? (l10n?.taskGuideManual ?? 'Do this step yourself')
                : (l10n?.taskGuideManualProtected(
                        protectedLabel(l10n, step.manualCategory!),
                      ) ??
                      'Do this step yourself, on a protected screen')),
    };

class _TextDialog extends StatefulWidget {
  const _TextDialog({required this.initial});

  final String initial;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _text = TextEditingController(text: widget.initial);

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
      title: Text(l10n?.taskGuideEditText ?? 'Write the words'),
      content: TextField(
        key: const ValueKey('guide-text-field'),
        controller: _text,
        autofocus: true,
        maxLines: 4,
        maxLength: const GuideLimits().maxTextLength,
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
