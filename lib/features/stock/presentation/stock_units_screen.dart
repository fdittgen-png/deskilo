// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4435 (G20) -- the handling units: the pallets, cartons and boxes of the business, at one place or everywhere. A unit is made from
// stock that is loose at a place, moves with its whole content in one request (every lot and piece keeps its trace), is unpacked
// where it stands, and is repackaged into the store's own boxes without a balance changing. The server answers and refuses; a
// failure to read says so and reads again.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/i18n/format_controller.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/app_snack.dart';
import '../../../core/ui/dropdown_field.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/handling_units.dart';
import '../domain/stock_config.dart';
import '../providers/stock_providers.dart';
import 'handling_unit_sheets.dart';
import 'stock_config_text.dart';
import 'stock_page_shell.dart';

class StockUnitsScreen extends ConsumerStatefulWidget {
  const StockUnitsScreen({super.key});

  @override
  ConsumerState<StockUnitsScreen> createState() => _StockUnitsState();
}

class _StockUnitsState extends ConsumerState<StockUnitsScreen> {
  String? _place;

  void _told(String text) => AppSnack.success(context, text);

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
    return StockPageShell(
      title: l10n.stockUnitsTitle,
      anchor: HelpAnchor.moneyStockUnits,
      floatingActionButton: (ref, workspaceId) => FloatingActionButton.extended(
        key: const ValueKey('stock-units-make'),
        onPressed: () => _make(workspaceId),
        icon: const Icon(Icons.add),
        label: Text(l10n.stockUnitMake),
      ),
      body: (context, ref, workspaceId) => ListView(
        padding: const EdgeInsets.all(AppSpacing.md).add(const EdgeInsets.only(bottom: kFabSafeBottom)),
        children: [
          Text(l10n.stockUnitsIntro),
          const SizedBox(height: AppSpacing.md),
          _PlaceFilter(key: const ValueKey('stock-units-place-filter'), workspaceId: workspaceId, place: _place, onChanged: (v) => setState(() => _place = v)),
          const SizedBox(height: AppSpacing.md),
          _Units(workspaceId: workspaceId, place: _place, onOpen: (u) => _open(workspaceId, u)),
        ],
      ),
    );
  }

  Future<void> _open(String workspaceId, HandlingUnit unit) => showAppSheet<void>(
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
  const _PlaceFilter({super.key, required this.workspaceId, required this.place, required this.onChanged});

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
    return StockRead(
      keyName: 'stock-units',
      value: ref.watch(handlingUnitListProvider(key)),
      onRetry: () => ref.invalidate(handlingUnitListProvider(key)),
      isEmpty: (page) => page.rows.isEmpty,
      empty: l10n.stockUnitsEmpty,
      data: (page) => Column(
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
                      _UnitContent(detail: d),
                      if (d.unit.isOpen) ...[
                        const SizedBox(height: AppSpacing.md),
                        _UnitActions(workspaceId: workspaceId, detail: d, places: places, changed: changed),
                        Text(l10n.stockUnitUnpackHint, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// The unit's head line and what it holds.
class _UnitContent extends StatelessWidget {
  const _UnitContent({required this.detail});

  final HandlingUnitDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final d = detail;
    return Column(
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
            trailing: Text('${appFormatOf(context).quantity(l.quantity)} ${l.unit}'),
          ),
        for (final c in d.children) ListTile(contentPadding: EdgeInsets.zero, title: Text(c.code), subtitle: Text(l10n.stockUnitNestedIn(d.unit.code))),
      ],
    );
  }
}

/// Move, repack and unpack of an open unit.
class _UnitActions extends ConsumerWidget {
  const _UnitActions({required this.workspaceId, required this.detail, required this.places, required this.changed});

  final String workspaceId;
  final HandlingUnitDetail detail;
  final Future<List<StockPlaceConfig>> Function() places;
  final void Function(String text) changed;

  Future<void> _move(BuildContext context, StockHandlingUnits units) async {
    final nav = Navigator.of(context);
    final l10n = context.l10n;
    final all = await places();
    if (!context.mounted) return;
    await showMoveUnitSheet(
      context,
      units,
      workspaceId: workspaceId,
      unit: detail.unit,
      places: all,
      onDone: (moved, place) async {
        nav.pop();
        changed(l10n.stockUnitMoved(moved.code, place));
      },
    );
  }

  Future<void> _repack(BuildContext context, StockHandlingUnits units) async {
    final nav = Navigator.of(context);
    final l10n = context.l10n;
    await showRepackSheet(
      context,
      units,
      workspaceId: workspaceId,
      detail: detail,
      onDone: (made) async {
        nav.pop();
        changed(l10n.stockUnitRepacked(made.length));
      },
    );
  }

  Future<void> _unpackIt(BuildContext context, StockHandlingUnits units) async {
    final nav = Navigator.of(context);
    final l10n = context.l10n;
    final text = l10n.stockUnitUnpacked(detail.unit.code);
    final failure = await _unpack(l10n, units, detail.unit);
    if (failure != null) {
      if (context.mounted) AppSnack.error(context, failure);
      return;
    }
    nav.pop();
    changed(text);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = ref.read(stockHandlingUnitsProvider);
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        FilledButton(key: const ValueKey('stock-unit-move'), onPressed: () => _move(context, units), child: Text(l10n.stockUnitMove)),
        OutlinedButton(key: const ValueKey('stock-unit-repack'), onPressed: () => _repack(context, units), child: Text(l10n.stockUnitRepack)),
        TextButton(key: const ValueKey('stock-unit-unpack'), onPressed: () => _unpackIt(context, units), child: Text(l10n.stockUnitUnpack)),
      ],
    );
  }

  Future<String?> _unpack(AppLocalizations l10n, StockHandlingUnits units, HandlingUnit unit) async {
    try {
      await units.unpack(workspaceId, newRequestId(), unitId: unit.id, revision: unit.revision);
      return null;
    } on StockConfigFailure catch (e, st) {
      TraceLogger.instance.error('stock', 'a unit could not be unpacked', error: e.runtimeType, stackTrace: st);
      return stockSaveProblem(l10n, e);
    }
  }
}
