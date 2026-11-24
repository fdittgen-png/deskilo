// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #945 — the workspace's sites: each address, the levels that stand at
// it, and the establishment's registration. The default site carries
// the workspace's address; a level or a member with no site means it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/kit/page_bar.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../domain/site.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/site_edit_dialog.dart';

class SitesScreen extends ConsumerWidget {
  const SitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sites = ref.watch(sitesProvider);
    final levels = ref.watch(levelsProvider).value ?? const [];
    return Scaffold(
      appBar: pageBar(context, title: l10n.featureMultiSite),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('sites-add'),
        onPressed: () => _editSite(context, ref, null),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: Text(l10n.sitesAdd),
      ),
      body: switch (sites) {
        AsyncData(value: final rows) => ListView(
            // #1181 — the add button overlays this list; it ends above it.
            padding: AppSpacing.lgAll
                .add(const EdgeInsets.only(bottom: kFabSafeBottom)),
            children: [
              Text(
                l10n.sitesIntro,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              for (final site in rows)
                Card(
                  key: ValueKey('site-${site.id}'),
                  child: ListTile(
                    key: ValueKey('sites-default-${site.id}'),
                    leading: Icon(site.isDefault
                        ? Icons.home_work_outlined
                        : Icons.location_city_outlined),
                    title: Text(site.name),
                    subtitle: Text([
                      if (site.isDefault) l10n.sitesDefault,
                      if (site.hasAddress) site.postalBlock.replaceAll('\n', ' · '),
                      if (site.legalId.isNotEmpty) site.legalId,
                    ].join('\n')),
                    isThreeLine: site.hasAddress,
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _editSite(context, ref, site),
                  ),
                ),
              if (rows.length > 1 && levels.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(l10n.sitesLevels, style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                for (final level in levels)
                  ListTile(
                    key: ValueKey('site-level-${level.id}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(level.name),
                    trailing: DropdownButton<String>(
                      key: ValueKey('site-level-pick-${level.id}'),
                      value: rows.any((s) => s.id == level.siteId && !s.isDefault)
                          ? level.siteId
                          : '',
                      items: [
                        for (final s in rows)
                          DropdownMenuItem(
                            value: s.isDefault ? '' : s.id,
                            child: Text(s.name),
                          ),
                      ],
                      onChanged: (v) async {
                        final ok = await runGuarded(
                          context,
                          domain: 'workspace',
                          message: 'level site change failed',
                          errorText: l10n.workspaceGenericError,
                          action: () => ref
                              .read(floorPlanRepositoryProvider)
                              .setLevelSite(level.id, (v ?? '').isEmpty ? null : v),
                        );
                        if (ok) ref.invalidate(levelsProvider);
                      },
                    ),
                  ),
              ],
            ],
          ),
        AsyncError(:final error) => ReadFailureBanner(error: error, onRetry: () => ref.invalidate(sitesProvider)),
        _ => const LoadingView(),
      },
    );
  }

  Future<void> _editSite(BuildContext context, WidgetRef ref, Site? site) async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final result = await showDialog<SiteEditResult>(
      context: context,
      builder: (_) => SiteEditDialog(
        site: site,
        workspaceId: workspace.id,
        workspaceCountry: workspace.countryCode,
      ),
    );
    if (result == null || !context.mounted) return;
    final repo = ref.read(workspaceRepositoryProvider);
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'site save failed',
      errorText: l10n.workspaceGenericError,
      action: () async {
        if (result.delete) {
          await repo.deleteSite(result.draft.id);
          return;
        }
        await repo.upsertSite(workspace.id, result.draft, isNew: site == null);
      },
    );
    if (!context.mounted) return;
    ref
      ..invalidate(sitesProvider)
      ..invalidate(levelsProvider);
    if (ok && !result.delete) {
      AppSnack.success(context, l10n.siteSaved);
    }
  }
}
