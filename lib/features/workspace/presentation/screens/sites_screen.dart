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
import '../../../../core/ui/loading_view.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../domain/site.dart';
import '../../providers/workspace_providers.dart';

class SitesScreen extends ConsumerWidget {
  const SitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sites = ref.watch(sitesProvider);
    final levels = ref.watch(levelsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sitesTitle)),
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
        AsyncError(:final error) => Center(child: Text(error.toString())),
        _ => const LoadingView(),
      },
    );
  }

  Future<void> _editSite(BuildContext context, WidgetRef ref, Site? site) async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final name = TextEditingController(text: site?.name ?? '');
    final street = TextEditingController(text: site?.street ?? '');
    final postal = TextEditingController(text: site?.postalCode ?? '');
    final city = TextEditingController(text: site?.city ?? '');
    final country = TextEditingController(
        text: site?.countryCode ?? workspace.countryCode);
    final legal = TextEditingController(text: site?.legalId ?? '');
    final vat = TextEditingController(text: site?.vatId ?? '');
    final exemption = TextEditingController(text: site?.taxExemptionReason ?? '');
    Widget field(String key, TextEditingController c, String label) => TextField(
          key: ValueKey(key),
          controller: c,
          decoration: InputDecoration(labelText: label),
        );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(site == null
            ? (l10n.sitesAdd)
            : site.name),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            field('site-name', name, l10n.siteName),
            field('site-street', street, l10n.siteStreet),
            field('site-postal', postal, l10n.sitePostalCode),
            field('site-city', city, l10n.siteCity),
            field('site-country', country, l10n.siteCountry),
            field('site-legal', legal,
                l10n.siteLegalId),
            if (site != null && !site.isDefault) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.siteRegistrationHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              field('site-vat', vat, l10n.siteVatId),
              field('site-exemption', exemption,
                  l10n.siteExemptionReason),
            ],
            if (site != null && !site.isDefault) ...[
              const SizedBox(height: AppSpacing.md),
              Text(l10n.siteDeleteHint,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ]),
        ),
        actions: [
          if (site != null && !site.isDefault)
            TextButton(
              key: const ValueKey('site-delete'),
              onPressed: () => Navigator.of(context).pop('delete'),
              child: Text(l10n.siteDelete),
            ),
          TextButton(
            key: const ValueKey('sites-cancel'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const ValueKey('site-save'),
            onPressed: () => Navigator.of(context).pop('save'),
            child: Text(l10n.commonSave),
          ),
        ],
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
        if (result == 'delete') {
          await repo.deleteSite(site!.id);
          return;
        }
        final draft = Site(
          id: site?.id ?? '',
          workspaceId: workspace.id,
          name: name.text.trim(),
          street: street.text.trim(),
          postalCode: postal.text.trim(),
          city: city.text.trim(),
          countryCode: country.text.trim().toUpperCase(),
          legalId: legal.text.trim(),
          vatId: vat.text.trim(),
          taxExemptionReason: exemption.text.trim(),
          isDefault: site?.isDefault ?? false,
          sortOrder: site?.sortOrder ?? 0,
        );
        await repo.upsertSite(workspace.id, draft, isNew: site == null);
      },
    );
    if (!context.mounted) return;
    ref
      ..invalidate(sitesProvider)
      ..invalidate(levelsProvider);
    if (ok && result == 'save') {
      AppSnack.success(context, l10n.siteSaved);
    }
  }
}
