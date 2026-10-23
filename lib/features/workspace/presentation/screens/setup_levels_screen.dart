// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2868 (ADR 0047 §3) — what the space does, from plain questions: each
// process gets the level the answers call for, with the reason in words;
// a quick start sets them all at once; any level can be changed by hand.
// Until the owner answers, every process stays at what the space does
// now; the preview names every feature the choice switches on and off,
// only the processes whose level changes take part, and switching
// anything off asks first. Applying also remembers the answers and the
// levels on the server (workspace_setup_journeys), so the screen reopens
// with them on any device; beside the questions, what the law of the
// space's country asks, from the tax reference data.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/process_activation.dart';
import '../../application/setup_journey_save.dart';
import '../../domain/feature_flags_write.dart';
import '../../domain/setup_journey.dart';
import '../../domain/setup_level_change.dart';
import '../../domain/setup_levels.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/local_setup_providers.dart';
import '../../providers/workspace_providers.dart';
import '../feature_names.dart';
import '../widgets/setup_obligations_card.dart';

class SetupLevelsScreen extends ConsumerStatefulWidget {
  const SetupLevelsScreen({super.key});

  @override
  ConsumerState<SetupLevelsScreen> createState() => _SetupLevelsScreenState();
}

String _levelWord(AppLocalizations l10n, SetupProcess p, String level) =>
    l10n.setupLevelName('${p.name}_$level');

/// `tax.vat → money.invoices` in the reader's words.
String _gapWords(AppLocalizations l10n, String gap) {
  final [from, to] = gap.split(' → ');
  String words(String pair) {
    final [process, level] = pair.split('.');
    final p = SetupProcess.values.byName(process);
    return '${l10n.setupProcessName(process)}: ${_levelWord(l10n, p, level)}';
  }

  return l10n.setupLevelsGap(words(from), words(to));
}

class _SetupLevelsScreenState extends ConsumerState<SetupLevelsScreen> {
  var _answers = const SetupAnswers();

  /// Until the owner answers, every process stays at what the space does.
  var _answered = false;

  /// The saved answers were taken over once; a later save does not
  /// overwrite what the owner is answering.
  var _restored = false;

  /// Levels the owner set by hand or by a quick start; the rest follow
  /// the recommendation.
  final _chosen = <SetupProcess, String>{};
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final workspace = ref.watch(currentWorkspaceProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.setupLevelsTitle)),
      body: workspace == null ? const LoadingView() : _body(l10n, workspace),
    );
  }

  Widget _body(AppLocalizations l10n, Workspace workspace) {
    final journey = ref.watch(setupJourneyProvider(workspace.id));
    if (journey case AsyncLoading(hasValue: false)) return const LoadingView();
    final saved = _restoreOnce(journey);
    final stored = resolveEnabledFeatures(workspace.featureFlags);
    final recommended = recommendSetupLevels(_answers);
    final current = currentSetupLevels(stored);
    final vector = {
      for (final p in SetupProcess.values)
        p: _chosen[p] ?? (_answered ? recommended[p]!.level : current[p]!),
    };
    final change = planSetupLevels(
      stored: stored,
      current: current,
      chosen: vector,
    );
    final gaps = setupVectorGaps(vector);
    final nothingToApply = _nothingToApply(change, saved, vector);
    final title = Theme.of(context).textTheme.titleMedium;
    return ListView(
      key: const ValueKey('setup-levels'),
      padding: AppSpacing.gutterAll,
      children: [
        Text(l10n.setupLevelsIntro),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.setupLevelsQuestions, style: title),
        ..._questions(l10n, saved),
        SetupObligationsCard(country: workspace.countryCode),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.setupLevelsPresets, style: title),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final preset in SetupPreset.values)
              ActionChip(
                key: ValueKey('setup-preset-${preset.name}'),
                label: Text(l10n.setupPresetName(preset.name)),
                onPressed: () => setState(() {
                  _chosen
                    ..clear()
                    ..addAll(setupPresets[preset]!);
                }),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.setupLevelsChoice, style: title),
        for (final p in SetupProcess.values)
          _ProcessLevel(
            key: ValueKey('setup-process-${p.name}'),
            process: p,
            level: vector[p]!,
            reason: vector[p] == recommended[p]!.level
                ? l10n.setupLevelsBecause(
                    l10n.setupReason(recommended[p]!.reason),
                  )
                : null,
            onChanged: (level) => setState(() => _chosen[p] = level),
          ),
        for (final gap in gaps)
          InlineBanner(icon: Icons.link_off, text: _gapWords(l10n, gap)),
        const SizedBox(height: AppSpacing.md),
        _Preview(change: change),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton(
            key: const ValueKey('setup-levels-apply'),
            onPressed: nothingToApply || gaps.isNotEmpty || _busy
                ? null
                : () => _apply(workspace, change, vector, saved?.version),
            child: Text(l10n.setupLevelsApply),
          ),
        ),
      ],
    );
  }

  /// The saved journey; its answers are taken over once loaded, and again
  /// once a conflict reloaded it.
  SetupJourney? _restoreOnce(AsyncValue<SetupJourney?> journey) {
    final saved = journey.value;
    if (!_restored && journey.hasValue && !journey.isLoading) {
      _restored = true;
      if (saved != null) _answers = saved.answers;
    }
    return saved;
  }

  /// Whether applying would change nothing: no feature, and nothing new to
  /// remember — the answers are kept with what they led to, also when the
  /// space already does it.
  bool _nothingToApply(
    SetupLevelChange change,
    SetupJourney? saved,
    SetupLevelVector vector,
  ) =>
      change.isEmpty &&
      !((_answered || _chosen.isNotEmpty) &&
          (saved == null ||
              saved.answers != _answers ||
              SetupProcess.values.any((p) => saved.levels[p] != vector[p])));

  /// Who saved the answers last, and each question with its answer.
  List<Widget> _questions(AppLocalizations l10n, SetupJourney? saved) => [
    if (saved?.updatedByName case final String name)
      Text(l10n.setupJourneySavedBy(name)),
    for (final key in setupQuestions)
      SwitchListTile(
        key: ValueKey('setup-question-$key'),
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.setupQuestion(key)),
        value: _answers[key],
        onChanged: (v) => setState(() {
          _answers = _answers.withAnswer(key, yes: v);
          _answered = true;
          _chosen.clear();
        }),
      ),
  ];

  Future<void> _apply(
    Workspace workspace,
    SetupLevelChange change,
    SetupLevelVector vector,
    int? journeyVersion,
  ) async {
    final l10n = context.l10n;
    if (change.switchOff.isNotEmpty && !await _confirmOff(l10n)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    await runGuarded(
      context,
      domain: 'workspace',
      message: 'setup levels apply failed',
      action: () async {
        try {
          await applySetupLevels(
            ref,
            workspaceId: workspace.id,
            change: change,
          );
          await saveSetupJourney(
            ref,
            workspaceId: workspace.id,
            answers: _answers,
            levels: vector,
            expectedVersion: journeyVersion,
          );
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.setupLevelsApplied)),
          );
          // The space now does what was chosen: the levels read from it.
          _answered = false;
          _chosen.clear();
        } on SetupJourneyConflict {
          // The features are applied; the answers someone else saved are
          // shown instead of these, never overwritten.
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.setupJourneyConflict)),
          );
          _restored = false;
          _answered = false;
          _chosen.clear();
        } on FeatureFlagsConflict {
          // Nothing was written: the owner looks again at what is there.
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.setupLevelsConflict)),
          );
          ref.invalidate(myWorkspacesProvider);
        }
      },
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<bool> _confirmOff(AppLocalizations l10n) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: const ValueKey('setup-levels-confirm-off'),
          content: Text(l10n.setupLevelsConfirmOff),
          actions: [
            TextButton(
              key: const ValueKey('setup-levels-confirm-off-no'),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              key: const ValueKey('setup-levels-confirm-off-yes'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.setupLevelsApply),
            ),
          ],
        ),
      ) ??
      false;
}

/// One process: its name, the reason for its level, and the level.
class _ProcessLevel extends StatelessWidget {
  const _ProcessLevel({
    super.key,
    required this.process,
    required this.level,
    required this.reason,
    required this.onChanged,
  });

  final SetupProcess process;
  final String level;
  final String? reason;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.setupProcessName(process.name)),
      subtitle: reason == null ? null : Text(reason!),
      trailing: DropdownButton<String>(
        key: ValueKey('setup-level-${process.name}'),
        value: level,
        onChanged: (v) => v == null ? null : onChanged(v),
        items: [
          for (final l in setupLevels[process]!)
            DropdownMenuItem(
              key: ValueKey('setup-level-${process.name}-${l.id}'),
              value: l.id,
              child: Text(_levelWord(l10n, process, l.id)),
            ),
        ],
      ),
    );
  }
}

/// What applying would switch on and off, every feature by name.
class _Preview extends StatelessWidget {
  const _Preview({required this.change});
  final SetupLevelChange change;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String names(List<WorkspaceFeature> fs) =>
        fs.map((f) => featureName(l10n, f)).join(', ');
    return Card(
      key: const ValueKey('setup-levels-preview'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (change.isEmpty) Text(l10n.setupLevelsNoChange),
            if (change.switchOn.isNotEmpty)
              Text(
                l10n.setupLevelsSwitchOn(names(change.switchOn)),
                key: const ValueKey('setup-levels-on'),
              ),
            if (change.switchOff.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.setupLevelsSwitchOff(names(change.switchOff)),
                key: const ValueKey('setup-levels-off'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
