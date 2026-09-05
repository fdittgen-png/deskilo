// SPDX-License-Identifier: 0BSD
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

import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace.dart';
import '../../providers/workspace_providers.dart';

class WorkspaceEnvironmentTile extends ConsumerWidget {
  const WorkspaceEnvironmentTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final isOwner = ref.watch(myMemberProvider).value?.isOwner ?? false;
    if (workspace == null || !isOwner) return const SizedBox.shrink();
    return ListTile(
      key: const ValueKey('workspace-environment'),
      leading: Icon(workspace.isDevelopment
          ? Icons.construction_outlined
          : Icons.verified_outlined),
      title: Text(l10n?.environmentLabel ?? 'Workspace type'),
      subtitle: Text(
        workspace.isDevelopment
            ? (l10n?.environmentDev ?? 'Development — for trying things out')
            : (l10n?.environmentProd ?? 'Production — the invoices are owed'),
      ),
      trailing: Switch(
        key: const ValueKey('workspace-environment-switch'),
        value: !workspace.isDevelopment,
        onChanged: (toProduction) =>
            _set(context, ref, workspace, toProduction: toProduction),
      ),
    );
  }

  Future<void> _set(
    BuildContext context,
    WidgetRef ref,
    Workspace workspace, {
    required bool toProduction,
  }) async {
    final l10n = AppLocalizations.of(context);
    if (toProduction) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: const ValueKey('workspace-environment-confirm'),
          title: Text(l10n?.environmentProdConfirmTitle ??
              'Declare this workspace production?'),
          content: Text(l10n?.environmentProdConfirmBody ??
              'The banner goes away and documents lose their watermark. '
                  'Invoices already issued do not change.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n?.commonCancel ?? 'Cancel'),
            ),
            FilledButton(
              key: const ValueKey('workspace-environment-confirm-yes'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                  l10n?.environmentProdConfirmAction ?? 'Declare production'),
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
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
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
      l10n?.environmentSaved ?? 'Workspace type saved.',
    );
  }
}
