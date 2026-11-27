// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4480 -- the sections of an item's page that read beyond the registry: where the item is, its group and tags,
// its variants and its supplier articles. Each reads what it shows itself, says a failed read with Try again, and
// opens the editor the business already has from its worded action; a save reads the section again.
// #4483 -- the actions are the item's declared ones (stock_item_actions.dart), as on the list's chips and toolbar.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/format_controller.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/navigation/routes.dart';
import '../../../core/ui/kit/kit_action_button.dart';
import '../../../core/ui/kit/kit_metrics.dart';
import '../../money/domain/service_item.dart';
import '../domain/stock_registry.dart';
import '../providers/stock_item_providers.dart';
import '../providers/stock_providers.dart';
import 'stock_item_actions.dart';
import 'stock_item_sections.dart';
import 'stock_read_failed.dart';

/// The item's group (where the business keeps groups) and its tags (where it keeps them).
class StockItemGroupSection extends ConsumerWidget {
  const StockItemGroupSection({
    super.key,
    required this.workspaceId,
    required this.row,
    required this.services,
    required this.groupsOn,
    required this.tagsOn,
  });

  final String workspaceId;

  /// The item's own row of the registry.
  final StockRegistryRow row;

  /// The business's services, for the item's name.
  final List<ServiceItem> services;
  final bool groupsOn;
  final bool tagsOn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final acts = StockItemActions(context, ref, workspaceId: workspaceId, services: services);
    final key = (workspaceId: workspaceId, itemId: row.itemId);
    final group = groupsOn ? ref.watch(stockItemGroupNameProvider(key)) : null;
    return StockItemSection(
      key: const ValueKey('stock-item-section-group'),
      title: l10n.stockItemSectionGroupTags,
      lines: [
        if (group != null)
          switch (group) {
            AsyncValue(hasValue: true, :final value) => StockItemFact(
              label: l10n.documentsColGroup,
              value: value ?? l10n.stockItemNoGroup,
            ),
            AsyncValue(:final error?) => StockReadFailed(
              keyName: 'stock-item-group',
              error: error,
              onRetry: () => ref.invalidate(stockItemGroupNameProvider(key)),
            ),
            _ => const LinearProgressIndicator(),
          },
      ],
      actions: [
        if (groupsOn)
          KitActionButton(
            key: stockItemActionKey(StockItemActionKind.group, row),
            label: l10n.stockItemEditGroup,
            tonal: true,
            showProgress: false,
            onPressed: () => acts.editGroup(row),
          ),
        if (tagsOn)
          KitActionButton(
            key: stockItemActionKey(StockItemActionKind.tags, row),
            label: l10n.stockItemEditTags,
            tonal: true,
            showProgress: false,
            onPressed: () => acts.editTags(row),
          ),
      ],
    );
  }
}

/// The item's variants in use, each with its own price where it has one.
class StockItemVariantsSection extends ConsumerWidget {
  const StockItemVariantsSection({
    super.key,
    required this.workspaceId,
    required this.row,
    required this.services,
    required this.mayManage,
  });

  final String workspaceId;

  /// The item's own row of the registry.
  final StockRegistryRow row;

  /// The business's services, for the item's name.
  final List<ServiceItem> services;
  final bool mayManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final format = appFormatOf(context);
    final key = (workspaceId: workspaceId, itemId: row.itemId);
    final read = ref.watch(stockItemVariantsProvider(key));
    return StockItemSection(
      key: const ValueKey('stock-item-section-variants'),
      title: l10n.stockItemSectionVariants,
      lines: [
        switch (read) {
          AsyncValue(hasValue: true, :final value?) when value.isEmpty => Text(
            l10n.stockItemNoVariants,
          ),
          AsyncValue(hasValue: true, :final value?) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final v in value)
                StockItemLine(
                  key: ValueKey('stock-item-variant-${v.id}'),
                  title: v.label,
                  subtitle: v.priceCents == null
                      ? null
                      : format.money(v.priceCents!),
                ),
            ],
          ),
          AsyncValue(:final error?) => StockReadFailed(
            keyName: 'stock-item-variants',
            error: error,
            onRetry: () => ref.invalidate(stockItemVariantsProvider(key)),
          ),
          _ => const LinearProgressIndicator(),
        },
      ],
      actions: [
        if (mayManage)
          KitActionButton(
            key: stockItemActionKey(StockItemActionKind.variants, row),
            label: l10n.stockItemEditVariants,
            tonal: true,
            showProgress: false,
            onPressed: () => StockItemActions(context, ref, workspaceId: workspaceId, services: services).editVariants(row),
          ),
      ],
    );
  }
}

/// The supplier articles that name the item, each with its supplier.
class StockItemSuppliersSection extends ConsumerWidget {
  const StockItemSuppliersSection({
    super.key,
    required this.workspaceId,
    required this.row,
    required this.services,
  });

  final String workspaceId;

  /// The item's own row of the registry.
  final StockRegistryRow row;

  /// The business's services, for the item's name.
  final List<ServiceItem> services;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final key = (workspaceId: workspaceId, itemId: row.itemId);
    final read = ref.watch(stockItemMappingsProvider(key));
    return StockItemSection(
      key: const ValueKey('stock-item-section-suppliers'),
      title: l10n.stockItemSectionSuppliers,
      lines: [
        switch (read) {
          AsyncValue(hasValue: true, :final value?)
              when value.mappings.isEmpty =>
            Text(l10n.stockItemNoSuppliers),
          AsyncValue(hasValue: true, :final value?) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final m in value.mappings)
                StockItemLine(
                  key: ValueKey('stock-item-supplier-${m.id}'),
                  title: m.articleRef,
                  subtitle: value.suppliers
                      .where((s) => s.id == m.supplierId)
                      .firstOrNull
                      ?.name,
                ),
            ],
          ),
          AsyncValue(:final error?) => StockReadFailed(
            keyName: 'stock-item-suppliers',
            error: error,
            onRetry: () => ref.invalidate(stockItemMappingsProvider(key)),
          ),
          _ => const LinearProgressIndicator(),
        },
      ],
      actions: [
        KitActionButton(
          key: stockItemActionKey(StockItemActionKind.suppliers, row),
          label: l10n.stockItemEditSuppliers,
          tonal: true,
          showProgress: false,
          onPressed: () => StockItemActions(context, ref, workspaceId: workspaceId, services: services).editSuppliers(row),
        ),
      ],
    );
  }
}

/// Where the item is: its first places with what lies there, and the way to every place.
class StockItemPlaces extends ConsumerWidget {
  const StockItemPlaces({
    super.key,
    required this.workspaceId,
    required this.itemId,
  });

  final String workspaceId;
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final format = appFormatOf(context);
    final filter = (workspaceId: workspaceId, itemId: itemId, locationId: null);
    final walk = ref.watch(stockOnHandWalkProvider(filter));
    final children = <Widget>[
      Text(
        l10n.stockItemPlacesTitle,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      if (walk.error != null)
        StockReadFailed(
          keyName: 'stock-item-places',
          error: walk.error!,
          onRetry: () => unawaited(
            ref.read(stockOnHandWalkProvider(filter).notifier).reload(),
          ),
        )
      else if (walk.isFirstLoad)
        const LinearProgressIndicator()
      else if (walk.rows.isEmpty)
        Text(l10n.stockItemNothingOnHand)
      else
        for (final r in walk.rows.take(KitMetrics.previewRows))
          StockItemLine(
            key: ValueKey(
              'stock-item-place-${r.locationId}-${r.variantId}-${r.lotId}',
            ),
            title: r.variantLabel == null
                ? r.locationLabel
                : '${r.locationLabel} · ${r.variantLabel}',
            subtitle: l10n.stockQuantityWithUnit(
              format.quantity(r.quantity),
              r.unit,
            ),
          ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(
          key: ValueKey('stock-item-where-$itemId'),
          onPressed: () => unawaited(context.push(Routes.stockWhere(itemId))),
          child: Text(l10n.stockItemSeeWhere),
        ),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
