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
import '../../domain/workspace.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/setup_invite_step.dart';
import '../widgets/setup_member_rights_step.dart';

class SetupStepScreen extends ConsumerWidget {
  const SetupStepScreen({super.key, required this.stepId});

  /// The catalogue id of the step (`setup_steps.dart`).
  final String stepId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(currentWorkspaceProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.setupStepTitle(stepId))),
      body: workspace == null ? const LoadingView() : _page(workspace),
    );
  }

  Widget _page(Workspace workspace) => switch (stepId) {
    'member_rights' => SetupMemberRightsStep(workspace: workspace),
    'invite' => SetupInviteStep(workspace: workspace),
    _ => _Elsewhere(stepId: stepId),
  };
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
