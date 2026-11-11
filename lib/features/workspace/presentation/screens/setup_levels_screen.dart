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
import '../../../../core/demo/presentation/demo_entry_sheet.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/dictionary_labels.dart';
import '../../application/process_activation.dart';
import '../../application/setup_journey_save.dart';
import '../../domain/feature_flags_write.dart';
import '../../domain/setup_candidate.dart';
import '../../domain/setup_journey.dart';
import '../../domain/setup_level_change.dart';
import '../../domain/setup_levels.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/held_setup_choices.dart';
import '../../providers/local_setup_providers.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/setup_choices_bar.dart';
import '../widgets/setup_held_notes.dart';
import '../widgets/setup_level_preview.dart';
import '../widgets/setup_obligations_card.dart';
import '../widgets/setup_process_choice.dart';

class SetupLevelsScreen extends ConsumerStatefulWidget {
  const SetupLevelsScreen({super.key});

  @override
  ConsumerState<SetupLevelsScreen> createState() => _SetupLevelsScreenState();
}

/// `tax.vat → money.invoices` in the reader's words.
String _gapWords(AppLocalizations l10n, String gap) {
  final [from, to] = gap.split(' → ');
  String words(String pair) {
    final [process, level] = pair.split('.');
    final p = SetupProcess.values.byName(process);
    return '${l10n.setupProcessName(process)}: ${l10n.setupLevelName('${p.name}_$level')}';
  }

  return l10n.setupLevelsGap(words(from), words(to));
}

class _SetupLevelsScreenState extends ConsumerState<SetupLevelsScreen> {
  var _answers = const SetupAnswers();

  /// Until the owner answers, every process stays at what the space does.
  var _answered = false;
  final _touched = <String>{}; // answered since the last apply or reset

  /// The saved answers were taken over once; a later save does not
  /// overwrite what the owner is answering.
  var _restored = false;

  /// Levels the owner set by hand or by a quick start; the rest follow
  /// the recommendation.
  final _chosen = <SetupProcess, String>{};

  /// Unresolved answers keep their previous value and cannot be applied.
  final _unknown = <String>{};
  var _busy = false;
  final _reviewKey = GlobalKey();

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
    final country = workspace.countryCode;
    final current = currentSetupLevels(stored, country: country);
    final saved = _restoreOnce(journey, current, workspace.id);
    // #3702 — places-aware; one answer recomputes only what it names.
    final books = current[SetupProcess.bookings] != 'none';
    final recommended = recommendSetupLevels(_answers, booksPlaces: books);
    final checked = setupCandidate(
      current: current,
      recommended: recommended,
      chosen: _chosen,
      touched: _touched,
      answered: _answered,
    );
    final (:vector, :held) = checked;
    final change = planSetupLevels(
      stored: stored,
      current: current,
      chosen: vector,
      country: country,
    );
    final gaps = setupVectorGaps(vector);
    final nothingToApply = _nothingToApply(change, saved, vector);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('setup-levels'),
            padding: AppSpacing.gutterAll,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  workspace.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(l10n.setupLevelsIntro),
                if (saved?.updatedByName case final String name)
                  Text(l10n.setupJourneySavedBy(name)),
                const SizedBox(height: AppSpacing.md),
                _questionGroup(
                  l10n,
                  'bookings',
                  l10n.setupChoicesBookings,
                  const [
                    'approve_bookings',
                    'several_rooms_or_sites',
                    'public_page',
                  ],
                  open: true,
                ),
                _questionGroup(l10n, 'money', l10n.setupChoicesMoney, const [
                  'members_owe_money',
                  'issue_invoices',
                  'pay_online',
                  'vat_registered',
                ]),
                _questionGroup(
                  l10n,
                  'operations',
                  l10n.setupChoicesOperations,
                  const [
                    'association',
                    'keep_books',
                    'tracks_purchases',
                    'door_tablet',
                    'organised',
                  ],
                ),
                ExpansionTile(
                  key: const ValueKey('setup-choice-guidance'),
                  title: Text(l10n.setupGuidanceTitle),
                  children: [
                    SetupObligationsCard(country: workspace.countryCode),
                  ],
                ),
                _advanced(l10n, vector, recommended, workspace.id),
                for (final gap in gaps)
                  InlineBanner(
                    icon: Icons.link_off,
                    text: _gapWords(l10n, gap),
                  ),
                ...setupHeldNotes(held, vector, (String gap) => _gapWords(l10n, gap)),
                Container(
                  key: _reviewKey,
                  child: SetupLevelPreview(change: change),
                ),
              ],
            ),
          ),
        ),
        SetupChoicesBar(
          workspaceName: workspace.name,
          changeCount: change.flags.length,
          unchanged: nothingToApply,
          unresolved: _unknown.isNotEmpty,
          busy: _busy,
          disabled: gaps.isNotEmpty,
          onReview: () => Scrollable.ensureVisible(_reviewKey.currentContext!),
          onApply: () => _apply(workspace, change, vector, saved?.version),
        ),
      ],
    );
  }

  Widget _questionGroup(
    AppLocalizations l10n,
    String id,
    String title,
    List<String> questions, {
    bool open = false,
  }) => Card(
    child: ExpansionTile(
      key: ValueKey('setup-questions-$id'),
      initiallyExpanded: open,
      title: Text(title),
      leading: Icon(switch (id) {
        'bookings' => Icons.calendar_month_outlined,
        'money' => Icons.payments_outlined,
        _ => Icons.settings_outlined,
      }),
      subtitle: questions.any(_unknown.contains)
          ? Text(
              questions
                  .where(_unknown.contains)
                  .map(l10n.setupQuestion)
                  .join(' · '),
            )
          : null,
      childrenPadding: AppSpacing.mdAll,
      children: _questions(l10n, questions),
    ),
  );

  Widget _advanced(
    AppLocalizations l10n,
    SetupLevelVector vector,
    Map<SetupProcess, SetupRecommendation> recommended,
    String workspaceId,
  ) => ExpansionTile(
    key: const ValueKey('setup-choices-advanced'),
    title: Text(l10n.setupChoicesAdvanced),
    children: [
      Text(l10n.setupLevelsPresets),
      Wrap(
        spacing: AppSpacing.sm,
        children: [
          for (final preset in SetupPreset.values)
            ActionChip(
              key: ValueKey('setup-preset-${preset.name}'),
              label: Text(l10n.setupPresetName(preset.name)),
              onPressed: _busy ? null : () => _choose(setupPresets[preset]),
            ),
        ],
      ),
      if (_chosen.isNotEmpty) ...[
        Text(l10n.setupChoicesManual),
        TextButton(
          key: const ValueKey('setup-choices-reset'),
          onPressed: _busy ? null : () => _choose(null),
          child: Text(l10n.setupChoicesReset),
        ),
      ],
      for (final p in SetupProcess.values)
        SetupProcessChoice(
          key: ValueKey('setup-process-${p.name}'),
          process: p,
          level: vector[p]!,
          reason: vector[p] == recommended[p]!.level
              ? l10n.setupReason(recommended[p]!.reason)
              : null,
          onChanged: (level) {
            if (!_busy) setState(() => _chosen[p] = level);
          },
          onSeeDemo: (route) async {
            if (!_busy) await _seeDemo(route, workspaceId);
          },
        ),
    ],
  );

  void _choose(SetupLevelVector? levels) => setState(() {
    _chosen
      ..clear()
      ..addAll(levels ?? {});
    if (levels == null) _answered = true;
    if (levels == null) _touched.addAll(setupQuestions);
  });

  /// The saved journey; its answers are taken over once loaded, and again
  /// once a conflict reloaded it. Without one, the questions open from what
  /// the space already does (#3076).
  SetupJourney? _restoreOnce(
    AsyncValue<SetupJourney?> journey,
    SetupLevelVector current,
    String workspaceId,
  ) {
    final saved = journey.value;
    if (!_restored && journey.hasValue && !journey.isLoading) {
      _restored = true;
      _unknown.clear();
      _answers = saved?.answers ?? setupAnswersFromLevels(current);
      if (saved != null) {
        final suggested = recommendSetupLevels(
          saved.answers,
          booksPlaces: current[SetupProcess.bookings] != 'none',
        );
        for (final p in SetupProcess.values) {
          final level = saved.levels[p];
          if (level != null &&
              current[p] == level &&
              level != suggested[p]!.level) {
            _chosen[p] = level;
          }
        }
      }
      // #3235 — back from the demo example: what was not applied yet.
      final held = _held(workspaceId);
      if (held != null) {
        _answers = held.answers;
        _answered = held.answered;
        if (held.answered) _touched.addAll(setupQuestions);
        _chosen
          ..clear()
          ..addAll(held.chosen);
        _unknown
          ..clear()
          ..addAll(held.unknown);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(heldSetupChoicesControllerProvider.notifier).clear();
          }
        });
      }
    }
    return saved;
  }

  HeldSetupChoices? _held(String workspaceId) => ref
      .read(heldSetupChoicesControllerProvider.notifier)
      .heldFor(ref.read(currentAccountIdProvider), workspaceId);

  /// #3235 — opens the demo example of a level. The answers that are not
  /// applied yet are held for the way back, once the visitor agreed; the
  /// visit applies nothing and writes nothing.
  Future<void> _seeDemo(String route, String workspaceId) async {
    final user = ref.read(currentAccountIdProvider);
    await offerDemoEntry(
      context,
      ref,
      link: DemoLink.example(to: route),
      beforeEnter: () => user == null
          ? null
          : ref
                .read(heldSetupChoicesControllerProvider.notifier)
                .hold(
                  HeldSetupChoices(
                    userId: user,
                    workspaceId: workspaceId,
                    answers: _answers,
                    answered: _answered,
                    chosen: Map.of(_chosen),
                    unknown: Set.of(_unknown),
                  ),
                ),
    );
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
  List<Widget> _questions(AppLocalizations l10n, List<String> questions) => [
    for (final key in questions) ...[
      SwitchListTile(
        key: ValueKey('setup-question-$key'),
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.setupQuestion(key)),
        value: _answers[key],
        onChanged: _busy ? null : (v) => _answer(key, yes: v),
        subtitle: _unknown.contains(key) ? Text(l10n.setupAnswerUnknown) : null,
      ),
      // #3076 — the third answer: the safe level, and what stays there.
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: FilterChip(
          key: ValueKey('setup-question-$key-unknown'),
          label: Text(l10n.setupAnswerUnknown),
          selected: _unknown.contains(key),
          tooltip: l10n.setupChoicesQuestionUnknown(l10n.setupQuestion(key)),
          onSelected: _busy
              ? null
              : (on) => _answer(key, yes: _answers[key], unknown: on),
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
        if (!unknown) _answers = _answers.withAnswer(key, yes: yes);
        _answered = true;
        _touched.add(key);
        unknown ? _unknown.add(key) : _unknown.remove(key);
      });

  String _unknownNote(AppLocalizations l10n, String question) =>
      l10n.setupChoicesNeedsDecision;

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
          _touched.clear();
          _chosen.clear();
        } on SetupJourneyConflict {
          // The features are applied; the answers someone else saved are
          // shown instead of these, never overwritten.
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.setupJourneyConflict)),
          );
          _restored = false;
          _answered = false;
          _touched.clear();
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
