// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/guarded.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../providers/directory_providers.dart';

class AdminVisibilityTile extends ConsumerWidget {
  const AdminVisibilityTile({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(myMemberProvider).value;
    if (member == null || !member.canAdminister || member.isOwner) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    final visible = ref.watch(adminVisibilityProvider(member.workspaceId));
    return SwitchListTile(
      key: const ValueKey('admin-visibility-tile-portal-admin-visible'),
      value: visible.value ?? false,
      title: Text(l.portalAdminVisible),
      onChanged: visible.hasValue
          ? (v) async {
              final ok = await runGuarded(
                context,
                domain: 'directory',
                message: 'save administrator visibility failed',
                errorText:
                    l.portalActionFailed,
                action: () => ref
                    .read(accountContactActionsProvider())
                    .adminVisibility(member.workspaceId, visible: v),
              );
              if (ok && context.mounted) {
                ref.invalidate(adminVisibilityProvider(member.workspaceId));
              }
            }
          : null,
    );
  }
}
