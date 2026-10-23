// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup step "places on the plan": every level, under its site when the
// space has several, with how many rooms, desks and seats it holds and the
// plan drawn by the app's own painter, read-only. The plan itself is drawn
// in the editor, or brought in from a template of the library. Beside them
// what a member finds to book, level by level.
//
// The workspace feature sits below this one in the feature graph, so it
// hands in what only it knows: the sites and whether the library is on.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/ui/setup_step_layout.dart';
import '../../domain/floor_plan.dart';
import '../../domain/level.dart';
import '../../providers/floor_plan_providers.dart';
import 'setup_bookable_places.dart';
import 'setup_plan_thumbnail.dart';

class SetupPlacesStep extends ConsumerWidget {
  const SetupPlacesStep({
    super.key,
    required this.sites,
    required this.libraryOn,
  });

  /// Site id → name when the space has several sites, the default first;
  /// empty when it has one.
  final Map<String, String> sites;

  /// Whether a template of the workspace library can start the plan.
  final bool libraryOn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levelsAsync = ref.watch(levelsProvider);
    final levels = levelsAsync.value;
    if (levels == null) {
      return levelsAsync.hasError ? const _LoadFailed() : const LoadingView();
    }
    final plans = <Level, FloorPlan?>{
      for (final level in levels)
        level: ref.watch(floorPlanProvider(level.id)).value,
    };
    return SetupStepLayout(
      form: _PlacesForm(plans: plans, sites: sites, libraryOn: libraryOn),
      preview: SetupBookablePlaces(plans: plans),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed();

  @override
  Widget build(BuildContext context) => Padding(
    padding: AppSpacing.lgAll,
    child: InlineBanner(
      key: const ValueKey('setup-places-failed'),
      icon: Icons.error_outline,
      text: context.l10n.setupStepLoadFailed,
    ),
  );
}

class _PlacesForm extends StatelessWidget {
  const _PlacesForm({
    required this.plans,
    required this.sites,
    required this.libraryOn,
  });

  /// Level → its plan; null while the plan loads.
  final Map<Level, FloorPlan?> plans;

  /// Site id → name when there are several, default first; else empty.
  final Map<String, String> sites;
  final bool libraryOn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final levels = plans.keys.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.setupStepHint('places')),
        const SizedBox(height: AppSpacing.md),
        if (levels.isEmpty)
          Text(l10n.setupPlacesEmpty, key: const ValueKey('setup-places-empty'))
        else if (sites.isEmpty)
          for (final level in levels) _LevelCard(level, plans[level])
        else
          for (final MapEntry(key: id, value: name) in sites.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                name,
                key: ValueKey('setup-places-site-$id'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final level in levels.where((l) => _siteOf(l) == id))
              _LevelCard(level, plans[level]),
          ],
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton(
              key: const ValueKey('setup-places-open-editor'),
              onPressed: () => context.push('/editor'),
              child: Text(l10n.setupPlacesOpenEditor),
            ),
            if (libraryOn)
              OutlinedButton(
                key: const ValueKey('setup-places-template'),
                onPressed: () => context.push('/library'),
                child: Text(l10n.setupPlacesFromTemplate),
              ),
          ],
        ),
      ],
    );
  }

  /// A level without a known site stands at the default one, listed
  /// first (#945).
  String _siteOf(Level level) =>
      sites.containsKey(level.siteId) ? level.siteId! : sites.keys.first;
}

class _LevelCard extends StatelessWidget {
  const _LevelCard(this.level, this.plan);

  final Level level;
  final FloorPlan? plan;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final plan = this.plan;
    return Card(
      key: ValueKey('setup-places-level-${level.id}'),
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(level.name, style: Theme.of(context).textTheme.titleSmall),
            if (plan == null)
              const LoadingView()
            else ...[
              Text(
                l10n.setupPlacesCounts(
                  plan.offices.length,
                  plan.desks.length,
                  plan.seats.length,
                ),
                key: ValueKey('setup-places-counts-${level.id}'),
              ),
              const SizedBox(height: AppSpacing.sm),
              SetupPlanThumbnail(plan: plan, levelName: level.name),
            ],
          ],
        ),
      ),
    );
  }
}
