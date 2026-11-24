// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4294 (G8, client slice 2) -- the reorder point of an item (or one variant) at a site: the level at
// or below which it is low, and what to order then: a quantity, or up to a level, or nothing (it only
// flags). The mistakes the screen can see are said under their field before anything is sent; the
// server decides, and a refusal is said under the sheet. A point's item, variant and site are fixed
// once it exists (make another). One request id per sheet: a retry answers once.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/i18n/app_format.dart';
import '../../../core/i18n/format_controller.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/dropdown_field.dart';
import '../../../core/ui/form_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../application/stock_reads.dart';
import '../domain/stock_config.dart';
import '../domain/stock_config_commands.dart';
import '../domain/stock_page.dart';
import '../domain/stock_reorder.dart';
import '../domain/stock_sites.dart';
import '../domain/stock_variants.dart';
import 'stock_config_text.dart';
import 'stock_quantity_field.dart';

/// What the sheet chooses from: the stock items, the places (their sites) and the address separator.
typedef StockPointChoices = ({List<StockItem> items, List<StockPlaceConfig> places, String separator});

/// Opens the sheet of [point] (null: a new one); true when it was saved.
Future<bool> showStockReorderPointSheet(
  BuildContext context,
  StockReorder reorder,
  StockConfigCommands config, {
  required String workspaceId,
  required StockPointChoices choices,
  StockReorderPoint? point,
}) {
  final l10n = context.l10n;
  final draft = _PointDraft(choices.items, choices.places, choices.separator, point, appFormatOf(context));
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.stockReorderPointTitle,
      submitLabel: l10n.stockEditSave,
      submitKey: const ValueKey('stock-point-save'),
      onDispose: draft.fields.dispose,
      validate: () => draft.validate(l10n),
      onSubmit: () => draft.submit(l10n, reorder, workspaceId),
      builder: (context, refresh) => draft.build(context, refresh, config, workspaceId),
    ),
  );
}

class _PointDraft {
  _PointDraft(this.items, List<StockPlaceConfig> places, this.separator, this.point, this.format)
    : sites = [
        for (final p in stockRealPlaces(places))
          if (p.parentId == null) p,
      ],
      item = point?.itemId,
      variant = point?.variantId,
      site = point?.siteId,
      upTo = point?.targetQuantity != null,
      active = point?.active ?? true,
      fields = FormControllers({
        'level': point == null ? '' : format.quantity(point.reorderPoint, grouped: false),
        'value': switch (point?.targetQuantity ?? point?.reorderQuantity) {
          final q? => format.quantity(q, grouped: false),
          null => '',
        },
      });

  final List<StockItem> items;
  final List<StockPlaceConfig> sites;
  final String separator;
  final StockReorderPoint? point;
  /// The member's format: what the fields are written and read in.
  final AppFormat format;
  String get locale => format.locale;
  final FormControllers fields;

  /// One per sheet: a retry of the same save answers once.
  final String requestId = newRequestId();
  String? item;
  String? variant;
  String? site;
  bool upTo;
  bool active;
  List<StockVariant> variants = const [];
  String? _variantsOf;

  /// What was typed, read in the member's format (1,5 or 1.5) as the exact text the server reads; what is no
  /// quantity stays as typed, for the check to refuse.
  String _dot(String field) => stockQuantityOrNull(fields.text(field), locale: locale)?.text ?? fields.text(field).trim();

  bool get isNew => point == null;
  String get unit => items.where((i) => i.id == item).firstOrNull?.unit ?? '';

  /// The sentences under the two choices (the text fields show their own through the form).
  final Map<String, String> _choiceErrors = {};

  FieldErrors validate(AppLocalizations l10n) {
    _choiceErrors.clear();
    final shown = {
      if (item == null) 'item': l10n.stockRequiredItem,
      if (site == null) 'site': l10n.stockRequiredSite,
      for (final e in checkReorderPoint(point: _dot('level'), value: _dot('value'), upTo: upTo).entries)
        switch (e.key) {
          'reorder_point' => 'level',
          'reorder_quantity' || 'target_quantity' => 'value',
          final k => k,
        }: stockRefusalText(l10n, e.value),
    };
    for (final k in ['item', 'site']) {
      final sentence = shown[k];
      if (sentence != null) _choiceErrors[k] = sentence;
    }
    return shown;
  }

  Future<String?> submit(AppLocalizations l10n, StockReorder reorder, String workspaceId) async {
    final value = _dot('value');
    return guardSave(
      domain: 'stock',
      message: 'a reorder point was not saved',
      action: () async {
        await reorder.savePoint(
          workspaceId,
          point: StockReorderPointDraft(
            target: isNew ? (item: item, variant: variant, site: site) : null,
            point: _dot('level'),
            value: value,
            upTo: upTo,
            active: active,
          ),
          requestId: requestId,
          pointId: point?.id,
          expectedRevision: point?.revision,
        );
      },
      problem: (e) => stockProblemText(l10n, e),
    );
  }

  /// The variants of the chosen item, read once per item.
  Future<void> _loadVariants(StockConfigCommands config, String workspaceId, VoidCallback refresh) async {
    final id = item;
    if (id == null || id == _variantsOf) return;
    _variantsOf = id;
    variants = await guardRead(
      domain: 'stock',
      message: 'the variants could not be read',
      read: () => StockReads(config).activeVariants(workspaceId, id),
      fallback: (_) => const [],
    );
    refresh();
  }

  List<Widget> build(BuildContext context, VoidCallback refresh, StockConfigCommands config, String workspaceId) {
    final l10n = context.l10n;
    final addresses = {for (final p in sites) p.id: stockAddress(p, separator)};
    if (isNew) unawaited(_loadVariants(config, workspaceId, refresh));
    return [
      AppDropdownField<String>(
        key: const ValueKey('stock-point-item'),
        label: l10n.expenseSupplyItem,
        value: item,
        error: _choiceErrors['item'],
        items: [for (final i in items) (i.id, i.name)],
        onChanged: isNew
            ? (v) {
                _choiceErrors.remove('item');
                item = v;
                variant = null;
                refresh();
              }
            : null,
      ),
      if (variants.isNotEmpty || variant != null) ...[
        const FormGap(),
        AppDropdownField<String?>(
          key: const ValueKey('stock-point-variant'),
          label: l10n.stockMappingVariant,
          value: variant,
          items: [
            (null, l10n.stockReorderPointWhole),
            for (final v in variants) (v.id, v.label),
          ],
          onChanged: isNew
              ? (v) {
                  variant = v;
                  refresh();
                }
              : null,
        ),
      ],
      const FormGap(),
      AppDropdownField<String>(
        key: const ValueKey('stock-point-site'),
        label: l10n.stockReorderPointSite,
        value: site,
        error: _choiceErrors['site'],
        items: [for (final p in sites) (p.id, addresses[p.id] ?? p.code)],
        onChanged: isNew
            ? (v) {
                _choiceErrors.remove('site');
                site = v;
                refresh();
              }
            : null,
      ),
      const FormGap(),
      StockQuantityField(
        key: const ValueKey('stock-point-level'),
        controller: fields['level'],
        fieldKey: 'level',
        label: l10n.stockReorderPointLevel(unit),
      ),
      const FormGap(),
      SegmentedButton<bool>(
        key: const ValueKey('stock-point-mode'),
        segments: [
          ButtonSegment(value: false, label: Text(l10n.stockReorderPointModeQuantity)),
          ButtonSegment(value: true, label: Text(l10n.stockReorderPointModeTarget)),
        ],
        selected: {upTo},
        onSelectionChanged: (s) {
          upTo = s.first;
          refresh();
        },
      ),
      const FormGap.small(),
      StockQuantityField(
        key: const ValueKey('stock-point-value'),
        controller: fields['value'],
        fieldKey: 'value',
        label: l10n.stockReorderPointValue,
      ),
      SwitchListTile(
        key: const ValueKey('stock-point-active'),
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.stockReorderPointActive),
        value: active,
        onChanged: (v) {
          active = v;
          refresh();
        },
      ),
    ];
  }
}
