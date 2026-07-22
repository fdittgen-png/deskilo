// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/workspace_providers.dart';

/// The waiting room (0052): a freshly joined member is PENDING until the
/// workspace's validators approve. They see only the workspace name here
/// — no plan, no directory, no money — plus a re-check button, the
/// profile switcher (they may be active elsewhere) and sign-out.
class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.pendingApprovalTitle ?? 'Awaiting approval'),
        actions: [
          IconButton(
            icon: const Icon(Icons.switch_account_outlined),
            tooltip: l10n?.profilesTitle ?? 'Profiles',
            onPressed: () => context.push('/profiles'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: AppSpacing.xlAll,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.hourglass_top_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  workspace?.name ?? '',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n?.pendingApprovalBody(workspace?.name ?? '') ??
                      'You have joined ${workspace?.name ?? ''}. An '
                          'administrator must approve your membership '
                          'before you can use the workspace — you will '
                          'get access as soon as they confirm.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  key: const ValueKey('pending-refresh'),
                  onPressed: () => ref
                    ..invalidate(myWorkspacesProvider)
                    ..invalidate(myMemberProvider),
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    l10n?.pendingApprovalRefresh ?? 'Check again',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
