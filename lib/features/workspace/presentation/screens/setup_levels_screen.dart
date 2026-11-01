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
// space's country asks, from the tax reference data. Each level can be
// seen in the demo's complete space, except from inside the demo.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/demo/demo_link.dart';
import '../../../../core/demo/presentation/demo_workspace.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/links/link_launcher.dart';
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
import '../../domain/setup_level_demo.dart';
import '../../domain/setup_levels.dart';
import '../../domain/setup_step_reach.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/local_setup_providers.dart';
import '../../providers/workspace_providers.dart';
import '../feature_copy.dart';
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

  /// Questions the owner left at "not sure yet": answered no for now.
  final _unknown = <String>{};
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
    final stored = resolveEnabledFeatures(workspace.featureFlags);
    final current = currentSetupLevels(stored);
    final saved = _restoreOnce(journey, current);
    final recommended = recommendSetupLevels(_answers);
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
                ? l10n.setupReason(recommended[p]!.reason)
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
  /// once a conflict reloaded it. Without one, the questions open from what
  /// the space already does (#3076).
  SetupJourney? _restoreOnce(
    AsyncValue<SetupJourney?> journey,
    SetupLevelVector current,
  ) {
    final saved = journey.value;
    if (!_restored && journey.hasValue && !journey.isLoading) {
      _restored = true;
      _unknown.clear();
      _answers = saved?.answers ?? setupAnswersFromLevels(current);
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
    for (final key in setupQuestions) ...[
      SwitchListTile(
        key: ValueKey('setup-question-$key'),
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.setupQuestion(key)),
        value: _answers[key],
        onChanged: (v) => _answer(key, yes: v),
      ),
      // #3076 — the third answer: the safe level, and what stays there.
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: FilterChip(
          key: ValueKey('setup-question-$key-unknown'),
          label: Text(l10n.setupAnswerUnknown),
          selected: _unknown.contains(key),
          onSelected: (on) => _answer(key, yes: false, unknown: on),
        ),
      ),
      if (_unknown.contains(key))
        Text(
          _unknownNote(l10n, key),
          key: ValueKey('setup-question-$key-note'),
        ),
    ],
  ];

  void _answer(String key, {required bool yes, bool unknown = false}) =>
      setState(() {
        _answers = _answers.withAnswer(key, yes: yes);
        _answered = true;
        unknown ? _unknown.add(key) : _unknown.remove(key);
        _chosen.clear();
      });

  /// The processes a yes would raise, at the level they stay at for now.
  String _unknownNote(AppLocalizations l10n, String question) {
    final yes = recommendSetupLevels(_answers.withAnswer(question, yes: true));
    final no = recommendSetupLevels(_answers.withAnswer(question, yes: false));
    return l10n.setupAnswerUnknownNote(
      [
        for (final p in SetupProcess.values)
          if (yes[p]!.level != no[p]!.level)
            '${l10n.setupProcessName(p.name)}: ${_levelWord(l10n, p, no[p]!.level)}',
      ].join(', '),
    );
  }

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

/// One process: its name, the reason for its level, the level, and where
/// the demo shows it.
class _ProcessLevel extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final demo = DemoEnvironment.maybeOf(context) != null
        ? null
        : setupLevelDemoRoute(process, level);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.setupProcessName(process.name)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reason != null) Text(reason!),
          if (demo != null)
            TextButton(
              key: ValueKey('setup-level-demo-${process.name}'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () =>
                  ref.read(linkLauncherProvider)(demoLinkUri(to: demo)),
              child: Text(l10n.setupLevelsSeeDemo),
            ),
        ],
      ),
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
    // #3076 — what the space gets, in the member-facing words of the
    // manifest, never the switches' own names.
    List<Widget> outcomes(
      String heading,
      List<WorkspaceFeature> fs,
      Key key,
    ) => [
      Text(heading, key: key, style: Theme.of(context).textTheme.titleSmall),
      for (final f in fs)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text('• ${featureDescription(l10n, f)}'),
        ),
    ];
    return Card(
      key: const ValueKey('setup-levels-preview'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (change.isEmpty) Text(l10n.setupLevelsNoChange),
            if (change.switchOn.isNotEmpty)
              ...outcomes(
                l10n.setupLevelsSwitchOn,
                change.switchOn,
                const ValueKey('setup-levels-on'),
              ),
            if (setupStepsFor(change.switchOn) case final steps
                when steps.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.setupLevelsStepsFollow(
                  steps.map((s) => l10n.setupStepTitle(s.id)).join(', '),
                ),
                key: const ValueKey('setup-levels-steps'),
              ),
            ],
            if (change.switchOff.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              ...outcomes(
                l10n.setupLevelsSwitchOff,
                change.switchOff,
                const ValueKey('setup-levels-off'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
