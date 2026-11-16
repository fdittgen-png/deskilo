// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3554 — a business's page lists the services it published, grouped by
// category in the order the business gave them, each with its duration,
// its price in its own currency (named: the page is a personal surface)
// and what that price means for tax. Nothing is added up or compared.
// Where the business takes inquiries, a service opens one that names it.
import 'package:flutter/material.dart';

import '../../../core/i18n/format_controller.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/public_workspace.dart';
import 'public_service_line.dart';

/// The services by category: categories in the order their first service
/// appears, the services without one last.
@visibleForTesting
List<({String? category, List<(int, PublicService)> services})>
publicServiceGroups(List<PublicService> services) {
  final groups = <String?, List<(int, PublicService)>>{};
  for (final (i, s) in services.indexed) {
    final category = s.category?.trim();
    (groups[category == null || category.isEmpty ? null : category] ??= []).add(
      (i, s),
    );
  }
  final uncategorised = groups.remove(null);
  return [
    for (final MapEntry(:key, :value) in groups.entries)
      (category: key, services: value),
    if (uncategorised != null) (category: null, services: uncategorised),
  ];
}

class PublicServicesSection extends StatelessWidget {
  const PublicServicesSection({super.key, required this.services, this.onAsk});

  final List<PublicService> services;

  /// Opens an inquiry naming the service; null where none can be sent.
  final void Function(PublicService service)? onAsk;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final format = personalFormatOf(context);
    final groups = publicServiceGroups(services);
    final onAsk = this.onAsk;
    return Padding(
      key: const ValueKey('public-workspace-services'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.placeServicesTitle, style: theme.textTheme.titleMedium),
          for (final group in groups) ...[
            if (groups.length > 1 || group.category != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  group.category ?? l10n.placeServicesOther,
                  style: theme.textTheme.titleSmall,
                ),
              ),
            for (final (i, s) in group.services)
              _ServiceRow(
                key: ValueKey('public-workspace-service-$i'),
                index: i,
                service: s,
                terms: publicServiceTerms(
                  l10n,
                  s,
                  format.moneyNamed(s.currency).formatMinor(s.priceMinor),
                ),
                onAsk: onAsk == null ? null : () => onAsk(s),
              ),
          ],
        ],
      ),
    );
  }
}

/// One service: plain text, or, where an inquiry can be sent, a control of
/// at least 48 dp with its "Ask" affordance, named for assistive technology
/// by what it does ("Ask about Relaxing massage").
class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    super.key,
    required this.index,
    required this.service,
    required this.terms,
    this.onAsk,
  });

  final int index;
  final PublicService service;
  final String terms;
  final VoidCallback? onAsk;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final onAsk = this.onAsk;
    final tile = ListTile(
      key: ValueKey('public-workspace-service-ask-$index'),
      contentPadding: EdgeInsets.zero,
      minTileHeight: 48,
      title: Text(service.name),
      subtitle: Text(terms),
      trailing: onAsk == null
          ? null
          : Text(
              l10n.placeServiceAskShort,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
      onTap: onAsk,
    );
    if (onAsk == null) return tile;
    return Semantics(
      container: true,
      button: true,
      label: l10n.placeServiceAsk(service.name),
      hint: terms,
      // recorder-key-exempt: the row's action for assistive technology; the tile carries the key
      onTap: onAsk,
      excludeSemantics: true,
      child: tile,
    );
  }
}
