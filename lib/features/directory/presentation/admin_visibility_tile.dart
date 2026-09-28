// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/trace/guarded.dart';
import '../../../l10n/app_localizations.dart';
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
    final l = AppLocalizations.of(context);
    final visible = ref.watch(adminVisibilityProvider(member.workspaceId));
    return SwitchListTile(
      value: visible.value ?? false,
      title: Text(l?.portalAdminVisible ?? 'Show me as a public administrator'),
      onChanged: visible.hasValue
          ? (v) async {
              final ok = await runGuarded(
                context,
                domain: 'directory',
                message: 'save administrator visibility failed',
                errorText:
                    l?.portalActionFailed ??
                    'Could not save this change. Please try again.',
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
