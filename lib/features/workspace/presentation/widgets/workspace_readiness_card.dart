// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/backend/schema_version.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace_feature.dart';
import '../../domain/workspace_readiness.dart';
import '../../providers/local_setup_providers.dart';
import '../../providers/workspace_providers.dart';

String readinessAreaLabel(
  AppLocalizations? l10n,
  ReadinessArea area,
) => switch (area) {
  ReadinessArea.backend =>
    l10n?.readinessAreaBackend ?? 'Server and database version',
  ReadinessArea.regionRules =>
    l10n?.readinessAreaRegionRules ?? 'Opening days, time zone and currency',
  ReadinessArea.resources =>
    l10n?.readinessAreaResources ?? 'Bookable places on the floor plan',
  ReadinessArea.pricing =>
    l10n?.readinessAreaPricing ?? 'Membership plans and tariffs',
  ReadinessArea.invitations =>
    l10n?.readinessAreaInvitations ?? 'Invite the first members',
  ReadinessArea.payments => l10n?.readinessAreaPayments ?? 'How members pay',
  ReadinessArea.rolesValidation =>
    l10n?.readinessAreaRolesValidation ?? 'Roles and who validates requests',
  ReadinessArea.recovery =>
    l10n?.readinessAreaRecovery ?? 'Export and recovery',
  ReadinessArea.localSetup =>
    l10n?.readinessAreaLocalSetup ??
        'Details your features need (identity, bank, platforms)',
  ReadinessArea.assistant =>
    l10n?.readinessAreaAssistant ?? 'Assistant access (optional)',
  ReadinessArea.firstBooking =>
    l10n?.readinessAreaFirstBooking ?? 'A first booking',
  ReadinessArea.unknown => '',
};

String readinessStateLabel(AppLocalizations? l10n, ReadinessState state) =>
    switch (state) {
      ReadinessState.ready => l10n?.readinessStateReady ?? 'Ready',
      ReadinessState.needsConfiguration =>
        l10n?.readinessStateNeeds ?? 'Needs configuration',
      ReadinessState.needsOperator =>
        l10n?.readinessStateNeedsOperator ?? 'Waiting for someone else',
      ReadinessState.notApplicable =>
        l10n?.readinessStateNotApplicable ?? 'Not needed here',
      ReadinessState.unverified =>
        l10n?.readinessStateUnverified ?? 'Not verified yet',
      ReadinessState.unavailable =>
        l10n?.readinessStateUnavailable ?? 'Could not be read',
    };

/// Why, in words, for the reasons the server names; null for the rest.
String? readinessReasonLabel(AppLocalizations? l10n, String? reason) =>
    switch (reason) {
      'too_few_validators' =>
        l10n?.readinessReasonTooFewValidators ??
            'A policy asks for more validators than this space has',
      'no_policies' =>
        l10n?.readinessReasonNoPolicies ?? 'No request waits for a validator',
      'no_evidence' =>
        l10n?.readinessReasonNoEvidence ?? 'No export or restore recorded yet',
      'recent_export' =>
        l10n?.readinessReasonRecentExport ?? 'A recent export is on record',
      'stale_export' =>
        l10n?.readinessReasonStaleExport ??
            'The last recorded export is more than 90 days old',
      'not_exposed' =>
        l10n?.readinessReasonNotExposed ??
            'This space does not expose anything to assistants yet',
      'eligibility_requested' =>
        l10n?.readinessReasonEligibilityRequested ??
            'Your request waits for a database administrator',
      'eligibility_expired' =>
        l10n?.readinessReasonEligibilityExpired ??
            'Your assistant eligibility has expired',
      'eligibility_no_identity' =>
        l10n?.readinessReasonEligibilityNoIdentity ??
            'Sign in with your verified identity first',
      final r? when r.startsWith('eligibility_') =>
        l10n?.readinessReasonEligibilityMissing ??
            'A database administrator has not approved you for assistants',
      _ => null,
    };

String readinessActorLabel(AppLocalizations? l10n, ReadinessActor actor) =>
    switch (actor) {
      ReadinessActor.owner => l10n?.readinessActorOwner ?? 'You',
      ReadinessActor.operator =>
        l10n?.readinessActorOperator ?? 'The server operator',
      ReadinessActor.administrator =>
        l10n?.readinessActorAdministrator ?? 'A database administrator',
    };

/// #1636 — at the top of the space's settings: the next thing that stands
/// between this space and a first booking, then every section with its
/// state, who acts on it and where to set it up. It reads; it never
/// books, invites or charges anything to find out. The backend section
/// comes from the app's own schema check; the rest from the server.
/// Hidden with the Get started help (`memberGettingStarted`), and for
/// anyone the server does not answer.
class WorkspaceReadinessCard extends ConsumerWidget {
  const WorkspaceReadinessCard({super.key, required this.workspaceId});
  final String workspaceId;

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
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final next = nextReadinessStep(sections);
    final blocked = sections.any((s) => s.blocking);
    final applicable = sections.where((s) => s.applicable);
    final ready = applicable.where((s) => s.state == ReadinessState.ready);
    final headline = switch (next) {
      final n? when n.blocking =>
        l10n?.readinessBlocked(readinessAreaLabel(l10n, n.area)) ??
            'Before a first booking: ${readinessAreaLabel(l10n, n.area)}',
      _ when !blocked =>
        l10n?.readinessFirstBookingReady ?? 'Ready for a first booking',
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
              l10n?.readinessTitle ?? 'Setting up this space',
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
                        ? (l10n?.localSlotOpen ?? 'Set up')
                        : (l10n?.readinessNext(
                                readinessAreaLabel(l10n, next.area),
                              ) ??
                              'Next: ${readinessAreaLabel(l10n, next.area)}'),
                  ),
                ),
              ),
            ExpansionTile(
              key: const ValueKey('workspace-readiness-all'),
              tilePadding: EdgeInsets.zero,
              title: Text(
                l10n?.readinessAll('${ready.length}', '${applicable.length}') ??
                    'All sections (${ready.length} of ${applicable.length} ready)',
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
                      ReadinessState.notApplicable => Icons.remove_circle_outline,
                      ReadinessState.unverified => Icons.help_outline,
                      ReadinessState.unavailable => Icons.cloud_off_outlined,
                    }),
                    title: Text(readinessAreaLabel(l10n, s.area)),
                    subtitle: Text(
                      [
                        readinessStateLabel(l10n, s.state),
                        if (s.state != ReadinessState.notApplicable)
                          s.required
                              ? (l10n?.readinessNeededFirst ??
                                    'Needed for a first booking')
                              : (l10n?.readinessLater ?? 'Needed later'),
                        ?readinessReasonLabel(l10n, s.reason),
                        if (s.state != ReadinessState.ready &&
                            s.state != ReadinessState.notApplicable)
                          l10n?.readinessActor(
                                readinessActorLabel(l10n, s.actor),
                              ) ??
                              'Who: ${readinessActorLabel(l10n, s.actor)}',
                      ].join(' · '),
                    ),
                    trailing: s.state == ReadinessState.ready ||
                            s.state == ReadinessState.notApplicable
                        ? null
                        : TextButton(
                            onPressed: () => context.push(s.route),
                            child: Text(l10n?.localSlotOpen ?? 'Set up'),
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
