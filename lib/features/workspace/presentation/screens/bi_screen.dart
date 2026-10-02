// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1923 A — Web-BI: the registered analytics modules, grouped by area.
// Areas without a module are not shown; each module renders its own
// consumer, which the server authorizes again.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/navigation_style.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/bi_modules.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/capacity_kpi_card.dart';

String biAreaName(AppLocalizations? l10n, BiArea area) => switch (area) {
  BiArea.overview => l10n?.biAreaOverview ?? 'Overview',
  BiArea.capacity => l10n?.biAreaCapacity ?? 'Space and capacity',
  BiArea.people => l10n?.biAreaPeople ?? 'People and business',
  BiArea.finance => l10n?.biAreaFinance ?? 'Finance',
  BiArea.treasury => l10n?.biAreaTreasury ?? 'Treasury',
  BiArea.operations => l10n?.biAreaOperations ?? 'Operations',
  BiArea.planning => l10n?.biAreaPlanning ?? 'Planning',
  BiArea.saved => l10n?.biAreaSaved ?? 'Saved analyses',
};

Widget _module(BiModule m) => switch (m.id) {
  'capacity.seat_utilisation' => const CapacityKpiCard(),
  _ => const SizedBox.shrink(),
};

class BiScreen extends ConsumerWidget {
  const BiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final modules = ref.watch(platformIsWebProvider)
        ? visibleBiModules(
            ref.watch(enabledFeaturesSyncProvider),
            ref.watch(myPermissionsProvider),
          )
        : const <BiModule>[];
    return Scaffold(
      appBar: AppBar(title: Text(l10n?.biTitle ?? 'Business analytics')),
      body: ListView(
        key: const ValueKey('bi-page'),
        children: [
          for (final area in BiArea.values)
            if (modules.any((m) => m.area == area)) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  0,
                ),
                child: Text(
                  biAreaName(l10n, area),
                  key: ValueKey('bi-area-${area.name}'),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              for (final m in modules.where((m) => m.area == area)) _module(m),
            ],
        ],
      ),
    );
  }
}
