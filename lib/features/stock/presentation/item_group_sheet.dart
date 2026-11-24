// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4361 (G12) -- one item group in a sheet: its name, where it sits (a group nests one level), the shared settings
// it carries and, for a group that exists, what changed it. Saving first PREVIEWS: the sheet says which settings
// reach how many items, which keep their own value and which cannot be reached, and a second save applies it
// (editing anything in between asks for a new preview). The group's id is made once per sheet and the save carries
// one request id and the revision it read, so a retry after a lost answer answers once and a group that moved
// meanwhile is refused. A group nothing uses can be deleted here.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/format/decimal_input.dart';
import '../../../core/i18n/format_controller.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_snack.dart';
import '../../../core/ui/dropdown_field.dart';
import '../../../core/ui/form_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/item_groups.dart';
import '../domain/purchase_factor.dart';
import '../domain/stock_config.dart';
import '../domain/stock_service_creator.dart';
import '../domain/workspace_units.dart';
import 'item_group_text.dart';
import 'measure_unit_text.dart';

/// The units a group may set for its items (the registry's units of count, mass and volume).

/// What a sheet offers beside the group itself: the places a home zone is chosen from, the VAT rates, and whether the
/// person may see and set what an item costs or sells for (manageServices and viewFinances).
typedef GroupChoices = ({List<StockPlaceConfig> places, List<StockVatChoice> vat, bool finance, List<WorkspaceUnit> units});

/// Opens the sheet of [group] (null: a new group); true when something was saved or deleted.
Future<bool> showItemGroupSheet(
  BuildContext context,
  ItemGroups port, {
  required String workspaceId,
  required ItemGroup? group,
  required List<ItemGroup> groups,
  GroupChoices choices = const (places: <StockPlaceConfig>[], vat: <StockVatChoice>[], finance: false, units: <WorkspaceUnit>[]),
}) {
  final l10n = context.l10n;
  final draft = _GroupDraft(port, workspaceId, group, groups, choices, appFormatOf(context).locale);
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: group == null ? l10n.meGroupAdd : l10n.taxRefGroup,
      submitLabel: l10n.stockEditSave,
      submitKey: const ValueKey('item-group-save'),
      onDispose: draft.fields.dispose,
      validate: () => draft.validate(l10n),
      onSubmit: () => draft.submit(l10n),
      builder: draft.build,
    ),
  );
}

class _GroupDraft {
  _GroupDraft(this.port, this.workspaceId, this.group, this.groups, this.choices, this.locale)
    : _id = group?.id ?? newRequestId(),
      parentId = group?.parentId,
      tracking = group?.params['tracking'] as String?,
      tagMode = group?.params['tag_mode'] as String?,
      unit = group?.params['inventory_unit'] as String?,
      sold = group?.params['sold_by_weight'] as bool?,
      zone = group?.params['home_zone_id'] as String?,
      vat = group?.params['vat_rate_id'] as String?,
      supply = group?.params['supply_class'] as String?,
      rounding = group?.params['price_rounding'] as String?,
      fields = FormControllers({
        'name': group?.name ?? '',
        'shelf': '${group?.params['shelf_life_days'] ?? ''}',
        'count': '${group?.params['count_every_days'] ?? ''}',
        'age': '${group?.params['min_age'] ?? ''}',
        'purchaseUnit': '${group?.params['default_purchase_unit'] ?? ''}',
        'factor': group?.params['default_purchase_factor_num'] == null
            ? ''
            : purchaseFactorText((group!.params['default_purchase_factor_num']! as num).toInt(), ((group.params['default_purchase_factor_den'] ?? 1) as num).toInt()),
        'reorderPoint': '${group?.params['reorder_point_default'] ?? ''}',
        'reorderQty': '${group?.params['reorder_quantity_default'] ?? ''}',
        'margin': group?.params['target_margin_bps'] == null ? '' : percentOfMarginBps((group!.params['target_margin_bps']! as num).toInt()),
      });

  final ItemGroups port;
  final String workspaceId;
  final ItemGroup? group;
  final List<ItemGroup> groups;
  final GroupChoices choices;
  final String locale;

  List<StockPlaceConfig> get places => choices.places;
  List<StockVatChoice> get vatChoices => choices.vat;

  /// Whether the person may see and set what an item costs or sells for (manageServices and viewFinances).
  bool get financeAllowed => choices.finance;
  final FormControllers fields;
  final String _id;

  /// One per sheet: a retry of the same save answers once.
  final String requestId = newRequestId();
  String? parentId;
  String? tracking;
  String? tagMode;
  String? unit;
  bool? sold;
  String? zone;
  String? vat;
  String? supply;
  String? rounding;

  GroupSaved? _preview;
  String? _previewOf;

  int? _int(String key) => int.tryParse(fields.text(key));

  /// A decimal typed with the member's own separators, as the dot-decimal text the server reads; null when empty or not one.
  String? _decimal(String key) {
    if (fields.text(key).isEmpty) return null;
    final text = decimalTextFromInput(fields.text(key), locale: locale, grouping: false);
    // a numeric(18,6): at most six decimals, never rounded
    return text != null && RegExp(r'^[0-9]{1,12}(\.[0-9]{1,6})?$').hasMatch(text) ? text : null;
  }

  /// Whether [text] (a dot-decimal text) is zero: `0`, `0.0`, `0.000000`.
  bool _isZero(String text) => !RegExp(r'[1-9]').hasMatch(text);

  PurchaseFactor? get _factor => fields.text('factor').isEmpty ? null : parsePurchaseFactor(fields.text('factor'));

  Map<String, Object?> body() => {
    'name': fields.text('name'),
    'parent_id': parentId,
    'parameters': {
      'tracking': tracking,
      'shelf_life_days': _int('shelf'),
      'tag_mode': tagMode,
      'inventory_unit': unit,
      'count_every_days': _int('count'),
      'min_age': _int('age'),
      'sold_by_weight': sold,
      'default_purchase_unit': fields.text('purchaseUnit').isEmpty ? null : fields.text('purchaseUnit'),
      'default_purchase_factor_num': _factor?.num,
      'default_purchase_factor_den': _factor?.den,
      'reorder_point_default': _decimal('reorderPoint'),
      'reorder_quantity_default': _decimal('reorderQty'),
      'home_zone_id': zone,
      // what an item costs or sells for is sent only by someone who may see it: absent, the server leaves it as it is
      if (financeAllowed) ...{
        'vat_rate_id': vat,
        'supply_class': supply,
        'price_rounding': rounding,
        'target_margin_bps': fields.text('margin').isEmpty ? null : marginBpsOfPercent(decimalTextFromInput(fields.text('margin'), locale: locale, grouping: false) ?? ''),
      },
    },
  };

  FieldErrors validate(AppLocalizations l10n) => {
    if (fields.text('name').isEmpty) 'name': l10n.stockReasonNameMalformed,
    for (final (key, field) in [('shelf', 'shelf'), ('count', 'count'), ('age', 'age')])
      if (fields.text(key).isNotEmpty && (_int(key) ?? 0) < 1) field: l10n.stockReasonOutOfRange,
    // a purchase unit and its factor go together, and the factor is one number or a fraction above zero
    if (fields.text('factor').isNotEmpty && _factor == null) 'factor': l10n.stockReasonOutOfRange,
    if (fields.text('purchaseUnit').isNotEmpty && fields.text('factor').isEmpty) 'factor': l10n.stockReasonOutOfRange,
    if (fields.text('purchaseUnit').isEmpty && fields.text('factor').isNotEmpty) 'purchaseUnit': l10n.stockReasonNameMalformed,
    if (fields.text('reorderPoint').isNotEmpty && _decimal('reorderPoint') == null) 'reorderPoint': l10n.stockReasonOutOfRange,
    if (fields.text('reorderQty').isNotEmpty && (_decimal('reorderQty') == null || _isZero(_decimal('reorderQty')!))) 'reorderQty': l10n.stockReasonOutOfRange,
    if (financeAllowed && fields.text('margin').isNotEmpty && marginBpsOfPercent(decimalTextFromInput(fields.text('margin'), locale: locale, grouping: false) ?? '') == null) 'margin': l10n.stockReasonOutOfRange,
  };

  Future<String?> submit(AppLocalizations l10n) async {
    final now = jsonEncode(body());
    try {
      if (_preview == null || _previewOf != now) {
        final preview = await port.save(workspaceId, requestId: requestId, groupId: _id, expectedRevision: group?.revision ?? 0, body: body(), apply: false);
        _previewOf = now;
        _preview = preview;
        // nothing is reached: there is nothing to confirm
        if (preview.impact.isEmpty && preview.skipped.isEmpty) return await _apply(l10n);
        return l10n.itemGroupConfirm;
      }
      return await _apply(l10n);
    } on Object catch (e, st) {
      TraceLogger.instance.warn('stock', 'an item group was not saved', error: e, stackTrace: st);
      return itemGroupProblem(l10n, e);
    }
  }

  Future<String?> _apply(AppLocalizations l10n) async {
    await port.save(workspaceId, requestId: requestId, groupId: _id, expectedRevision: group?.revision ?? 0, body: body());
    return null;
  }

  List<Widget> build(BuildContext context, VoidCallback refresh) {
    final l10n = context.l10n;
    void edit(void Function() change) {
      change();
      _preview = null;
      refresh();
    }

    final parents = [
      for (final g in groups)
        if (g.parentId == null && g.id != group?.id) g,
    ];
    return [
      ..._basicFields(l10n, edit, parents),
      ..._proposalFields(context, l10n, edit),
      ..._financeFields(context, l10n, edit),
      ..._footer(context, l10n),
    ];
  }

  List<Widget> _basicFields(AppLocalizations l10n, void Function(void Function()) edit, List<ItemGroup> parents) => [
      AppTextField(key: const ValueKey('item-group-name'), controller: fields['name'], fieldKey: 'name', label: l10n.itemGroupName, onChanged: (_) => _preview = null),
      const FormGap(),
      AppDropdownField<String?>(
        key: const ValueKey('item-group-parent'),
        label: l10n.itemGroupParent,
        value: parentId,
        items: [(null, l10n.itemGroupNoParent), for (final g in parents) (g.id, g.name)],
        onChanged: (v) => edit(() => parentId = v),
      ),
      const FormGap(),
      AppDropdownField<String?>(
        key: const ValueKey('item-group-tracking'),
        label: l10n.stockEditTracking,
        value: tracking,
        items: [(null, l10n.itemGroupNotSet), for (final t in ['none', 'lot', 'expiry', 'serial']) (t, itemGroupValueText(l10n, 'tracking', t))],
        onChanged: (v) => edit(() => tracking = v),
      ),
      const FormGap(),
      AppTextField(
        key: const ValueKey('item-group-shelf'),
        controller: fields['shelf'],
        fieldKey: 'shelf',
        label: l10n.stockEditShelfLife,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => _preview = null,
      ),
      const FormGap(),
      AppDropdownField<String?>(
        key: const ValueKey('item-group-tag-mode'),
        label: l10n.itemGroupTagMode,
        value: tagMode,
        items: [(null, l10n.itemGroupNotSet), for (final t in ['none', 'per_batch', 'per_unit']) (t, itemGroupValueText(l10n, 'tag_mode', t))],
        onChanged: (v) => edit(() => tagMode = v),
      ),
      const FormGap(),
      AppDropdownField<String?>(
        key: const ValueKey('item-group-unit'),
        label: l10n.stockEditInventoryUnit,
        value: unit,
        items: [
          (null, l10n.itemGroupNotSet),
          for (final u in choices.units) (u.code, measureUnitName(l10n, u)),
          // a unit the group already holds that the picker no longer offers (archived) stays visible
          if (unit != null && !choices.units.any((u) => u.code == unit)) (unit, unit!),
        ],
        onChanged: (v) => edit(() => unit = v),
      ),
      const FormGap(),
      AppTextField(
        key: const ValueKey('item-group-count'),
        controller: fields['count'],
        fieldKey: 'count',
        label: l10n.itemGroupCountEvery,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => _preview = null,
      ),
      const FormGap(),
      AppTextField(
        key: const ValueKey('item-group-age'),
        controller: fields['age'],
        fieldKey: 'age',
        label: l10n.itemGroupMinAge,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => _preview = null,
      ),
      const FormGap(),
      AppDropdownField<bool?>(
        key: const ValueKey('item-group-weight'),
        label: l10n.itemGroupSoldByWeight,
        value: sold,
        items: [(null, l10n.itemGroupNotSet), (true, l10n.itemGroupYes), (false, l10n.itemGroupNo)],
        onChanged: (v) => edit(() => sold = v),
      )
  ];

  List<Widget> _proposalFields(BuildContext context, AppLocalizations l10n, void Function(void Function()) edit) => [
      const FormGap(),
      Text(l10n.itemGroupProposalHint, key: const ValueKey('item-group-proposals'), style: Theme.of(context).textTheme.bodySmall),
      const FormGap.small(),
      AppTextField(key: const ValueKey('item-group-purchase-unit'), controller: fields['purchaseUnit'], fieldKey: 'purchaseUnit', label: l10n.itemGroupPurchaseUnit, onChanged: (_) => _preview = null),
      const FormGap(),
      AppTextField(key: const ValueKey('item-group-factor'), controller: fields['factor'], fieldKey: 'factor', label: l10n.itemGroupPurchaseFactor, onChanged: (_) => _preview = null),
      const FormGap(),
      AppTextField(
        key: const ValueKey('item-group-reorder-point'),
        controller: fields['reorderPoint'],
        fieldKey: 'reorderPoint',
        label: l10n.itemGroupReorderPoint,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        onChanged: (_) => _preview = null,
      ),
      const FormGap(),
      AppTextField(
        key: const ValueKey('item-group-reorder-qty'),
        controller: fields['reorderQty'],
        fieldKey: 'reorderQty',
        label: l10n.itemGroupReorderQty,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        onChanged: (_) => _preview = null,
      ),
      const FormGap(),
      AppDropdownField<String?>(
        key: const ValueKey('item-group-home-zone'),
        label: l10n.itemGroupHomeZone,
        value: zone,
        items: [(null, l10n.itemGroupNotSet), for (final p in places) (p.id, p.name)],
        onChanged: (v) => edit(() => zone = v),
      ),
  ];

  List<Widget> _financeFields(BuildContext context, AppLocalizations l10n, void Function(void Function()) edit) => [
      if (financeAllowed) ...[
        const FormGap(),
        Text(l10n.itemGroupFinanceHint, key: const ValueKey('item-group-finance'), style: Theme.of(context).textTheme.bodySmall),
        const FormGap.small(),
        if (vatChoices.isNotEmpty)
          AppDropdownField<String?>(
            key: const ValueKey('item-group-vat'),
            label: l10n.vatServiceRate,
            value: vat,
            items: [(null, l10n.itemGroupNotSet), for (final v in vatChoices) (v.id, v.label)],
            onChanged: (v) => edit(() => vat = v),
          ),
        const FormGap(),
        AppDropdownField<String?>(
          key: const ValueKey('item-group-supply'),
          label: l10n.itemGroupSupply,
          value: supply,
          items: [(null, l10n.itemGroupNotSet), ('general', l10n.itemGroupSupplyGeneral), ('property', l10n.itemGroupSupplyProperty)],
          onChanged: (v) => edit(() => supply = v),
        ),
        const FormGap(),
        AppDropdownField<String?>(
          key: const ValueKey('item-group-rounding'),
          label: l10n.itemGroupRounding,
          value: rounding,
          items: [(null, l10n.itemGroupNotSet), for (final r in itemGroupRoundings) (r, r == 'none' ? l10n.itemGroupRoundingNone : r)],
          onChanged: (v) => edit(() => rounding = v),
        ),
        const FormGap(),
        AppTextField(
          key: const ValueKey('item-group-margin'),
          controller: fields['margin'],
          fieldKey: 'margin',
          label: l10n.itemGroupMargin,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          onChanged: (_) => _preview = null,
        ),
      ],
  ];

  List<Widget> _footer(BuildContext context, AppLocalizations l10n) => [
      if (_preview != null) _PreviewCard(preview: _preview!),
      if (group != null) ...[
        const FormGap(),
        _HistoryBlock(port: port, workspaceId: workspaceId, groupId: group!.id),
        if (group!.items == 0)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('item-group-delete'),
              onPressed: () => _delete(context),
              child: Text(l10n.itemGroupDelete),
            ),
          ),
      ],
  ];

  Future<void> _delete(BuildContext context) async {
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    try {
      await port.delete(workspaceId, requestId: newRequestId(), groupId: group!.id, expectedRevision: group!.revision);
      if (context.mounted) AppSnack.info(context, l10n.itemGroupDeleted);
      navigator.pop(true);
    } on Object catch (e, st) {
      TraceLogger.instance.warn('stock', 'an item group was not deleted', error: e, stackTrace: st);
      if (context.mounted) AppSnack.error(context, itemGroupProblem(l10n, e));
    }
  }
}

/// What the change would reach: a line per changed setting, and the items that cannot be reached.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});

  final GroupSaved preview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      key: const ValueKey('item-group-preview'),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.itemGroupPreviewTitle, style: Theme.of(context).textTheme.titleSmall),
            const FormGap.small(),
            if (preview.impact.isEmpty) Text(l10n.itemGroupPreviewNothing),
            for (final e in preview.impact.entries)
              Text(
                l10n.itemGroupPreviewLine(itemGroupParamLabel(l10n, e.key), e.value.affected, e.value.keptOwn, e.value.skipped),
                key: ValueKey('item-group-preview-${e.key}'),
              ),
            if (preview.skipped.isNotEmpty) ...[
              const FormGap.small(),
              Text(l10n.itemGroupSkippedTitle, style: Theme.of(context).textTheme.labelLarge),
              for (final s in preview.skipped) Text(l10n.itemGroupSkippedLine(s.itemId, itemGroupParamLabel(l10n, s.parameter), itemGroupReasonText(l10n, s.reason))),
            ],
          ],
        ),
      ),
    );
  }
}

/// The recorded changes of a group, newest first.
class _HistoryBlock extends StatelessWidget {
  const _HistoryBlock({required this.port, required this.workspaceId, required this.groupId});

  final ItemGroups port;
  final String workspaceId;
  final String groupId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder<List<GroupHistoryRow>>(
      future: port.history(workspaceId, groupId: groupId),
      builder: (context, snapshot) {
        final rows = snapshot.data;
        return Column(
          key: const ValueKey('item-group-history'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.itemGroupHistory, style: Theme.of(context).textTheme.titleSmall),
            if (rows != null && rows.isEmpty) Text(l10n.itemGroupHistoryNone),
            for (final r in rows ?? const <GroupHistoryRow>[])
              Text(
                l10n.itemGroupHistoryLine(
                  itemGroupParamLabel(l10n, r.parameter),
                  itemGroupValueText(l10n, r.parameter, r.oldValue),
                  itemGroupValueText(l10n, r.parameter, r.newValue),
                  r.affected,
                ),
              ),
          ],
        );
      },
    );
  }
}
