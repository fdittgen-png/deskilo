// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../profile/providers/profile_providers.dart';
import '../../domain/member.dart';
import '../../providers/workspace_providers.dart';
import 'badge_manager_dialog.dart';

/// Settings → "My badge" (0053), lifted out of settings_screen.dart when
/// that file reached its length budget.
///
/// It sits beside the sign-in PIN tile (#662) on purpose: the card and
/// the PIN are two halves of one credential, and a member holding one
/// without the other cannot sign in. Keeping them adjacent is what makes
/// that legible without a paragraph of explanation.
class MyBadgeTile extends ConsumerWidget {
  const MyBadgeTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final myProfile = ref.watch(myProfileProvider).value;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // My badge (0053): the member's own kiosk credentials — mint
      // the printable QR, register their RFID/NFC card, revoke.
      // Same manager the admins use, with the self-service RPCs.
      if (ref.watch(myMemberProvider).value case final me?
          when me.status == MemberStatus.active && !me.isKiosk)
        ListTile(
          key: const ValueKey('settings-my-badge'),
          leading: const Icon(Icons.badge_outlined),
          title: Text(l10n?.myBadgeTitle ?? 'My badge'),
          onTap: () {
            final workspace =
                ref.read(currentWorkspaceProvider).value;
            if (workspace == null) return;
            showDialog<void>(
              context: context,
              builder: (_) => BadgeManagerDialog(
                workspaceId: workspace.id,
                memberId: me.id,
                name: myProfile?.displayName ?? '',
                l10n: l10n,
                issue: () => ref
                    .read(workspaceRepositoryProvider)
                    .issueMyBadge(workspace.id),
                registerNfc: (uid) => ref
                    .read(workspaceRepositoryProvider)
                    .registerMyNfcBadge(workspace.id, uid: uid),
                revoke: (badgeId) => ref
                    .read(workspaceRepositoryProvider)
                    .revokeMyBadge(badgeId),
                // Deletion is one shared RPC: the server allows the
                // badge's own member or an admin (0055).
                delete: (badgeId) => ref
                    .read(workspaceRepositoryProvider)
                    .deleteRevokedBadge(badgeId),
              ),
            );
          },
        ),
    ]);
  }
}
