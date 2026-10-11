// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../domain/workspace_application.dart';
import '../../providers/workspace_application_providers.dart';
import '../application_status_label.dart';
import '../widgets/workspace_application_thread.dart';

/// Account history: reachable with no active membership, including refusals.
class WorkspaceApplicationsScreen extends ConsumerStatefulWidget {
  const WorkspaceApplicationsScreen({super.key});
  @override
  ConsumerState<WorkspaceApplicationsScreen> createState() =>
      _ApplicationsState();
}

class _ApplicationsState extends ConsumerState<WorkspaceApplicationsScreen> {
  String? _account;
  final _pages = <ApplicationCursor>[];
  @override
  Widget build(BuildContext context) {
    final account = ref.watch(authStateProvider).value;
    if (_account != account) {
      _account = account;
      _pages.clear();
    }
    final l10n = context.l10n;
    final provider = workspaceApplicationsProvider(before: _pages.lastOrNull);
    final applications = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.applicationsTitle),
        actions: [
          IconButton(
            key: const ValueKey('workspace-applications-pending-approval-refresh'),
            tooltip: l10n.pendingApprovalRefresh,
            onPressed: () => ref.invalidate(provider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: account == null
          ? const SizedBox.shrink()
          : switch (applications) {
              AsyncData(value: final rows) => ListView(
                padding: AppSpacing.mdAll,
                children: [
                  Text(
                    l10n.applicationDiscussionHint,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (rows.isEmpty)
                    Text(l10n.applicationsEmpty),
                  for (final application in rows)
                    Card(
                      child: ListTile(
                        key: ValueKey('application-${application.id}'),
                        leading: Icon(
                          application.status == 'rejected'
                              ? Icons.person_off_outlined
                              : application.status == 'confirmed'
                              ? Icons.how_to_reg_outlined
                              : Icons.hourglass_top_outlined,
                        ),
                        title: Text(application.workspaceName),
                        subtitle: Text(
                          [
                            if (!application.isApplicant)
                              application.applicantName,
                            applicationStatusLabel(l10n, application.status),
                            MaterialLocalizations.of(
                              context,
                            ).formatShortDate(application.createdAt.toLocal()),
                          ].where((value) => value.isNotEmpty).join(' · '),
                        ),
                        trailing: const Icon(Icons.chat_bubble_outline),
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => WorkspaceApplicationThread(
                            application: application,
                            account: account,
                          ),
                        ),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        key: const ValueKey('workspace-applications-chevron-left'),
                        tooltip: MaterialLocalizations.of(context)
                            .previousPageTooltip,
                        onPressed: _pages.isEmpty
                            ? null
                            : () => setState(_pages.removeLast),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      IconButton(
                        key: const ValueKey('workspace-applications-chevron-right'),
                        tooltip: MaterialLocalizations.of(context)
                            .nextPageTooltip,
                        onPressed: rows.length < 50
                            ? null
                            : () =>
                                  setState(() => _pages.add(rows.last.cursor)),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ],
              ),
              AsyncError() => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.applicationsLoadFailed,
                    ),
                    TextButton(
                      key: const ValueKey('workspace-applications-retry'),
                      onPressed: () => ref.invalidate(provider),
                      child: Text(l10n.commonRetry),
                    ),
                  ],
                ),
              ),
              _ => const LoadingView(),
            },
    );
  }
}
