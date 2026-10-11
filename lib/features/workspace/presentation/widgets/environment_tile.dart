// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #917 — "is this workspace real?", asked of the one person entitled to
// answer.
//
// Only the OWNER may declare a space production; an admin cannot quietly
// take the development mark off the documents they issue (the server
// enforces the same rule in `set_workspace_environment`). Turning the
// mark ON needs no ceremony — saying "this is not real" is always safe.
// Turning it OFF is a statement that the invoices leaving here are owed,
// so it is confirmed, and the confirmation says what stops happening.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/workspace_providers.dart';

class WorkspaceEnvironmentTile extends ConsumerWidget {
  const WorkspaceEnvironmentTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final isOwner = ref.watch(myMemberProvider).value?.isOwner ?? false;
    if (workspace == null || !isOwner) return const SizedBox.shrink();
    final pairsOn = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.environmentPairs);
    return Column(children: [
      MergeSemantics(child: ListTile(
      key: const ValueKey('workspace-environment'),
      leading: Icon(workspace.isDevelopment
          ? Icons.construction_outlined
          : Icons.verified_outlined),
      title: Text(l10n.environmentLabel),
      subtitle: Text(
        workspace.isDevelopment
            ? (l10n.environmentDev)
            : (l10n.environmentProd),
      ),
      trailing: Switch(
        key: const ValueKey('workspace-environment-switch'),
        value: !workspace.isDevelopment,
        onChanged: (toProduction) =>
            _set(context, ref, workspace, toProduction: toProduction),
      ),
      )),
      // #987 — the other side of the pair.
      if (pairsOn)
        ListTile(
          key: const ValueKey('workspace-create-twin'),
          leading: const Icon(Icons.copy_all_outlined),
          title: Text(workspace.pairId.isEmpty
              ? (l10n.environmentPairsCreateTwin)
              : workspace.isDevelopment
                  ? (l10n.environmentPairsPairedProd)
                  : (l10n.environmentPairsPairedDev)),
          subtitle: workspace.pairId.isEmpty
              ? Text(l10n.environmentPairsCreateTwinDesc)
              : null,
          enabled: workspace.pairId.isEmpty,
          onTap: workspace.pairId.isEmpty
              ? () => _createTwin(context, ref, workspace)
              : null,
        ),
    ]);
  }

  Future<void> _createTwin(
      BuildContext context, WidgetRef ref, Workspace workspace) async {
    final l10n = context.l10n;
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'twin creation failed',
      errorText: l10n.workspaceGenericError,
      action: () => ref
          .read(workspaceRepositoryProvider)
          .createWorkspaceTwin(workspace.id),
    )) {
      return;
    }
    ref
      ..invalidate(myWorkspacesProvider)
      ..invalidate(currentWorkspaceProvider);
    if (!context.mounted) return;
    AppSnack.success(
        context, l10n.environmentPairsTwinCreated);
  }

  Future<void> _set(
    BuildContext context,
    WidgetRef ref,
    Workspace workspace, {
    required bool toProduction,
  }) async {
    final l10n = context.l10n;
    if (toProduction) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: const ValueKey('workspace-environment-confirm'),
          title: Text(l10n.environmentProdConfirmTitle),
          content: Text(l10n.environmentProdConfirmBody),
          actions: [
            TextButton(
              key: const ValueKey('environment-tile-cancel'),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              key: const ValueKey('workspace-environment-confirm-yes'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                  l10n.environmentProdConfirmAction),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
    final saved = await runGuarded(
      context,
      domain: 'workspace',
      message: 'workspace environment change failed',
      errorText: l10n.workspaceGenericError,
      action: () => ref.read(workspaceRepositoryProvider).setWorkspaceEnvironment(
            workspace.id,
            toProduction
                ? WorkspaceEnvironment.production
                : WorkspaceEnvironment.development,
          ),
    );
    ref.invalidate(myWorkspacesProvider);
    if (!saved || !context.mounted) return;
    AppSnack.success(
      context,
      l10n.environmentSaved,
    );
  }
}
