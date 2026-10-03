// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — one of my spaces on Me › Home: tap to enter it, the menu to
// leave it. Leaving is ordinary and reversible by rejoining; leaving AND
// erasing my data stays the stronger action under Privacy.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../../workspace/domain/member.dart';
import '../../workspace/domain/workspace.dart';
import '../../workspace/presentation/member_labels.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../providers/me_providers.dart';
import '../../workspace/presentation/widgets/workspace_avatar.dart';
import '../../../app/shell/space_entry.dart';

class MeSpaceCard extends ConsumerWidget {
  const MeSpaceCard({
    super.key,
    required this.space,
    required this.member,
    this.lastUsed = false,
    this.grouped = false,
  });

  final Workspace space;
  final Member? member;
  final bool lastUsed;
  final bool grouped;

  bool get _pending => member?.status == MemberStatus.pending;

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n?.meLeaveTitle(space.name) ?? 'Leave ${space.name}?'),
        content: Text(
          l10n?.meLeaveBody ??
              'You stop being a member. Your bookings, invoices and messages '
                  'stay with the space. To also erase your data, use Privacy.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('me-leave-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n?.commonCancel ?? 'Cancel'),
          ),
          FilledButton(
            key: const ValueKey('me-leave-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n?.meLeaveAction ?? 'Leave this space'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final ok = await runGuarded(
      context,
      domain: 'me',
      message: 'leave space failed',
      errorText:
          l10n?.meLeaveFailed ?? 'Could not leave the space. Please try again.',
      action: () => ref
          .read(meActionsProvider)
          .leave(space.id, isOwner: member?.isOwner ?? false),
    );
    if (!ok) return;
    ref
      ..invalidate(myWorkspacesProvider)
      ..invalidate(myMembershipsProvider);
    if (!context.mounted) return;
    AppSnack.success(
      context,
      l10n?.meLeaveDone(space.name) ?? 'You left ${space.name}.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final role = member == null ? null : memberRoleLabel(l10n, member!);
    final owner = member?.isOwner ?? false;
    final row = Builder(
      key: ValueKey('me-space-${space.id}'),
      builder: (cardContext) => ListTile(
        leading: grouped
            ? const Icon(Icons.meeting_room_outlined)
            : WorkspaceAvatar(workspace: space),
        title: Text(
          grouped
              ? (space.environment == 'prod'
                    ? (l10n?.profilesPairProd ?? 'PROD')
                    : (l10n?.profilesPairDev ?? 'DEV'))
              : space.name,
        ),
        subtitle: Text(
          _pending
              ? (l10n?.meSpacePending ?? 'Waiting for approval')
              : [
                  ?role,
                  if (!grouped)
                    space.environment == 'prod'
                        ? (l10n?.profilesPairProd ?? 'PROD')
                        : (l10n?.profilesPairDev ?? 'DEV'),
                ].join(' · '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lastUsed)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: Chip(
                  key: ValueKey('me-space-last-${space.id}'),
                  label: Text(l10n?.meSpaceLastUsed ?? 'Last used'),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            const Icon(Icons.chevron_right, size: 20),
            PopupMenuButton<String>(
              key: ValueKey('me-space-menu-${space.id}'),
              tooltip: MaterialLocalizations.of(context).showMenuTooltip,
              onSelected: (_) => _leave(context, ref),
              itemBuilder: (_) => [
                PopupMenuItem(
                  key: const ValueKey('me-space-leave'),
                  value: 'leave',
                  enabled: !owner,
                  child: Text(
                    owner
                        ? (l10n?.meLeaveOwner ??
                              'Owners hand the space over before leaving')
                        : (l10n?.meLeaveAction ?? 'Leave this space'),
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          final box = cardContext.findRenderObject() as RenderBox?;
          final from = box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size;
          enterSpace(context, ref, space, from: from);
        },
      ),
    );
    return grouped
        ? row
        : Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: row,
          );
  }
}
