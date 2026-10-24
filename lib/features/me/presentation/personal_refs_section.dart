// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2563 C1 — Me › Home: the workspaces my personal account names that this
// server does not list as one of my spaces — a workspace on another
// installation, or a saved one I hold no membership with here. Read from
// my personal home alone (`my_personal_workspace_refs_v1`), so it works
// with no workspace selected and on a home that hosts none. A workspace on
// another installation says plainly that its membership is not verified
// yet: nothing here claims more than the home knows, and nothing here
// grants anything.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/app_localizations.dart';
import '../../workspace/domain/member.dart';
import '../../workspace/presentation/member_labels.dart';
import '../domain/personal_workspace_refs.dart';
import '../providers/me_providers.dart';

class PersonalRefsSection extends ConsumerWidget {
  const PersonalRefsSection({super.key});

  static String detail(AppLocalizations l10n, PersonalWorkspaceRef ref) {
    final status = ref.status;
    final parts = [
      if (ref.freshness == RefFreshness.unavailable)
        l10n.meRefUnverified
      else if (status == null)
        l10n.meRefNoRelationship
      else
        memberStatusLabel(l10n, MemberStatus.values.byName(status.name)),
      if (ref.isDefault) l10n.meRefDefault,
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final answer = ref.watch(personalWorkspaceRefsProvider);
    if (answer.hasError) {
      return Padding(
        key: const ValueKey('me-refs-unavailable'),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text(
          l10n.meRefsUnavailable,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }
    final refs = answer.value?.beyondLocalSpaces ?? const [];
    if (refs.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('me-refs'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            top: AppSpacing.lg,
            bottom: AppSpacing.xs,
          ),
          child: Text(
            l10n.meRefsTitle,
            style: Theme.of(context).textTheme.titleMedium?.strong,
          ),
        ),
        for (final item in refs)
          ListTile(
            key: ValueKey('me-ref-${item.networkId}'),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
            ),
            leading: Icon(
              item.freshness == RefFreshness.unavailable
                  ? Icons.cloud_off_outlined
                  : Icons.meeting_room_outlined,
            ),
            title: Text(
              item.label ?? l10n.meRefUnnamed,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(detail(l10n, item)),
            trailing: item.isFavorite
                ? Icon(
                    Icons.star,
                    color: scheme.primary,
                    semanticLabel: l10n.meGroupFavorites,
                  )
                : null,
          ),
      ],
    );
  }
}
