// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/mcp_usage.dart';
import '../../providers/mcp_providers.dart';
import '../mcp_operation_labels.dart';

/// A count in the reader's number format.
String _count(BuildContext context, int n) => NumberFormat.decimalPattern(
  Localizations.maybeLocaleOf(context)?.toString(),
).format(n);

/// #1630 — the workspace's assistant use over the last 30 days, for its
/// owner: four counts and the busiest services. Counts only: no person
/// is named.
class McpWorkspaceUsageCard extends ConsumerWidget {
  const McpWorkspaceUsageCard({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final usage = ref.watch(mcpWorkspaceUsageProvider(workspaceId));
    return Card(
      key: const ValueKey('mcp-usage-workspace'),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n?.mcpUsageWorkspaceTitle ?? 'Assistant use, last 30 days',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            usage.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(
                key: const ValueKey('mcp-usage-workspace-unavailable'),
                l10n?.mcpUsageUnavailable ?? 'Usage could not be loaded.',
              ),
              data: (u) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  McpUsageFigures(counts: u.total),
                  for (final op in u.byOperation.take(5))
                    Row(
                      key: ValueKey('mcp-usage-op-${op.operation}'),
                      children: [
                        Expanded(
                          child: Text(
                            mcpOperationLabel(l10n, op.operation),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(_count(context, op.counts.requests)),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// #1630 — the person's own assistant use today, one line per assistant.
class McpMyUsageSection extends ConsumerWidget {
  const McpMyUsageSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final usage = ref.watch(myMcpUsageProvider);
    final format = DateFormat.yMd(
      Localizations.maybeLocaleOf(context)?.toString(),
    ).add_Hm();
    return Column(
      key: const ValueKey('mcp-usage-mine'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n?.mcpUsageMineTitle ?? 'Your assistant use today',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        usage.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(
            key: const ValueKey('mcp-usage-mine-unavailable'),
            l10n?.mcpUsageUnavailable ?? 'Usage could not be loaded.',
          ),
          data: (clients) => clients.isEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      key: const ValueKey('mcp-usage-mine-none'),
                      l10n?.mcpUsageNone ??
                          'No assistant has used your access yet.',
                    ),
                    const McpUsageFigures(counts: McpUsageCounts.zero),
                  ],
                )
              : Column(
                  children: [
                    for (final c in clients)
                      Card(
                        key: ValueKey('mcp-usage-client-${c.clientId}'),
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                c.clientName,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              McpUsageFigures(counts: c.today),
                              if (c.lastUsedAt != null)
                                Text(
                                  l10n?.mcpUsageLastUsed(
                                        format.format(c.lastUsedAt!.toLocal()),
                                      ) ??
                                      'Last used ${format.format(c.lastUsedAt!.toLocal())}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// The four counts side by side: requests, refused, applied, awaiting
/// validation.
class McpUsageFigures extends StatelessWidget {
  const McpUsageFigures({super.key, required this.counts});

  final McpUsageCounts counts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget figure(String key, int value, String label) => Padding(
      padding: const EdgeInsets.only(
        right: AppSpacing.lg,
        bottom: AppSpacing.sm,
      ),
      child: Column(
        key: ValueKey('mcp-usage-$key'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_count(context, value), style: theme.textTheme.titleLarge),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
    return Wrap(
      children: [
        figure(
          'requests',
          counts.requests,
          l10n?.mcpUsageRequests ?? 'Requests',
        ),
        figure(
          'refusals',
          counts.refusals,
          l10n?.mcpUsageRefusals ?? 'Refused',
        ),
        figure('applied', counts.applied, l10n?.mcpUsageApplied ?? 'Applied'),
        figure(
          'pending',
          counts.pendingValidation,
          l10n?.mcpUsagePending ?? 'Awaiting validation',
        ),
      ],
    );
  }
}
