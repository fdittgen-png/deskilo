// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — one of my spaces on Me › Home: tap to enter it, the menu to
// leave it. Leaving is ordinary and reversible by rejoining; leaving AND
// erasing my data stays the stronger action under Privacy.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/space_entry.dart';
import '../../../core/demo/presentation/demo_workspace.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/status_colors.dart';
import '../../../core/time/clock.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../../workspace/domain/member.dart';
import '../../workspace/domain/workspace.dart';
import '../../workspace/presentation/member_labels.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../providers/me_providers.dart';
import '../providers/space_attention_provider.dart';
import '../providers/space_prefs_provider.dart';

class MeSpaceCard extends ConsumerWidget {
  const MeSpaceCard({
    super.key,
    required this.space,
    required this.member,
    this.lastUsed = false,
  });

  /// Production is twice as wide as development in the row it shares.
  static const int prodFlex = 2;
  static const int devFlex = 1;

  final Workspace space;
  final Member? member;
  final bool lastUsed;

  bool get _pending => member?.status == MemberStatus.pending;

  /// Active, or waiting for approval (the entry then shows the approval
  /// page). Paused, exited or no row: no access to this side.
  bool get _hasAccess =>
      member?.status == MemberStatus.active || _pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final words = l10n;
    final role = member == null ? null : memberRoleLabel(l10n, member!);
    final demo = DemoEnvironment.maybeOf(context) != null;
    final environment = demo ? words.demoSessionBadge : space.environment == 'prod'
        ? words.uxRealWorkspace
        : words.uxTestSpace;
    final status = _pending
        ? (l10n.meSpacePending)
        : role;
    final brightness = Theme.of(context).brightness;
    final isProd = space.environment == 'prod';
    // #2313 — what waits for me on THIS side, so the app icon's count
    // can be traced to its space and environment.
    final waiting = _hasAccess
        ? ref.watch(spaceAttentionCountsProvider)[space.id] ?? 0
        : 0;
    // Green says the space is real, orange says it is one to try things in
    // (#917); the word is on the tile as well, and the colour is a tint, not
    // a block, so the list stays calm.
    final tone = isProd
        ? AppEnvironmentColors.productionOf(brightness)
        : AppEnvironmentColors.developmentOf(brightness);
    return Expanded(
      flex: isProd ? prodFlex : devFlex,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
        child: Builder(
          builder: (buttonContext) => Tooltip(
            message: [
              space.name,
              environment,
              if (demo) words.demoSessionBadgeHint else if (space.isDevelopment) words.uxTestSpaceHint else words.uxRealSpaceHint,
              ?status,
              if (lastUsed) l10n.meSpaceLastUsed,
              if (waiting > 0) words.meSpaceNotifications(waiting),
            ].join(' · '),
            child: Badge.count(
              key: ValueKey('me-space-badge-${space.id}'),
              count: waiting,
              maxCount: 99,
              isLabelVisible: waiting > 0,
              backgroundColor: Theme.of(context).colorScheme.primary,
              textColor: Theme.of(context).colorScheme.onPrimary,
              child: FilledButton(
                key: ValueKey('me-space-${space.id}'),
                style: FilledButton.styleFrom(
                  padding: AppSpacing.mdH,
                  minimumSize: const Size(48, 52),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.lgAll,
                  ),
                  elevation: 0,
                  backgroundColor: tone.withValues(alpha: isProd ? .18 : .12),
                  foregroundColor: tone,
                  disabledBackgroundColor: tone.withValues(alpha: .06),
                  disabledForegroundColor: tone.withValues(alpha: .38),
                ),
                // 0379 — both sides hold the same people; a side whose
                // membership is not active for this person is shown
                // disabled and does nothing.
                onPressed: !_hasAccess ? null : () {
                  // The "recently used" sort remembers when I went in.
                  unawaited(ref
                      .read(spacePrefsProvider.notifier)
                      .touch(spaceRowKeyOf(space), ref.read(clockProvider).now()));
                  final box = buttonContext.findRenderObject() as RenderBox?;
                  final from = box == null
                      ? null
                      : box.localToGlobal(Offset.zero) & box.size;
                  unawaited(enterSpace(context, ref, space, from: from));
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (lastUsed) ...[
                      Icon(
                        Icons.history,
                        size: 16,
                        key: ValueKey('me-space-last-${space.id}'),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ] else ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: tone,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Flexible(
                      child: Text(
                        isProd ? words.uxOpenWorkspace : words.uxTestSpace,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge?.strong,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks, then leaves [space]; owners must hand it over first.
Future<void> confirmLeaveSpace(
  BuildContext context,
  WidgetRef ref,
  Workspace space,
  Member? member,
) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.meLeaveTitle(space.name)),
      content: Text(
        l10n.meLeaveBody,
      ),
      actions: [
        TextButton(
          key: const ValueKey('me-leave-cancel'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('me-leave-confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.meLeaveAction),
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
        l10n.meLeaveFailed,
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
    l10n.meLeaveDone(space.name),
  );
}
