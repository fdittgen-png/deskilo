// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  ReadinessArea.regionRules =>
    l10n?.readinessAreaRegionRules ?? 'Opening days, time zone and currency',
  ReadinessArea.resources =>
    l10n?.readinessAreaResources ?? 'Bookable places on the floor plan',
  ReadinessArea.pricing =>
    l10n?.readinessAreaPricing ?? 'Membership plans and tariffs',
  ReadinessArea.invitations =>
    l10n?.readinessAreaInvitations ?? 'Invite the first members',
  ReadinessArea.payments => l10n?.readinessAreaPayments ?? 'How members pay',
  ReadinessArea.recovery =>
    l10n?.readinessAreaRecovery ?? 'Export and recovery',
  ReadinessArea.localSetup =>
    l10n?.readinessAreaLocalSetup ??
        'Details your features need (identity, bank, platforms)',
  ReadinessArea.unknown => '',
};

String readinessStateLabel(AppLocalizations? l10n, ReadinessState state) =>
    switch (state) {
      ReadinessState.ready => l10n?.readinessStateReady ?? 'Ready',
      ReadinessState.needsConfiguration =>
        l10n?.readinessStateNeeds ?? 'Needs configuration',
      ReadinessState.unverified =>
        l10n?.readinessStateUnverified ?? 'Not verified yet',
    };

/// #1636 — at the top of the space's settings: the next thing that stands
/// between this space and a first booking, then every section with its
/// state and where to set it up. It reads; it never books, invites or
/// charges anything to find out. Hidden with the Get started help
/// (`memberGettingStarted`), and for anyone the server does not answer.
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
    final sections = [
      for (final s
          in ref.watch(workspaceReadinessProvider(workspaceId)).value ??
              const <ReadinessSection>[])
        if (s.area != ReadinessArea.unknown) s,
    ];
    if (sections.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final next = nextReadinessStep(sections);
    final blocked = sections.any((s) => s.blocking);
    final ready = sections.where((s) => s.state == ReadinessState.ready);
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
                l10n?.readinessAll('${ready.length}', '${sections.length}') ??
                    'All sections (${ready.length} of ${sections.length} ready)',
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
                      ReadinessState.unverified => Icons.help_outline,
                    }),
                    title: Text(readinessAreaLabel(l10n, s.area)),
                    subtitle: Text(
                      '${readinessStateLabel(l10n, s.state)} · '
                      '${s.required ? (l10n?.readinessNeededFirst ?? 'Needed for a first booking') : (l10n?.readinessLater ?? 'Needed later')}',
                    ),
                    trailing: s.state == ReadinessState.ready
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
