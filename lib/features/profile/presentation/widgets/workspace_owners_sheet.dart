// SPDX-License-Identifier: 0BSD
//
// #937 — who owns a workspace the platform owner is not in: name and
// e-mail, with a copy action. The read is logged server-side.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/workspace_overview.dart';
import '../../../workspace/providers/workspace_providers.dart';

Future<void> showWorkspaceOwnersSheet(
  BuildContext context,
  WidgetRef ref,
  WorkspaceOverview workspace,
) {
  final owners = ref
      .read(workspaceRepositoryProvider)
      .fetchWorkspaceOwners(workspace.id);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      final theme = Theme.of(context);
      return SafeArea(
        child: Padding(
          padding: AppSpacing.lgAll,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n?.profilesOwnersOf(workspace.name) ??
                    'Owners of ${workspace.name}',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              FutureBuilder<List<WorkspaceOwner>>(
                future: owners,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(snapshot.error.toString());
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final rows = snapshot.data!;
                  if (rows.isEmpty) {
                    return Text(l10n?.profilesOwnersNone ?? 'No owner.');
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final owner in rows)
                        ListTile(
                          key: ValueKey('workspace-owner-${owner.memberId}'),
                          leading: const Icon(Icons.person_outline),
                          title: Text(owner.name),
                          subtitle: Text(owner.email),
                          trailing: IconButton(
                            tooltip: l10n?.profilesCopyEmail ?? 'Copy e-mail',
                            icon: const Icon(Icons.copy_outlined),
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: owner.email),
                              );
                              if (context.mounted) {
                                AppSnack.success(
                                  context,
                                  l10n?.profilesEmailCopied ?? 'E-mail copied.',
                                );
                              }
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
