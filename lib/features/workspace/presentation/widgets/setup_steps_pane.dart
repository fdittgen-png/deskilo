// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3629 (desk M10) — the setup guide's steps beside the page on the desk:
// what the space does first, then every step the space uses by the guide's
// groups, each with where it stands in the guide's own words and mark, and
// Launch last. With room it is a list with the progress said in words;
// with less, a rail of numbers whose tooltip names the step and its state.
// It reads the one status the guide reads: it adds no step and no state.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/dictionary_labels.dart';
import '../../domain/launch_review.dart';
import '../../domain/setup_status.dart';
import '../../providers/local_setup_providers.dart';
import '../../providers/workspace_providers.dart';
import '../setup_step_words.dart';

/// The guide's pages in the order the steps beside them list them: what
/// the space does, every step it uses, Launch. Each is its address under
/// `/setup` (`levels`, `step/<id>`, `launch`).
List<String> setupDeskSequence(SetupStatus status) => [
  'levels',
  for (final g in LaunchReview.from(status).groups)
    for (final s in g.steps) 'step/${s.step}',
  'launch',
];

class SetupStepsPane extends ConsumerWidget {
  const SetupStepsPane({
    required this.open,
    required this.rail,
    required this.onOpen,
    super.key,
  });

  /// The width of the list: a step's name and its state on one line each.
  static const double listWidth = 264;

  /// The width of the rail of numbers.
  static const double railWidth = 72;

  /// The page open beside it, by its address under `/setup`; null for the
  /// guide itself.
  final String? open;

  /// Numbers only.
  final bool rail;

  /// Opens a page by its address under `/setup`; null for the guide.
  final ValueChanged<String?> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspaceId = ref.watch(currentWorkspaceProvider).value?.id;
    final status = workspaceId == null
        ? null
        : ref.watch(workspaceSetupStatusProvider(workspaceId)).value;
    if (status == null) return const LoadingView();
    final groups = LaunchReview.from(status).groups;
    final steps = [for (final g in groups) ...g.steps];
    final done = steps.where((s) => s.state == SetupStepState.ready).length;
    var number = 0;
    Widget step(SetupStepStatus s) => _StepEntry(
      step: s,
      number: ++number,
      rail: rail,
      selected: open == 'step/${s.step}',
      onTap: () => onOpen('step/${s.step}'),
    );
    return Material(
      key: const ValueKey('setup-desk-steps'),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          _PageEntry(
            id: 'guide',
            icon: Icons.checklist_outlined,
            label: l10n.setupGuideTitle,
            detail: l10n.setupDeskProgress(done, steps.length),
            rail: rail,
            selected: open == null,
            onTap: () => onOpen(null),
          ),
          _PageEntry(
            id: 'levels',
            icon: Icons.tune_outlined,
            label: l10n.setupLevelsTitle,
            rail: rail,
            selected: open == 'levels',
            onTap: () => onOpen('levels'),
          ),
          for (final g in groups) ...[
            if (!rail) _GroupHeader(text: l10n.setupLaunchGroup(g.group.name)),
            for (final s in g.steps) step(s),
          ],
          _PageEntry(
            id: 'launch',
            icon: Icons.fact_check_outlined,
            label: l10n.setupLaunchLink,
            rail: rail,
            selected: open == 'launch',
            onTap: () => onOpen('launch'),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelLarge),
    ),
  );
}

/// The guide, what the space does, or Launch.
class _PageEntry extends StatelessWidget {
  const _PageEntry({
    required this.id,
    required this.icon,
    required this.label,
    required this.rail,
    required this.selected,
    required this.onTap,
    this.detail,
  });

  final String id;
  final IconData icon;
  final String label;

  /// Said under the label in the list; part of the rail's tooltip.
  final String? detail;
  final bool rail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => rail
      ? _RailEntry(
          key: ValueKey('setup-desk-$id'),
          label: [label, ?detail].join(' · '),
          selected: selected,
          onTap: onTap,
          child: Icon(icon),
        )
      : ListTile(
          key: ValueKey('setup-desk-$id'),
          leading: Icon(icon),
          title: Text(label),
          subtitle: detail == null
              ? null
              : Text(detail!, key: ValueKey('setup-desk-$id-detail')),
          selected: selected,
          onTap: onTap,
        );
}

/// A step: its mark, its name and where it stands.
class _StepEntry extends StatelessWidget {
  const _StepEntry({
    required this.step,
    required this.number,
    required this.rail,
    required this.selected,
    required this.onTap,
  });

  final SetupStepStatus step;
  final int number;
  final bool rail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = l10n.setupStepTitle(step.step);
    final word = setupStepWord(l10n, step);
    final key = ValueKey('setup-desk-step-${step.step}');
    if (rail) {
      return _RailEntry(
        key: key,
        label: _railLabel(number, title, word),
        selected: selected,
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$number'),
            const SizedBox(width: AppSpacing.xs),
            Icon(setupStepIcon(step.state), size: AppSpacing.md),
          ],
        ),
      );
    }
    return ListTile(
      key: key,
      dense: true,
      leading: Icon(setupStepIcon(step.state)),
      title: Text(title),
      subtitle: Text(word, key: ValueKey('setup-desk-state-${step.step}')),
      selected: selected,
      onTap: onTap,
    );
  }
}

/// "3. Opening hours · To do": what a number of the rail stands for.
String _railLabel(int n, String title, String word) => '$n. $title · $word';

/// One place of the rail: a mark the size of a finger, named by its
/// tooltip and to a screen reader.
class _RailEntry extends StatelessWidget {
  const _RailEntry({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  /// A finger's size (48 dp).
  static const double _height = 48;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        label: label,
        selected: selected,
        button: true,
        excludeSemantics: true,
        child: Material(
          color: selected ? scheme.secondaryContainer : Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: _height,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
