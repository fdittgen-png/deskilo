// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2869 (ADR 0047 §6) — with the setup guide on, one compact banner takes
// the place of the two settings cards: the next milestone, how far the
// space is from it, the next step, and Resume. Nothing once every milestone
// the owner chose is reached.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../providers/local_setup_providers.dart';

class SetupResumeBanner extends ConsumerWidget {
  const SetupResumeBanner({super.key, required this.workspaceId});
  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = ref.watch(workspaceSetupStatusProvider(workspaceId)).value;
    final milestone = status?.nextMilestone;
    final step = status?.nextStep;
    if (status == null || milestone == null || step == null) {
      return const SizedBox.shrink();
    }
    return Card(
      key: const ValueKey('setup-resume-banner'),
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: ListTile(
        leading: const Icon(Icons.checklist_outlined),
        title: Text(l10n.setupGuideTitle),
        subtitle: Text(
          l10n.setupGuideBanner(
            l10n.setupMilestoneName(milestone.milestone),
            milestone.ready,
            milestone.required,
            l10n.setupStepTitle(step.step),
          ),
        ),
        trailing: TextButton(
          key: const ValueKey('setup-resume-open'),
          onPressed: () async {
            await context.push('/setup');
            ref.invalidate(workspaceSetupStatusProvider(workspaceId));
          },
          child: Text(l10n.setupGuideResume),
        ),
      ),
    );
  }
}
