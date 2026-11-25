// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4169 (B1) -- the stock settings of one item: what is kept, bought and
// sold, its inventory unit, its package units (a package holds
// numerator / denominator of the inventory unit) and its codes. The lists
// shown are the complete lists the save sends. The save names the revision it
// read; a stale one, a refusal with its field and reason, and a unit fixed by
// the first movement are each said, and nothing is shown saved that was not.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../../../core/ui/form_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../application/stock_reads.dart';
import '../domain/item_groups.dart';
import '../domain/stock_config.dart';
import '../domain/stock_config_check.dart';
import '../domain/stock_config_commands.dart';
import 'stock_config_text.dart';
import 'stock_unit_picker.dart';

/// Opens the editor of [itemId]; true when something was saved. [options] says whether lots are asked for, whether the
/// item is kept in stock and, when the business has item groups, the port that tells which values the item keeps of its own.
Future<bool> showStockItemEditor(
  BuildContext context,
  StockConfigCommands commands, {
  required String workspaceId,
  required String itemId,
  required String itemName,
  ({bool lots, bool keep, ItemGroups? groups}) options = (lots: false, keep: false, groups: null),
}) async {
  final l10n = context.l10n;
  final config = await guardRead<StockItemConfig?>(
    domain: 'stock',
    message: 'the item could not be read for its editor',
    read: () => StockReads(commands).item(workspaceId, itemId),
    fallback: (_) {
      if (context.mounted) AppSnack.error(context, l10n.stockReadFailed);
      return null;
    },
  );
  if (config == null || !context.mounted) return false;
  final own = await _ownValues(StockReads(commands, groups: options.groups), workspaceId, itemId);
  if (!context.mounted) return false;
  final unitCodes = await stockUnitCodes(context, workspaceId);
  if (!context.mounted) return false;
  final editor = _ItemDraft(config, workspaceId: workspaceId, unitCodes: unitCodes, lotsOn: options.lots, keepInStock: options.keep, own: own);
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.stockEditItemTitle(itemName),
      submitLabel: l10n.stockEditSave,
      submitKey: const ValueKey('stock-item-save'),
      onDispose: editor.dispose,
      validate: () => editor.validate(l10n),
      onSubmit: () => editor.save(l10n, commands, workspaceId),
      builder: editor.fields,
    ),
  );
}

class _UnitRow {
  _UnitRow(StockUnitDraft u)
    : unit = TextEditingController(text: u.unit),
      num = TextEditingController(text: '${u.factorNum}'),
      den = TextEditingController(text: '${u.factorDen}'),
      defaultPurchase = u.defaultPurchase,
      defaultSale = u.defaultSale;

  final TextEditingController unit;
  final TextEditingController num;
  final TextEditingController den;
  bool defaultPurchase;
  bool defaultSale;

  StockUnitDraft get draft => StockUnitDraft(
    unit: unit.text.trim(),
    factorNum: int.tryParse(num.text.trim()) ?? 0,
    factorDen: int.tryParse(den.text.trim()) ?? 0,
    defaultPurchase: defaultPurchase,
    defaultSale: defaultSale,
  );

  void dispose() {
    unit.dispose();
    num.dispose();
    den.dispose();
  }
}

class _CodeRow {
  _CodeRow(StockCodeDraft c) : code = TextEditingController(text: c.code), kind = c.kind, unit = c.unit;

  final TextEditingController code;
  String kind;
  String? unit;

  StockCodeDraft get draft => StockCodeDraft(code: code.text.trim(), kind: kind, unit: unit);

  void dispose() => code.dispose();
}

/// The settings in which the item of a group keeps a value of its own against the group's. Without groups, or when the
/// read fails, nothing is marked: the mark is information, never a reason to keep the editor closed.
Future<Set<String>> _ownValues(StockReads reads, String workspaceId, String itemId) => guardRead(
  domain: 'stock',
  message: 'the own values of an item were not read for its editor',
  read: () => reads.ownValues(workspaceId, itemId),
  fallback: (_) => const <String>{},
);

class _ItemDraft {
  _ItemDraft(this.config, {required this.workspaceId, required this.unitCodes, required this.lotsOn, bool keepInStock = false, this.own = const {}})
    : tracking = config.tracking,
      shelfLife = TextEditingController(text: config.shelfLifeDays?.toString() ?? ''),
      stockable = keepInStock || config.stockable,
      purchasable = config.purchasable,
      sellable = config.sellable,
      units = [for (final u in config.units) _UnitRow(u)],
      codes = [for (final c in config.codes) _CodeRow(c)];

  final StockItemConfig config;

  /// The business whose units an extra unit of the item is picked from (#4471).
  final String workspaceId;

  /// The codes of the units the business offers: an extra unit that is none of them cannot be saved.
  final Set<String> unitCodes;

  /// Whether lots and expiry are asked for in this business (stockLots).
  final bool lotsOn;

  /// The settings the item keeps its own value of, against its group.
  final Set<String> own;

  Widget? _ownMark(AppLocalizations l10n, BuildContext context, String parameter) => own.contains(parameter)
      ? Text(l10n.itemGroupOwn, key: ValueKey('stock-item-own-$parameter'), style: Theme.of(context).textTheme.bodySmall)
      : null;
  String tracking;
  final TextEditingController shelfLife;

  /// One per editor: a retry of the same save answers once.
  final String requestId = newRequestId();
  bool stockable;
  bool purchasable;
  bool sellable;
  final List<_UnitRow> units;
  final List<_CodeRow> codes;

  void dispose() {
    shelfLife.dispose();
    for (final u in units) {
      u.dispose();
    }
    for (final c in codes) {
      c.dispose();
    }
  }

  StockItemConfig get current => StockItemConfig(
    itemId: config.itemId,
    revision: config.revision,
    stockable: stockable,
    purchasable: purchasable,
    sellable: sellable,
    inventoryUnit: config.inventoryUnit,
    tracking: tracking,
    shelfLifeDays: int.tryParse(shelfLife.text.trim()),
    units: [for (final u in units) u.draft],
    codes: [for (final c in codes) c.draft],
  );

  FieldErrors validate(AppLocalizations l10n) => {
    if (lotsOn && shelfLife.text.trim().isNotEmpty && (int.tryParse(shelfLife.text.trim()) ?? 0) <= 0)
      'shelf_life_days': stockRefusalText(l10n, StockRefusal.outOfRange),
    for (final e in checkStockItem(
      units: [for (final u in units) u.draft],
      codes: [for (final c in codes) c.draft],
    ).entries)
      e.key: stockRefusalText(l10n, e.value),
    // #4471 -- an extra unit is one of the business's units, never a name typed
    for (final (i, u) in units.indexed)
      if (u.unit.text.trim().isNotEmpty && !unitCodes.contains(u.unit.text.trim())) stockUnitField(i, 'unit'): l10n.masterDataUnlisted,
  };

  Future<String?> save(AppLocalizations l10n, StockConfigCommands commands, String workspaceId) async {
    return guardSave(
      domain: 'stock',
      message: 'the stock settings of an item were not saved',
      action: () async {
        await commands.saveItem(workspaceId, current, requestId);
      },
      problem: (e) => stockProblemText(l10n, e),
    );
  }

  List<Widget> fields(BuildContext context, VoidCallback refresh) {
    final l10n = context.l10n;
    final unitNames = [for (final u in units) u.unit.text.trim()].where((n) => n.isNotEmpty).toList();
    return [
      SwitchListTile(
        key: const ValueKey('stock-item-stockable'),
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.stockEditStockable),
        value: stockable,
        onChanged: (v) {
          stockable = v;
          refresh();
        },
      ),
      SwitchListTile(
        key: const ValueKey('stock-item-purchasable'),
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.stockEditPurchasable),
        value: purchasable,
        onChanged: (v) {
          purchasable = v;
          refresh();
        },
      ),
      SwitchListTile(
        key: const ValueKey('stock-item-sellable'),
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.stockEditSellable),
        value: sellable,
        onChanged: (v) {
          sellable = v;
          refresh();
        },
      ),
      ListTile(
        key: const ValueKey('stock-item-inventory-unit'),
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.stockEditInventoryUnit),
        subtitle: _ownMark(l10n, context, 'inventory_unit'),
        trailing: Text(config.inventoryUnit),
      ),
      if (lotsOn) ..._trackingFields(context, l10n, refresh),
      const FormGap(),
      FormSection(
        title: l10n.stockEditUnitsTitle,
        children: [
          Text(l10n.stockEditUnitsHint, style: Theme.of(context).textTheme.bodySmall),
          const FormGap.small(),
          for (var i = 0; i < units.length; i++) ..._unitRow(context, l10n, i, refresh),
          TextButton.icon(
            key: const ValueKey('stock-item-add-unit'),
            icon: const Icon(Icons.add),
            label: Text(l10n.stockEditAddUnit),
            onPressed: () {
              units.add(_UnitRow(const StockUnitDraft(unit: '', factorNum: 1, factorDen: 1)));
              refresh();
            },
          ),
        ],
      ),
      const FormGap(),
      FormSection(
        title: l10n.stockEditCodesTitle,
        children: [
          for (var i = 0; i < codes.length; i++) ..._codeRow(context, l10n, i, unitNames, refresh),
          TextButton.icon(
            key: const ValueKey('stock-item-add-code'),
            icon: const Icon(Icons.add),
            label: Text(l10n.stockEditAddCode),
            onPressed: () {
              codes.add(_CodeRow(const StockCodeDraft(code: '', kind: 'own')));
              refresh();
            },
          ),
        ],
      ),
    ];
  }

  List<Widget> _trackingFields(BuildContext context, AppLocalizations l10n, VoidCallback refresh) => [
    const FormGap(),
    SegmentedButton<String>(
      key: const ValueKey('stock-item-tracking'),
      showSelectedIcon: false,
      segments: [
        ButtonSegment(value: 'none', label: Text(l10n.stockEditTrackingNone)),
        ButtonSegment(value: 'lot', label: Text(l10n.stockEditTrackingLot)),
        ButtonSegment(value: 'expiry', label: Text(l10n.stockEditTrackingExpiry)),
      ],
      selected: {tracking},
      onSelectionChanged: (s) {
        tracking = s.first;
        refresh();
      },
    ),
    ...?_ownLine(l10n, context, 'tracking'),
    if (tracking == 'expiry') ...[
      const FormGap.small(),
      AppTextField(
        key: const ValueKey('stock-item-shelf-life'),
        controller: shelfLife,
        fieldKey: 'shelf_life_days',
        label: l10n.stockEditShelfLife,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
      ...?_ownLine(l10n, context, 'shelf_life_days'),
    ],
  ];

  List<Widget>? _ownLine(AppLocalizations l10n, BuildContext context, String parameter) {
    final mark = _ownMark(l10n, context, parameter);
    return mark == null ? null : [mark];
  }

  List<Widget> _unitRow(BuildContext context, AppLocalizations l10n, int i, VoidCallback refresh) {
    final u = units[i];
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: StockUnitPicker(
              key: ValueKey('stock-unit-$i-name'),
              workspaceId: workspaceId,
              fieldKey: stockUnitField(i, 'unit'),
              value: u.unit.text.trim(),
              label: l10n.stockEditUnitName,
              onChanged: (code) {
                u.unit.text = code;
                refresh();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: AppTextField(
              controller: u.num,
              fieldKey: stockUnitField(i, 'factor_num'),
              label: l10n.stockEditFactorNum,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              key: ValueKey('stock-unit-$i-num'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: AppTextField(
              controller: u.den,
              fieldKey: stockUnitField(i, 'factor_den'),
              label: l10n.stockEditFactorDen,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              key: ValueKey('stock-unit-$i-den'),
            ),
          ),
          IconButton(
            key: ValueKey('stock-unit-$i-remove'),
            tooltip: l10n.stockEditRemove,
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              units.removeAt(i).dispose();
              refresh();
            },
          ),
        ],
      ),
      CheckboxListTile(
        key: ValueKey('stock-unit-$i-default-purchase'),
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.stockEditDefaultPurchase),
        value: u.defaultPurchase,
        onChanged: (v) {
          u.defaultPurchase = v ?? false;
          refresh();
        },
      ),
      CheckboxListTile(
        key: ValueKey('stock-unit-$i-default-sale'),
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.stockEditDefaultSale),
        value: u.defaultSale,
        onChanged: (v) {
          u.defaultSale = v ?? false;
          refresh();
        },
      ),
    ];
  }

  List<Widget> _codeRow(
    BuildContext context,
    AppLocalizations l10n,
    int i,
    List<String> unitNames,
    VoidCallback refresh,
  ) {
    final c = codes[i];
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppTextField(
              controller: c.code,
              fieldKey: stockCodeField(i, 'code'),
              label: l10n.stockEditCode,
              key: ValueKey('stock-code-$i-code'),
            ),
          ),
          IconButton(
            key: ValueKey('stock-code-$i-remove'),
            tooltip: l10n.stockEditRemove,
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              codes.removeAt(i).dispose();
              refresh();
            },
          ),
        ],
      ),
      SegmentedButton<String>(
        key: ValueKey('stock-code-$i-kind'),
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: 'gtin', label: Text(l10n.stockEditCodeGtin)),
          ButtonSegment(value: 'own', label: Text(l10n.stockEditCodeOwn)),
        ],
        selected: {c.kind},
        onSelectionChanged: (s) {
          c.kind = s.first;
          refresh();
        },
      ),
      const FormGap.small(),
      DropdownButtonFormField<String?>(
        key: ValueKey('stock-code-$i-unit'),
        initialValue: unitNames.contains(c.unit) ? c.unit : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: l10n.stockEditCodeUnit),
        items: [
          DropdownMenuItem<String?>(child: Text(config.inventoryUnit)),
          for (final n in unitNames) DropdownMenuItem<String?>(value: n, child: Text(n)),
        ],
        onChanged: (v) => c.unit = v,
      ),
      const FormGap(),
    ];
  }
}
