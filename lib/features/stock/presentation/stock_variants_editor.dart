// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4169 (B2) -- the variants of one item and the dimensions they vary by. A
// variant is one value of each dimension chosen (red, size M); the list shown
// is the complete list the save sends, at the item's revision read. A variant
// with stock stays in use and a combination that history names stays as
// written: the server says so, under the variant, and nothing is shown saved
// that was not. Dimensions (Colour, Size) and their values are edited beside:
// a value left out is kept, not deleted, so a variant that names it keeps its
// label.
import 'package:flutter/material.dart';

import '../../../core/format/amount_input.dart';
import '../../../core/i18n/app_format.dart';
import '../../../core/i18n/format_controller.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/app_snack.dart';
import '../../../core/ui/form_kit.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/stock_config.dart';
import '../domain/stock_config_check.dart';
import '../domain/stock_config_commands.dart';
import '../domain/stock_variants.dart';
import 'stock_config_text.dart';

/// Opens the variants of [itemId]; true when something was saved.
Future<bool> showStockVariantsEditor(
  BuildContext context,
  StockConfigCommands commands, {
  required String workspaceId,
  required String itemId,
  required String itemName,
}) async {
  final l10n = context.l10n;
  final StockItemConfig? item;
  final List<StockDimension> dimensions;
  final List<StockVariant> variants;
  try {
    item = await commands.item(workspaceId, itemId);
    dimensions = await commands.dimensions(workspaceId);
    variants = await commands.variants(workspaceId, itemId);
  } on Object catch (e, st) {
    TraceLogger.instance.error('stock', 'the variants of an item could not be read', error: e, stackTrace: st);
    if (context.mounted) AppSnack.error(context, l10n.stockReadFailed);
    return false;
  }
  if (item == null || !context.mounted) return false;
  final draft = _VariantsDraft(commands, workspaceId, item, dimensions, variants, appFormatOf(context));
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.stockVariantsTitle(itemName),
      submitLabel: l10n.stockEditSave,
      submitKey: const ValueKey('stock-variants-save'),
      onDispose: draft.dispose,
      validate: () => draft.validate(l10n),
      onSubmit: () => draft.save(l10n),
      builder: draft.build,
    ),
  );
}

class _VariantRow {
  _VariantRow({required this.format, this.id, Map<String, String>? values, int? price, this.active = true})
    : values = {...?values},
      price = TextEditingController(
        text: price == null ? '' : amountInputText(price, currency: format.currencyCode, locale: format.locale),
      );

  /// The member's format and the business's currency: what the price is typed and read in.
  final AppFormat format;
  final String? id;
  final Map<String, String> values;
  final TextEditingController price;
  bool active;

  AmountRead get _read =>
      readAmountInput(price.text, locale: format.locale, currency: format.currencyCode, allowNegative: false);

  /// The price in minor units, or null when none is typed (or what is typed is no amount, said under the field).
  int? get priceCents => _read.minor;
  AmountInputProblem? get priceProblem => _read.problem;
}

class _VariantsDraft {
  _VariantsDraft(this.commands, this.workspaceId, this.item, this.dimensions, List<StockVariant> variants, this.format)
    : rows = [
        for (final v in variants) _VariantRow(format: format, id: v.id, values: v.values, price: v.priceCents, active: v.active),
      ];

  final AppFormat format;

  final StockConfigCommands commands;
  final String workspaceId;
  final StockItemConfig item;
  List<StockDimension> dimensions;
  final List<_VariantRow> rows;

  /// One per editor: a retry of the same save answers once.
  final String requestId = newRequestId();

  void dispose() {
    for (final r in rows) {
      r.price.dispose();
    }
  }

  Iterable<StockDimension> get _active => dimensions.where((d) => d.active);

  FieldErrors validate(AppLocalizations l10n) => {
    for (final e in checkStockVariants([
      for (final r in rows) (values: r.values, priceCents: r.priceCents),
    ]).entries)
      e.key: stockReasonText(l10n, e.value),
    for (final (i, r) in rows.indexed)
      if (r.priceProblem case final problem?)
        'variants[$i].price_cents': amountInputProblemText(l10n, problem, currency: format.currencyCode),
  };

  Future<String?> save(AppLocalizations l10n) async {
    try {
      await commands.saveVariants(
        workspaceId,
        item.itemId,
        variants: [
          for (final r in rows)
            StockVariant(id: r.id, values: r.values, priceCents: r.priceCents, active: r.active, label: ''),
        ],
        expectedRevision: item.revision,
        requestId: requestId,
      );
      return null;
    } on Object catch (e, st) {
      TraceLogger.instance.warn('stock', 'the variants of an item were not saved', error: e, stackTrace: st);
      return stockSaveProblem(l10n, e);
    }
  }

  List<Widget> build(BuildContext context, VoidCallback refresh) {
    final l10n = context.l10n;
    return [
      Text(l10n.stockVariantsHint, style: Theme.of(context).textTheme.bodySmall),
      const FormGap.small(),
      if (_active.isEmpty) Text(l10n.stockVariantsNoDimensions, key: const ValueKey('stock-variants-no-dimensions')),
      for (var i = 0; i < rows.length; i++) ..._row(context, l10n, i, refresh),
      Wrap(
        spacing: AppSpacing.sm,
        children: [
          TextButton.icon(
            key: const ValueKey('stock-variants-add'),
            icon: const Icon(Icons.add),
            label: Text(l10n.stockVariantsAdd),
            onPressed: _active.isEmpty
                ? null
                : () {
                    rows.add(_VariantRow(format: format));
                    refresh();
                  },
          ),
          TextButton(
            key: const ValueKey('stock-dimensions-manage'),
            onPressed: () async {
              await _showStockDimensions(context, commands, workspaceId: workspaceId);
              try {
                dimensions = await commands.dimensions(workspaceId);
              } on Object catch (e, st) {
                TraceLogger.instance.error('stock', 'the dimensions could not be read again', error: e, stackTrace: st);
              }
              refresh();
            },
            child: Text(l10n.stockDimensionsManage),
          ),
        ],
      ),
    ];
  }

  List<Widget> _row(BuildContext context, AppLocalizations l10n, int i, VoidCallback refresh) {
    final r = rows[i];
    return [
      for (final d in _active)
        DropdownButtonFormField<String?>(
          key: ValueKey('stock-variant-$i-${d.id}'),
          initialValue: d.values.any((v) => v.id == r.values[d.id]) ? r.values[d.id] : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: d.name),
          items: [
            const DropdownMenuItem<String?>(child: Text('')),
            for (final v in d.values.where((v) => v.active || v.id == r.values[d.id]))
              DropdownMenuItem<String?>(value: v.id, child: Text(v.label)),
          ],
          onChanged: (value) {
            if (value == null) {
              r.values.remove(d.id);
            } else {
              r.values[d.id] = value;
            }
            refresh();
          },
        ),
      // Below the form's error scope, so the row can read its own problem.
      Builder(
        builder: (context) => switch (FormErrorsScope.maybeOf(context)?.errors['variants[$i].values']) {
          final String error => Text(
            error,
            key: ValueKey('stock-variant-$i-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          _ => const SizedBox.shrink(),
        },
      ),
      Row(
        children: [
          Expanded(
            child: AppAmountField(
              key: ValueKey('stock-variant-$i-price'),
              controller: r.price,
              fieldKey: 'variants[$i].price_cents',
              label: l10n.stockVariantPrice,
              currency: format.currencyCode,
              allowNegative: false,
            ),
          ),
          IconButton(
            key: ValueKey('stock-variant-$i-remove'),
            tooltip: l10n.stockEditRemove,
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              rows.removeAt(i).price.dispose();
              refresh();
            },
          ),
        ],
      ),
      SwitchListTile(
        key: ValueKey('stock-variant-$i-active'),
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.stockPlaceActive),
        value: r.active,
        onChanged: (v) {
          r.active = v;
          refresh();
        },
      ),
      const Divider(),
    ];
  }
}

/// The dimensions of the business: each opens its editor; one is added from
/// the button.
Future<void> _showStockDimensions(
  BuildContext context,
  StockConfigCommands commands, {
  required String workspaceId,
}) => showAppSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _DimensionsSheet(commands: commands, workspaceId: workspaceId),
);

class _DimensionsSheet extends StatefulWidget {
  const _DimensionsSheet({required this.commands, required this.workspaceId});

  final StockConfigCommands commands;
  final String workspaceId;

  @override
  State<_DimensionsSheet> createState() => _DimensionsSheetState();
}

class _DimensionsSheetState extends State<_DimensionsSheet> {
  late Future<List<StockDimension>> _dimensions = widget.commands.dimensions(widget.workspaceId);

  Future<void> _edit(StockDimension? dimension) async {
    final saved = await _showDimensionEditor(context, widget.commands, workspaceId: widget.workspaceId, dimension: dimension);
    if (saved && mounted) {
      setState(() {
        _dimensions = widget.commands.dimensions(widget.workspaceId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: FutureBuilder<List<StockDimension>>(
          future: _dimensions,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(l10n.stockReadFailed, key: const ValueKey('stock-dimensions-failed'));
            }
            final all = snapshot.data;
            if (all == null) return const LoadingView();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.stockDimensionsTitle, style: Theme.of(context).textTheme.titleMedium),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final d in all)
                        ListTile(
                          key: ValueKey('stock-dimension-${d.id}'),
                          title: Text(
                            d.name,
                            style: d.active ? null : const TextStyle(decoration: TextDecoration.lineThrough),
                          ),
                          subtitle: Text(d.values.where((v) => v.active).map((v) => v.label).join(', ')),
                          onTap: () => _edit(d),
                        ),
                    ],
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('stock-dimension-add'),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.stockDimensionAdd),
                  onPressed: () => _edit(null),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

Future<bool> _showDimensionEditor(
  BuildContext context,
  StockConfigCommands commands, {
  required String workspaceId,
  required StockDimension? dimension,
}) {
  final l10n = context.l10n;
  final draft = _DimensionDraft(dimension);
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.stockDimensionsTitle,
      submitLabel: l10n.stockEditSave,
      submitKey: const ValueKey('stock-dimension-save'),
      onDispose: draft.dispose,
      validate: () => draft.validate(l10n),
      onSubmit: () => draft.save(l10n, commands, workspaceId),
      builder: draft.build,
    ),
  );
}

class _ValueRow {
  _ValueRow({required this.id, required String label, required this.active}) : label = TextEditingController(text: label);

  final String? id;
  final TextEditingController label;
  bool active;
}

class _DimensionDraft {
  _DimensionDraft(this.dimension)
    : name = TextEditingController(text: dimension?.name ?? ''),
      active = dimension?.active ?? true,
      values = [for (final v in dimension?.values ?? const <StockDimensionValue>[]) _ValueRow(id: v.id, label: v.label, active: v.active)];

  final StockDimension? dimension;
  final TextEditingController name;
  final List<_ValueRow> values;
  bool active;

  /// One per editor: a retry of the same save answers once.
  final String requestId = newRequestId();

  void dispose() {
    name.dispose();
    for (final v in values) {
      v.label.dispose();
    }
  }

  FieldErrors validate(AppLocalizations l10n) {
    final errors = <String, String>{};
    if (name.text.trim().isEmpty || name.text.trim().length > 60) errors['name'] = 'name_malformed';
    final seen = <String>{};
    for (var i = 0; i < values.length; i++) {
      final label = values[i].label.text.trim();
      if (label.isEmpty || label.length > 60) {
        errors['values[$i].label'] = 'name_malformed';
      } else if (!seen.add(label)) {
        errors['values[$i].label'] = 'name_duplicate';
      }
    }
    return {for (final e in errors.entries) e.key: stockReasonText(l10n, e.value)};
  }

  Future<String?> save(AppLocalizations l10n, StockConfigCommands commands, String workspaceId) async {
    try {
      await commands.saveDimension(
        workspaceId,
        dimension: StockDimension(
          id: dimension?.id ?? '',
          revision: dimension?.revision ?? 0,
          name: name.text.trim(),
          active: active,
          values: [
            for (final v in values) StockDimensionValue(id: v.id, label: v.label.text.trim(), active: v.active),
          ],
        ).toSave(),
        requestId: requestId,
        dimensionId: dimension?.id,
        expectedRevision: dimension?.revision,
      );
      return null;
    } on Object catch (e, st) {
      TraceLogger.instance.warn('stock', 'a dimension was not saved', error: e, stackTrace: st);
      return stockSaveProblem(l10n, e);
    }
  }

  List<Widget> build(BuildContext context, VoidCallback refresh) {
    final l10n = context.l10n;
    return [
      AppTextField(
        key: const ValueKey('stock-dimension-name'),
        controller: name,
        fieldKey: 'name',
        label: l10n.stockDimensionName,
      ),
      const FormGap(),
      for (var i = 0; i < values.length; i++)
        Row(
          children: [
            Expanded(
              child: AppTextField(
                key: ValueKey('stock-dimension-value-$i'),
                controller: values[i].label,
                fieldKey: 'values[$i].label',
                label: l10n.stockDimensionValue,
              ),
            ),
            IconButton(
              key: ValueKey('stock-dimension-value-$i-remove'),
              tooltip: l10n.stockEditRemove,
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                values.removeAt(i).label.dispose();
                refresh();
              },
            ),
          ],
        ),
      TextButton.icon(
        key: const ValueKey('stock-dimension-add-value'),
        icon: const Icon(Icons.add),
        label: Text(l10n.stockDimensionAddValue),
        onPressed: () {
          values.add(_ValueRow(id: null, label: '', active: true));
          refresh();
        },
      ),
      SwitchListTile(
        key: const ValueKey('stock-dimension-active'),
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.stockPlaceActive),
        value: active,
        onChanged: (v) {
          active = v;
          refresh();
        },
      ),
    ];
  }
}
