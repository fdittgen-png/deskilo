// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4480 -- what an item's page shows, a section at a time, each with its own worded actions that open the editors
// the business already has (no second editor): name, price and VAT in the service editor; the home place, the
// stock settings, the group, the tags, the variants and the supplier articles in theirs. The rights decide the
// actions as the server does: `manageServices` for name, price and VAT, `manageStock` for the rest; a reader sees
// the sections and no action. A save reads the item again, so the page shows what was saved.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/format_controller.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/form_kit.dart';
import '../../../core/ui/kit/kit_action_button.dart';
import '../../../core/ui/kit/status_chip.dart';
import '../../../l10n/app_localizations.dart';
import '../../money/domain/service_item.dart';
import '../../money/presentation/vat_price_label.dart';
import '../../money/presentation/widgets/service_sheet.dart';
import '../../money/providers/money_providers.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/stock_config.dart';
import '../domain/stock_item_attention.dart';
import '../domain/stock_registry.dart';
import '../providers/stock_item_providers.dart';
import '../providers/stock_providers.dart';
import 'stock_home_sheet.dart';
import 'stock_item_editor.dart';
import 'stock_item_parts.dart';
import 'stock_item_sections.dart';

/// The words of what an item needs.
String stockAttentionText(AppLocalizations l10n, StockAttention a) =>
    switch (a) {
      StockAttention.belowReorder => l10n.stockItemAttentionLow,
      StockAttention.noPrice => l10n.stockItemAttentionNoPrice,
      StockAttention.noPlace => l10n.stockItemAttentionNoPlace,
    };

/// The sections of the item [itemId], from its registry [rows] (the item, or one row per variant) and its
/// [service] (null when it cannot be read: no Edit of name, price and VAT then).
class StockItemView extends ConsumerWidget {
  const StockItemView({
    super.key,
    required this.workspaceId,
    required this.itemId,
    required this.rows,
    required this.service,
    required this.services,
  });

  final String workspaceId;
  final String itemId;
  final List<StockRegistryRow> rows;
  final ServiceItem? service;

  /// The business's services, whose categories the service editor proposes.
  final List<ServiceItem> services;

  StockRegistryRow get _main =>
      rows.where((r) => r.variantId == null).firstOrNull ?? rows.first;

  String get _name => service?.name ?? _main.itemName;

  void _saved(BuildContext context, WidgetRef ref) {
    if (context.mounted) reloadStockRegistry(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final held = ref.watch(myPermissionsProvider);
    final mayManage = held.contains(WorkspacePermission.manageStock);
    final features = ref.watch(enabledFeaturesSyncProvider);
    final groupsOn = features.contains(WorkspaceFeature.stockItemGroups);
    final tagsOn = ref.watch(stockTagsProvider);
    final low = ref.watch(stockLowKeysProvider(workspaceId));
    final attention = {
      for (final r in rows) ...stockAttentionOf(r, low),
    }.toList()..sort((a, b) => a.index.compareTo(b.index));
    // A handful of sections: all of them built, so each is found and read where it stands.
    return SingleChildScrollView(
      key: ValueKey('stock-item-sections-$itemId'),
      padding: AppSpacing.gutterAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (attention.isNotEmpty) ...[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final a in attention)
                  StatusChip(
                    key: ValueKey('stock-item-attention-${a.name}'),
                    label: stockAttentionText(l10n, a),
                    tone: StatusTone.warn,
                  ),
              ],
            ),
            const FormGap(),
          ],
          _overview(
            context,
            ref,
            held.contains(WorkspacePermission.manageServices),
          ),
          _stock(context, ref, mayManage),
          if (mayManage && (groupsOn || tagsOn))
            StockItemGroupSection(
              workspaceId: workspaceId,
              itemId: itemId,
              name: _name,
              groupsOn: groupsOn,
              tagsOn: tagsOn,
            ),
          StockItemVariantsSection(
            workspaceId: workspaceId,
            itemId: itemId,
            name: _name,
            mayManage: mayManage,
          ),
          if (mayManage)
            StockItemSuppliersSection(
              workspaceId: workspaceId,
              itemId: itemId,
              name: _name,
            ),
        ],
      ),
    );
  }

  Widget _overview(BuildContext context, WidgetRef ref, bool mayEditService) {
    final l10n = context.l10n;
    final format = appFormatOf(context);
    final main = _main;
    final price = service?.priceCents ?? main.priceCents;
    final vat = service == null
        ? null
        : vatRateSuffix(
            chargesVat:
                ref.watch(currentWorkspaceProvider).value?.vatRegime ==
                'vat_registered',
            rates: ref.watch(vatRatesProvider).value ?? const [], // empty-ok: an unread rate names no VAT, never a wrong one
            vatRateId: service!.vatRateId,
            format: format,
          );
    final cost = !main.costVisible
        ? l10n.stockRegistryCostHidden
        : main.costMinor == null
        ? l10n.stockRegistryCostUnknown
        : format.money(main.costMinor!);
    final editable = service;
    return StockItemSection(
      key: const ValueKey('stock-item-section-overview'),
      title: l10n.stockItemSectionOverview,
      lines: [
        StockItemFacts(
          facts: [
            StockItemFact(
              label: l10n.servicesPrice,
              value: price == null
                  ? l10n.stockItemAttentionNoPrice
                  : format.money(price),
            ),
            if (vat != null)
              StockItemFact(label: l10n.stockItemFactVat, value: vat),
            if (main.unit.isNotEmpty)
              StockItemFact(label: l10n.standaloneInvoiceLineUnit, value: main.unit),
            if (main.barcode case final code?)
              StockItemFact(label: l10n.stockItemFactBarcode, value: code),
            StockItemFact(label: l10n.stockItemFactCost, value: cost),
          ],
        ),
      ],
      actions: [
        if (mayEditService && editable != null)
          KitActionButton(
            key: ValueKey('stock-item-edit-$itemId'),
            label: l10n.stockItemEditDetails,
            tonal: true,
            showProgress: false,
            onPressed: () async {
              await ServiceEditor.open(
                context,
                ref,
                workspaceId: workspaceId,
                service: editable,
                categories: [for (final s in services) s.category],
              );
              if (context.mounted) _saved(context, ref);
            },
          ),
      ],
    );
  }

  Widget _stock(BuildContext context, WidgetRef ref, bool mayManage) {
    final l10n = context.l10n;
    final format = appFormatOf(context);
    final separator = ref.watch(stockAddressSeparatorProvider);
    // The places only feed the home place's choice.
    final places =
        ref.watch(stockPlaceConfigsProvider(workspaceId)).value ??
        const <StockPlaceConfig>[]; // empty-ok: a choice
    final lotsOn = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.stockLots);
    String home(StockRegistryRow r) => switch (r.homeAddressPath) {
      final path? => l10n.stockRegistryHome(
        path.split(stockAddressJoint).join(separator),
      ),
      null => l10n.stockRegistryNoHome,
    };
    String onHand(StockRegistryRow r) => l10n.stockRegistryOnHand(
      l10n.stockQuantityWithUnit(format.quantity(r.onHand), r.unit),
    );
    return StockItemSection(
      key: const ValueKey('stock-item-section-stock'),
      title: l10n.stockItemSectionStock,
      lines: [
        for (final r in rows)
          StockItemLine(
            key: ValueKey('stock-item-stock-${r.key}'),
            title: r.variantLabel ?? onHand(r),
            subtitle: r.variantLabel == null
                ? home(r)
                : '${onHand(r)} · ${home(r)}',
            action: !mayManage
                ? null
                : TextButton.icon(
                    key: ValueKey('stock-home-${r.key}'),
                    icon: const Icon(Icons.place_outlined),
                    label: Text(l10n.stockItemEditHome),
                    onPressed: () async {
                      final saved = await showStockHomeSheet(
                        context,
                        ref.read(stockRegistryProvider),
                        workspaceId: workspaceId,
                        row: r,
                        places: places,
                        separator: separator,
                      );
                      if (saved && context.mounted) _saved(context, ref);
                    },
                  ),
          ),
        const FormGap.small(),
        StockItemPlaces(workspaceId: workspaceId, itemId: itemId),
      ],
      actions: [
        if (mayManage)
          KitActionButton(
            key: ValueKey('stock-edit-item-$itemId'),
            label: l10n.stockItemEditSettings,
            tonal: true,
            showProgress: false,
            onPressed: () async {
              final saved = await showStockItemEditor(
                context,
                ref.read(stockConfigCommandsProvider),
                workspaceId: workspaceId,
                itemId: itemId,
                itemName: _name,
                options: (
                  lots: lotsOn,
                  keep: false,
                  groups: itemGroupsIfOn(ref),
                ),
              );
              if (saved && context.mounted) _saved(context, ref);
            },
          ),
      ],
    );
  }
}
