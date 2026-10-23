// SPDX-License-Identifier: AGPL-3.0-or-later
//
// One step of the setup guide on its own page (`/setup/step/<id>`): the
// step's form beside "what your members will see". A step without a page
// of its own says so and opens the screen the catalogue names for it.
// Nothing here decides readiness: the server computes it from what the
// step applied, and the guide reads it again on the way back.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../domain/setup_steps.dart';
import '../../domain/site.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/setup_basics_step.dart';
import '../widgets/setup_grow_pages.dart';
import '../widgets/setup_hours_step.dart';
import '../widgets/setup_invite_step.dart';
import '../widgets/setup_look_step.dart';
import '../widgets/setup_member_rights_step.dart';
import '../widgets/setup_new_members_step.dart';
import '../widgets/setup_run_pages.dart';

class SetupStepScreen extends ConsumerWidget {
  const SetupStepScreen({
    super.key,
    required this.stepId,
    this.placesStep,
    this.runPages,
    this.growPages,
    this.moneyRecorded,
  });

  /// The catalogue id of the step (`setup_steps.dart`).
  final String stepId;

  /// Builds the places page. The plan feature owns it and sits above this
  /// one in the feature graph (`test/lint/feature_layers.yaml`), so the
  /// router hands the builder in; without it the step opens the editor.
  final SetupPlacesBuilder? placesStep;

  /// The Run steps' pages, handed in by the router for the same reason;
  /// without them those steps open their own screens.
  final SetupRunPages? runPages;

  /// The Grow steps' pages, handed in by the router for the same reason.
  final SetupGrowPages? growPages;

  /// Whether the space has issued a document or recorded money, which
  /// fixes its country and currency: the money feature reads it, so the
  /// router hands the read in; without it the basics page treats them as
  /// open and the server still refuses.
  final SetupMoneyRecorded? moneyRecorded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(currentWorkspaceProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.setupStepTitle(stepId))),
      body: workspace == null ? const LoadingView() : _page(ref, workspace),
    );
  }

  bool _moneyRecorded(WidgetRef ref, String workspaceId) =>
      moneyRecorded?.call(ref, workspaceId) ?? false;

  Widget _page(WidgetRef ref, Workspace workspace) => switch (stepId) {
    'basics' => SetupBasicsStep(
      workspace: workspace,
      moneyLocaleLocked: _moneyRecorded(ref, workspace.id),
    ),
    'hours' => const SetupHoursStep(),
    'places' => switch (placesStep) {
      final page? => _PlacesHost(page: page),
      null => _Elsewhere(stepId: stepId),
    },
    'member_rights' => SetupMemberRightsStep(workspace: workspace),
    'invite' => SetupInviteStep(workspace: workspace),
    'new_members' => SetupNewMembersStep(workspace: workspace),
    'look' => SetupLookStep(workspace: workspace),
    _ =>
      runPages?.pageFor(stepId, workspace) ??
          growPages?.pageFor(stepId, workspace) ??
          _Elsewhere(stepId: stepId),
  };
}

/// Watches whether the space [workspaceId] has recorded money.
typedef SetupMoneyRecorded = bool Function(WidgetRef ref, String workspaceId);

/// The places page from what this feature knows: the sites when there are
/// several (default first) and whether the library is on.
typedef SetupPlacesBuilder =
    Widget Function({
      required Map<String, String> sites,
      required bool libraryOn,
    });

class _PlacesHost extends ConsumerWidget {
  const _PlacesHost({required this.page});
  final SetupPlacesBuilder page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = ref.watch(enabledFeaturesSyncProvider);
    final List<Site> sites = features.contains(WorkspaceFeature.multiSite)
        ? ref.watch(sitesProvider).value ?? const []
        : const [];
    return page(
      sites: {if (sites.length > 1) for (final s in sites) s.id: s.name},
      libraryOn: features.contains(WorkspaceFeature.workspaceLibrary),
    );
  }
}

/// A step done on its own screen, or an id the catalogue does not know.
class _Elsewhere extends StatelessWidget {
  const _Elsewhere({required this.stepId});
  final String stepId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final route = setupSteps
        .where((s) => s.id == stepId)
        .map((s) => s.route)
        .firstOrNull;
    return ListView(
      padding: AppSpacing.lgAll,
      children: [
        InlineBanner(
          key: const ValueKey('setup-step-elsewhere'),
          icon: Icons.open_in_new,
          severity: InlineBannerSeverity.info,
          text: l10n.setupStepElsewhere,
          actionLabel: l10n.setupStepOpenScreen,
          onAction: () => context.pushReplacement(route ?? '/setup'),
        ),
      ],
    );
  }
}
