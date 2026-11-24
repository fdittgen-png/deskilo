// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4435 (G20) -- the handling units: the pallets, cartons and boxes of the business, at one place or everywhere. A unit is made from
// stock that is loose at a place, moves with its whole content in one request (every lot and piece keeps its trace), is unpacked
// where it stands, and is repackaged into the store's own boxes without a balance changing. The server answers and refuses; a
// failure to read says so and reads again.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/help/help_dot.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/dropdown_field.dart';
import '../../../core/ui/kit/page_title.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/handling_units.dart';
import '../domain/stock_config.dart';
import '../providers/stock_providers.dart';
import 'handling_unit_sheets.dart';
import 'stock_config_text.dart';

class StockUnitsScreen extends ConsumerStatefulWidget {
  const StockUnitsScreen({super.key});

  @override
  ConsumerState<StockUnitsScreen> createState() => _StockUnitsState();
}

class _StockUnitsState extends ConsumerState<StockUnitsScreen> {
  String? _place;

  void _told(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _read(String workspaceId, {String? unitId}) {
    ref.invalidate(handlingUnitListProvider);
    if (unitId != null) ref.invalidate(handlingUnitProvider((workspaceId: workspaceId, unitId: unitId)));
  }

  Future<void> _make(String workspaceId) async {
    final l10n = context.l10n;
    final places = _real(await ref.read(stockPlaceConfigsProvider(workspaceId).future));
    final items = await ref.read(stockItemsProvider(workspaceId).future);
    if (!mounted) return;
    await showMakeUnitSheet(
      context,
      ref.read(stockHandlingUnitsProvider),
      workspaceId: workspaceId,
      places: places,
      items: items,
      onDone: (made) async {
        _read(workspaceId);
        if (mounted) _told(l10n.stockUnitMade(made.code));
      },
    );
  }

  static List<StockPlaceConfig> _real(List<StockPlaceConfig> all) => [for (final p in all) if (p.active && !p.virtual) p];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final workspaceId = ref.watch(currentWorkspaceProvider).value?.id;
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.stockUnitsTitle),
        actions: [HelpDot(l10n.stockUnitsTitle, anchor: HelpAnchor.moneyStockUnits)],
      ),
      floatingActionButton: workspaceId == null
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('stock-units-make'),
              onPressed: () => _make(workspaceId),
              icon: const Icon(Icons.add),
              label: Text(l10n.stockUnitMake),
            ),
      body: workspaceId == null
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(l10n.stockUnitsIntro),
                const SizedBox(height: AppSpacing.md),
                _PlaceFilter(workspaceId: workspaceId, place: _place, onChanged: (v) => setState(() => _place = v)),
                const SizedBox(height: AppSpacing.md),
                _Units(workspaceId: workspaceId, place: _place, onOpen: (u) => _open(workspaceId, u)),
              ],
            ),
    );
  }

  Future<void> _open(String workspaceId, HandlingUnit unit) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => _UnitSheet(
      workspaceId: workspaceId,
      unitId: unit.id,
      places: () async => _real(await ref.read(stockPlaceConfigsProvider(workspaceId).future)),
      changed: (text) {
        _read(workspaceId, unitId: unit.id);
        if (mounted) _told(text);
      },
    ),
  );
}

class _PlaceFilter extends ConsumerWidget {
  const _PlaceFilter({required this.workspaceId, required this.place, required this.onChanged});

  final String workspaceId;
  final String? place;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(stockPlaceConfigsProvider(workspaceId)).value ?? const []; // empty-ok: a place is a choice, not a need
    return AppDropdownField<String?>(
      key: const ValueKey('stock-units-place'),
      label: context.l10n.stockUnitPlace,
      value: place,
      items: [(null, context.l10n.stockUnitsAllPlaces), for (final p in places) if (p.active && !p.virtual) (p.id, p.code)],
      onChanged: onChanged,
    );
  }
}

class _Units extends ConsumerWidget {
  const _Units({required this.workspaceId, required this.place, required this.onOpen});

  final String workspaceId;
  final String? place;
  final ValueChanged<HandlingUnit> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final key = (workspaceId: workspaceId, locationId: place);
    return ref.watch(handlingUnitListProvider(key)).when(
      loading: () => const LoadingView(),
      error: (e, _) => Column(
        children: [
          Text(l10n.stockUnitsReadFailed),
          TextButton(key: const ValueKey('stock-units-retry'), onPressed: () => ref.invalidate(handlingUnitListProvider(key)), child: Text(l10n.identityConnectRetry)),
        ],
      ),
      data: (page) => page.rows.isEmpty
          ? Text(l10n.stockUnitsEmpty, key: const ValueKey('stock-units-empty'))
          : Column(
              children: [
                for (final u in page.rows)
                  ListTile(
                    key: ValueKey('stock-unit-${u.code}'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(u.code),
                    subtitle: Text([unitKindText(l10n, u.kind), u.locationCode, if (u.labelCode != null) u.labelCode!].join(' · ')),
                    onTap: () => onOpen(u),
                  ),
              ],
            ),
    );
  }
}

class _UnitSheet extends ConsumerWidget {
  const _UnitSheet({required this.workspaceId, required this.unitId, required this.places, required this.changed});

  final String workspaceId;
  final String unitId;
  final Future<List<StockPlaceConfig>> Function() places;
  final void Function(String text) changed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = ref.read(stockHandlingUnitsProvider);
    final detail = ref.watch(handlingUnitProvider((workspaceId: workspaceId, unitId: unitId)));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: detail.when(
          loading: () => const LoadingView(),
          error: (e, _) => Text(l10n.stockUnitsReadFailed),
          data: (d) => d == null
              ? Text(l10n.stockUnitsReadFailed)
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('${d.unit.code} · ${unitKindText(l10n, d.unit.kind)} · ${d.unit.locationCode}', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      Text(l10n.stockUnitContent, style: Theme.of(context).textTheme.labelLarge),
                      if (d.lines.isEmpty) Text(l10n.stockUnitContentNone),
                      for (final l in d.lines)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l.itemName),
                          subtitle: Text([if (l.lotCode.isNotEmpty) l.lotCode, for (final p in l.pieces) if (p.tag.isNotEmpty) p.tag].join(' · ')),
                          trailing: Text('${l.quantity.text} ${l.unit}'),
                        ),
                      for (final c in d.children) ListTile(contentPadding: EdgeInsets.zero, title: Text(c.code), subtitle: Text(l10n.stockUnitNestedIn(d.unit.code))),
                      if (d.unit.isOpen) ...[
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.sm,
                          children: [
                            FilledButton(
                              key: const ValueKey('stock-unit-move'),
                              onPressed: () async {
                                final nav = Navigator.of(context);
                                final all = await places();
                                if (!context.mounted) return;
                                await showMoveUnitSheet(
                                  context,
                                  units,
                                  workspaceId: workspaceId,
                                  unit: d.unit,
                                  places: all,
                                  onDone: (moved, place) async {
                                    nav.pop();
                                    changed(l10n.stockUnitMoved(moved.code, place));
                                  },
                                );
                              },
                              child: Text(l10n.stockUnitMove),
                            ),
                            OutlinedButton(
                              key: const ValueKey('stock-unit-repack'),
                              onPressed: () async {
                                final nav = Navigator.of(context);
                                await showRepackSheet(
                                  context,
                                  units,
                                  workspaceId: workspaceId,
                                  detail: d,
                                  onDone: (made) async {
                                    nav.pop();
                                    changed(l10n.stockUnitRepacked(made.length));
                                  },
                                );
                              },
                              child: Text(l10n.stockUnitRepack),
                            ),
                            TextButton(
                              key: const ValueKey('stock-unit-unpack'),
                              onPressed: () async {
                                final nav = Navigator.of(context);
                                final text = l10n.stockUnitUnpacked(d.unit.code);
                                final failure = await _unpack(l10n, units, d.unit);
                                if (failure != null && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure)));
                                  return;
                                }
                                nav.pop();
                                changed(text);
                              },
                              child: Text(l10n.stockUnitUnpack),
                            ),
                          ],
                        ),
                        Text(l10n.stockUnitUnpackHint, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Future<String?> _unpack(AppLocalizations l10n, StockHandlingUnits units, HandlingUnit unit) async {
    try {
      await units.unpack(workspaceId, newRequestId(), unitId: unit.id, revision: unit.revision);
      return null;
    } on StockConfigFailure catch (e) {
      return stockSaveProblem(l10n, e);
    }
  }
}
