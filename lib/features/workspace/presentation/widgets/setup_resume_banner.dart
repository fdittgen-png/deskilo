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
import '../../domain/workspace_feature.dart';
import '../../domain/workspace_readiness.dart';
import '../../providers/local_setup_providers.dart';
import '../../providers/workspace_providers.dart';

class SetupResumeBanner extends ConsumerWidget {
  const SetupResumeBanner({
    super.key,
    required this.workspaceId,
    this.compact = false,
  });
  final String workspaceId;

  /// One dense line, for a screen whose content must stay in view (Reserve).
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = ref.watch(workspaceSetupStatusProvider(workspaceId)).value;
    final milestone = status?.nextMilestone;
    final step = status?.nextStep;
    if (status == null || milestone == null || step == null) {
      return const SizedBox.shrink();
    }
    final card = Card(
      key: const ValueKey('setup-resume-banner'),
      margin: EdgeInsets.symmetric(
        vertical: compact ? AppSpacing.xs : AppSpacing.sm,
      ),
      child: ListTile(
        dense: compact,
        leading: const Icon(Icons.checklist_outlined),
        title: compact ? null : Text(l10n.setupGuideTitle),
        subtitle: Text(
          l10n.setupGuideBanner(
            l10n.setupMilestoneName(milestone.milestone),
            milestone.ready,
            milestone.required,
            l10n.setupStepTitle(step.step),
          ),
          maxLines: compact ? 1 : null,
          overflow: compact ? TextOverflow.ellipsis : null,
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
    // Without its title the compact line still names itself to a reader.
    return compact ? Semantics(label: l10n.setupGuideTitle, child: card) : card;
  }
}

/// The guide's banner for [workspaceId] when the guide is on, the reader
/// [configures] the space and a milestone is still open; null otherwise.
Widget? setupResumeBannerFor(
  WidgetRef ref,
  String? workspaceId, {
  required bool configures,
  bool compact = false,
}) {
  if (workspaceId == null ||
      !configures ||
      !ref
          .watch(enabledFeaturesSyncProvider)
          .contains(WorkspaceFeature.setupGuide)) {
    return null;
  }
  final status = ref.watch(workspaceSetupStatusProvider(workspaceId)).value;
  return status?.nextMilestone == null || status?.nextStep == null
      ? null
      : SetupResumeBanner(workspaceId: workspaceId, compact: compact);
}

/// The readiness sections of [workspaceId], for a surface outside this
/// feature that guides by them (Reserve's get-started card).
List<ReadinessSection>? watchWorkspaceReadiness(
  WidgetRef ref,
  String workspaceId,
) => ref.watch(workspaceReadinessProvider(workspaceId)).value;

/// #3077 — whether the setup guide still has a milestone open for
/// [workspaceId]: the sidebar offers its door only then.
bool setupGuideOpenFor(WidgetRef ref, String? workspaceId) {
  if (workspaceId == null ||
      !ref
          .watch(enabledFeaturesSyncProvider)
          .contains(WorkspaceFeature.setupGuide)) {
    return false;
  }
  return ref.watch(workspaceSetupStatusProvider(workspaceId)).value?.nextMilestone != null;
}
