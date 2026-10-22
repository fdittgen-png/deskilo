// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/domain/workspace_event.dart';
import '../../../events/presentation/event_labels.dart';
import '../../domain/local_setup.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/local_setup_providers.dart';
import '../../providers/workspace_providers.dart';
import 'setup_resume_banner.dart';
import 'workspace_readiness_card.dart';

/// #1657 — a validation event type, as its label, from its stored word.
String eventTypeWord(AppLocalizations l10n, String dbName) =>
    eventTypeLabel(l10n, EventType.fromDb(dbName));

String localSlotLabel(AppLocalizations l10n, LocalSlotKind kind,
        [String? eventType]) =>
    switch (kind) {
      LocalSlotKind.legalIdentity =>
        l10n.localSlotLegalIdentity,
      LocalSlotKind.paymentDetails =>
        l10n.localSlotPaymentDetails,
      LocalSlotKind.paymentProvider =>
        l10n.localSlotPaymentProvider,
      LocalSlotKind.einvoicePlatform =>
        l10n.localSlotEinvoicePlatform,
      LocalSlotKind.site => l10n.localSlotSite,
      LocalSlotKind.namedValidators => l10n.localSlotNamedValidators(
              eventTypeLabel(l10n, EventType.fromDb(eventType ?? ''))),
      LocalSlotKind.unknown => '',
    };

/// #1656 — at creation: what the chosen template will need locally,
/// because it never carries anyone's identity, bank or provider account.
class TemplateLocalNeedsView extends ConsumerWidget {
  const TemplateLocalNeedsView({super.key, required this.templateId});
  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final needs =
        ref.watch(templateLocalNeedsProvider(templateId)).value ??
        const <LocalSlot>[];
    final shown = [
      for (final s in needs)
        if (s.kind != LocalSlotKind.unknown) s,
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('template-local-needs'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.localNeedsTitle,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        for (final s in shown)
          ListTile(
            key: ValueKey('template-local-need-${s.kind.name}${s.eventType ?? ''}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.edit_note_outlined),
            title: Text(localSlotLabel(l10n, s.kind, s.eventType)),
            subtitle: s.required
                ? null
                : Text(l10n.localSlotRecommended),
          ),
      ],
    );
  }
}

/// #1656 — in settings: what this space still lacks for the features it
/// has on, each with where to fill it in. Nothing when complete.
@visibleForTesting
class LocalReadinessCard extends ConsumerWidget {
  const LocalReadinessCard({super.key, required this.workspaceId});
  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final gaps =
        ref.watch(workspaceLocalGapsProvider(workspaceId)).value ??
        const <LocalSlot>[];
    if (gaps.isEmpty) return const SizedBox.shrink();
    return Card(
      key: const ValueKey('local-readiness'),
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.localGapsTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final s in gaps)
              ListTile(
                key: ValueKey('local-gap-${s.kind.name}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  s.required ? Icons.error_outline : Icons.info_outline,
                ),
                title: Text(localSlotLabel(l10n, s.kind, s.eventType)),
                subtitle: s.required
                    ? null
                    : Text(l10n.localSlotRecommended),
                trailing: TextButton(
                  key: ValueKey('local-setup-open-${s.route}'),
                  onPressed: () => context.push(s.route),
                  child: Text(l10n.localSlotOpen),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// #1636 #1656 — the top of the space's settings: how far it is from a
/// first booking, then what its features still lack locally. #2869 — with
/// the setup guide on, its resume banner instead (ADR 0047 §6).
List<Widget> setupReadinessCards(String workspaceId) => [
  _SetupEntry(workspaceId: workspaceId),
];

class _SetupEntry extends ConsumerWidget {
  const _SetupEntry({required this.workspaceId});
  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(enabledFeaturesSyncProvider).contains(WorkspaceFeature.setupGuide)
          ? SetupResumeBanner(workspaceId: workspaceId)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WorkspaceReadinessCard(workspaceId: workspaceId),
                LocalReadinessCard(workspaceId: workspaceId),
              ],
            );
}
