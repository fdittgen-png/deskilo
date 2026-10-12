// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/backend/schema_version.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/set_readiness_aside.dart';
import '../../domain/workspace_feature.dart';
import '../../domain/workspace_readiness.dart';
import '../../providers/local_setup_providers.dart';
import '../../providers/workspace_providers.dart';

String readinessAreaLabel(
  AppLocalizations l10n,
  ReadinessArea area,
) => switch (area) {
  ReadinessArea.backend =>
    l10n.readinessAreaBackend,
  ReadinessArea.regionRules =>
    l10n.readinessAreaRegionRules,
  ReadinessArea.resources =>
    l10n.readinessAreaResources,
  ReadinessArea.pricing =>
    l10n.readinessAreaPricing,
  ReadinessArea.invitations =>
    l10n.readinessAreaInvitations,
  ReadinessArea.payments => l10n.readinessAreaPayments,
  ReadinessArea.rolesValidation =>
    l10n.readinessAreaRolesValidation,
  ReadinessArea.recovery =>
    l10n.readinessAreaRecovery,
  ReadinessArea.localSetup =>
    l10n.readinessAreaLocalSetup,
  ReadinessArea.assistant =>
    l10n.readinessAreaAssistant,
  ReadinessArea.firstBooking =>
    l10n.readinessAreaFirstBooking,
  // #2332 — English only where no localization is installed.
  ReadinessArea.memberPermissions =>
    l10n
        .readinessAreaMemberPermissions,
  ReadinessArea.legalIdentity =>
    l10n
        .readinessAreaLegalIdentity,
  ReadinessArea.unknown => '',
};

String _readinessStateLabel(AppLocalizations l10n, ReadinessState state) =>
    switch (state) {
      ReadinessState.ready => l10n.readinessStateReady,
      ReadinessState.needsConfiguration =>
        l10n.readinessStateNeeds,
      ReadinessState.needsOperator =>
        l10n.readinessStateNeedsOperator,
      ReadinessState.notApplicable =>
        l10n.readinessStateNotApplicable,
      ReadinessState.unverified =>
        l10n.readinessStateUnverified,
      ReadinessState.unavailable =>
        l10n.readinessStateUnavailable,
    };

/// Why, in words, for the reasons the server names; null for the rest.
@visibleForTesting
String? readinessReasonLabel(AppLocalizations l10n, String? reason) =>
    switch (reason) {
      'too_few_validators' =>
        l10n.readinessReasonTooFewValidators,
      'members_cannot_book' => l10n
          .readinessReasonMembersCannotBook,
      'invoicing_needs_identity' =>
        l10n
            .readinessReasonInvoicingNeedsIdentity,
      'no_policies' =>
        l10n.readinessReasonNoPolicies,
      'no_evidence' =>
        l10n.readinessReasonNoEvidence,
      'recent_export' =>
        l10n.readinessReasonRecentExport,
      'stale_export' =>
        l10n.readinessReasonStaleExport,
      'not_exposed' =>
        l10n.readinessReasonNotExposed,
      'eligibility_requested' =>
        l10n.readinessReasonEligibilityRequested,
      'eligibility_expired' =>
        l10n.readinessReasonEligibilityExpired,
      'eligibility_no_identity' =>
        l10n.readinessReasonEligibilityNoIdentity,
      final r? when r.startsWith('eligibility_') =>
        l10n.readinessReasonEligibilityMissing,
      _ => null,
    };

String _readinessActorLabel(AppLocalizations l10n, ReadinessActor actor) =>
    switch (actor) {
      ReadinessActor.owner => l10n.readinessActorOwner,
      ReadinessActor.operator =>
        l10n.readinessActorOperator,
      ReadinessActor.administrator =>
        l10n.readinessActorAdministrator,
    };

/// #1636 — at the top of the space's settings: the next thing that stands
/// between this space and a first booking, then every section with its
/// state, who acts on it and where to set it up. It reads; it never
/// books, invites or charges anything to find out. The backend section
/// comes from the app's own schema check; the rest from the server.
/// Hidden with the Get started help (`memberGettingStarted`), and for
/// anyone the server does not answer. An optional section that is still
/// open can be set aside for later (0307): the next step moves on, the
/// state stays what it is, and Undo takes it back.
class WorkspaceReadinessCard extends ConsumerWidget {
  const WorkspaceReadinessCard({super.key, required this.workspaceId});
  final String workspaceId;

  Future<void> _setAside(
    BuildContext context,
    WidgetRef ref,
    ReadinessSection section, {
    required bool undo,
  }) async {
    final l10n = context.l10n;
    final aside = ref.read(readinessAsideProvider);
    try {
      if (undo) {
        await aside.undo(workspaceId, section);
      } else {
        await aside.later(workspaceId, section);
      }
    } on Object catch (e, st) {
      TraceLogger.instance.error(
        'workspace',
        'set readiness section aside failed',
        error: e,
        stackTrace: st,
      );
      if (context.mounted) {
        AppSnack.error(
          context,
          l10n.readinessSetAsideFailed,
        );
      }
    }
    ref.invalidate(workspaceReadinessProvider(workspaceId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.memberGettingStarted)) {
      return const SizedBox.shrink();
    }
    final server = [
      for (final s
          in ref.watch(workspaceReadinessProvider(workspaceId)).value ??
              const <ReadinessSection>[])
        if (s.area != ReadinessArea.unknown) s,
    ];
    if (server.isEmpty) return const SizedBox.shrink();
    final sections = [
      backendReadiness(ref.watch(schemaCompatibilityProvider).value),
      ...server,
    ];
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final next = nextReadinessStep(sections);
    final blocked = sections.any((s) => s.blocking);
    final applicable = sections.where((s) => s.applicable);
    final ready = applicable.where((s) => s.state == ReadinessState.ready);
    final headline = switch (next) {
      // #2332 — the legal identity holds back invoicing, not a booking.
      final n? when n.blocking && n.area == ReadinessArea.legalIdentity =>
        l10n
            .readinessBlockedInvoicing(readinessAreaLabel(l10n, n.area)),
      final n? when n.blocking =>
        l10n.readinessBlocked(readinessAreaLabel(l10n, n.area)),
      _ when !blocked =>
        l10n.readinessFirstBookingReady,
      _ => '',
    };
    return Card(
      key: const ValueKey('workspace-readiness'),
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.readinessTitle,
              style: textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(headline, key: const ValueKey('workspace-readiness-headline')),
            if (next != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: const ValueKey('workspace-readiness-next'),
                  onPressed: () => context.push(next.route),
                  child: Text(
                    next.blocking
                        ? (l10n.localSlotOpen)
                        : (l10n.readinessNext(
                                readinessAreaLabel(l10n, next.area),
                              )),
                  ),
                ),
              ),
            ExpansionTile(
              key: const ValueKey('workspace-readiness-all'),
              tilePadding: EdgeInsets.zero,
              title: Text(
                l10n.readinessAll('${ready.length}', '${applicable.length}'),
                style: textTheme.bodyMedium,
              ),
              children: [
                for (final s in sections)
                  ListTile(
                    key: ValueKey('workspace-readiness-${s.area.name}'),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(switch (s.state) {
                      ReadinessState.ready => Icons.check_circle_outline,
                      ReadinessState.needsConfiguration =>
                        s.required
                            ? Icons.error_outline
                            : Icons.radio_button_unchecked,
                      ReadinessState.needsOperator => Icons.dns_outlined,
                      ReadinessState.notApplicable =>
                        Icons.remove_circle_outline,
                      ReadinessState.unverified => Icons.help_outline,
                      ReadinessState.unavailable => Icons.cloud_off_outlined,
                    }),
                    title: Text(readinessAreaLabel(l10n, s.area)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [
                            _readinessStateLabel(l10n, s.state),
                            if (s.acknowledged && s.canSetAside)
                              l10n.readinessSetAside
                            else if (s.state != ReadinessState.notApplicable)
                              if (s.required &&
                                  s.area == ReadinessArea.legalIdentity)
                                l10n
                                    .readinessNeededInvoicing
                              else if (s.required)
                                l10n.readinessNeededFirst
                              else
                                l10n.readinessLater,
                            ?readinessReasonLabel(l10n, s.reason),
                            if (s.state != ReadinessState.ready &&
                                s.state != ReadinessState.notApplicable)
                              l10n.readinessActor(
                                    _readinessActorLabel(l10n, s.actor),
                                  ),
                          ].join(' · '),
                        ),
                        if (s.canSetAside)
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: s.acknowledged
                                ? TextButton.icon(
                                    key: ValueKey(
                                      'workspace-readiness-undo-${s.area.name}',
                                    ),
                                    onPressed: () =>
                                        _setAside(context, ref, s, undo: true),
                                    icon: const Icon(Icons.undo),
                                    label: Text(
                                      l10n.readinessSetAsideUndo,
                                    ),
                                  )
                                : TextButton(
                                    key: ValueKey(
                                      'workspace-readiness-later-${s.area.name}',
                                    ),
                                    onPressed: () =>
                                        _setAside(context, ref, s, undo: false),
                                    child: Text(
                                      l10n.readinessSetAsideAction,
                                    ),
                                  ),
                          ),
                      ],
                    ),
                    trailing:
                        s.state == ReadinessState.ready ||
                            s.state == ReadinessState.notApplicable
                        ? null
                        : TextButton(
                            key: ValueKey('workspace-readiness-open-${s.route}'),
                            onPressed: () => context.push(s.route),
                            child: Text(l10n.localSlotOpen),
                          ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
