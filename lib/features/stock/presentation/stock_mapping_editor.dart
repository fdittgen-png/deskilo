// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4169 (B2) -- a supplier's article mapped to an item: the supplier, the
// article reference, the variant it is and the package unit it is bought in.
// An explicit save, never a guess from a name; the same article of one
// supplier is mapped once, and a unit the item does not list is refused with
// its field.
import 'package:flutter/material.dart';

import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/form_kit.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../application/stock_reads.dart';
import '../domain/stock_config.dart';
import '../domain/stock_config_commands.dart';
import '../domain/stock_drafts.dart';
import '../domain/stock_variants.dart';
import 'stock_config_text.dart';

/// The supplier articles of [itemId], each opening its editor; one is added
/// from the button.
Future<void> showStockMappings(
  BuildContext context,
  StockConfigCommands commands, {
  required String workspaceId,
  required String itemId,
  required String itemName,
}) => showAppSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _MappingsSheet(commands: commands, workspaceId: workspaceId, itemId: itemId, itemName: itemName),
);

class _Loaded {
  const _Loaded(this.item, this.mappings, this.suppliers, this.variants);

  final StockItemConfig item;
  final List<SupplierItemMapping> mappings;
  final List<StockSupplierRef> suppliers;
  final List<StockVariant> variants;
}

class _MappingsSheet extends StatefulWidget {
  const _MappingsSheet({
    required this.commands,
    required this.workspaceId,
    required this.itemId,
    required this.itemName,
  });

  final StockConfigCommands commands;
  final String workspaceId;
  final String itemId;
  final String itemName;

  @override
  State<_MappingsSheet> createState() => _MappingsSheetState();
}

class _MappingsSheetState extends State<_MappingsSheet> {
  late Future<_Loaded> _loaded = _read();

  Future<_Loaded> _read() async {
    final read = await StockReads(widget.commands).mappingsOf(widget.workspaceId, widget.itemId);
    return _Loaded(read.item, read.mappings, read.suppliers, read.variants);
  }

  Future<void> _edit(_Loaded data, SupplierItemMapping? mapping) async {
    final saved = await _showMappingEditor(context, widget.commands, workspaceId: widget.workspaceId, data: data, mapping: mapping);
    if (saved && mounted) {
      setState(() {
        _loaded = _read();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: FutureBuilder<_Loaded>(
          future: _loaded,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              TraceLogger.instance.warn('stock', 'the supplier articles could not be read', error: snapshot.error, stackTrace: snapshot.stackTrace);
              return Text(l10n.stockReadFailed, key: const ValueKey('stock-mappings-failed'));
            }
            final data = snapshot.data;
            if (data == null) return const LoadingView();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.stockMappingsTitle(widget.itemName), style: Theme.of(context).textTheme.titleMedium),
                if (data.mappings.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Text(l10n.stockMappingNone, key: const ValueKey('stock-mappings-none')),
                  ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final m in data.mappings)
                        ListTile(
                          key: ValueKey('stock-mapping-${m.id}'),
                          title: Text(m.articleRef),
                          subtitle: Text(
                            data.suppliers.where((s) => s.id == m.supplierId).map((s) => s.name).firstOrNull ?? '',
                          ),
                          onTap: () => _edit(data, m),
                        ),
                    ],
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('stock-mapping-add'),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.stockMappingAdd),
                  onPressed: () => _edit(data, null),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

Future<bool> _showMappingEditor(
  BuildContext context,
  StockConfigCommands commands, {
  required String workspaceId,
  required _Loaded data,
  required SupplierItemMapping? mapping,
}) {
  final l10n = context.l10n;
  final draft = _MappingDraft(data, mapping);
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.stockMappingsEdit,
      submitLabel: l10n.stockEditSave,
      submitKey: const ValueKey('stock-mapping-save'),
      onDispose: draft.article.dispose,
      validate: () => {
        if (draft.supplier == null) 'supplier_id': l10n.stockRequiredSupplier,
        if (draft.article.text.trim().isEmpty) 'article_ref': l10n.stockRequiredArticle,
      },
      onSubmit: () => draft.save(l10n, commands, workspaceId),
      builder: draft.build,
    ),
  );
}

class _MappingDraft {
  _MappingDraft(this.data, this.mapping)
    : article = TextEditingController(text: mapping?.articleRef ?? ''),
      supplier = mapping?.supplierId,
      variant = mapping?.variantId,
      unit = mapping?.purchaseUnit;

  final _Loaded data;
  final SupplierItemMapping? mapping;
  final TextEditingController article;
  String? supplier;
  String? variant;
  String? unit;

  /// One per editor: a retry of the same save answers once.
  final String requestId = newRequestId();

  Future<String?> save(AppLocalizations l10n, StockConfigCommands commands, String workspaceId) async {
    return guardSave(
      domain: 'stock',
      message: 'a supplier article was not saved',
      action: () async {
        await commands.saveMapping(
          workspaceId,
          mapping: SupplierMappingDraft(
            supplierId: supplier,
            itemId: data.item.itemId,
            variantId: variant,
            articleRef: article.text.trim(),
            purchaseUnit: unit,
            active: true,
          ),
          requestId: requestId,
          mappingId: mapping?.id,
          expectedRevision: mapping?.revision,
        );
      },
      problem: (e) => stockProblemText(l10n, e),
    );
  }

  List<Widget> build(BuildContext context, VoidCallback refresh) {
    final l10n = context.l10n;
    return [
      DropdownButtonFormField<String?>(
        key: const ValueKey('stock-mapping-supplier'),
        initialValue: supplier,
        isExpanded: true,
        decoration: InputDecoration(labelText: l10n.stockMappingSupplier),
        items: [
          for (final s in data.suppliers) DropdownMenuItem<String?>(value: s.id, child: Text(s.name)),
        ],
        onChanged: (v) {
          supplier = v;
          refresh();
        },
      ),
      const FormGap(),
      AppTextField(
        key: const ValueKey('stock-mapping-article'),
        controller: article,
        fieldKey: 'article_ref',
        label: l10n.stockMappingArticle,
      ),
      const FormGap(),
      DropdownButtonFormField<String?>(
        key: const ValueKey('stock-mapping-variant'),
        initialValue: data.variants.any((v) => v.id == variant) ? variant : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: l10n.stockMappingVariant),
        items: [
          DropdownMenuItem<String?>(child: Text(l10n.stockMappingNoVariant)),
          for (final v in data.variants.where((v) => v.active)) DropdownMenuItem<String?>(value: v.id, child: Text(v.label)),
        ],
        onChanged: (v) {
          variant = v;
          refresh();
        },
      ),
      const FormGap(),
      DropdownButtonFormField<String?>(
        key: const ValueKey('stock-mapping-unit'),
        initialValue: data.item.units.any((u) => u.unit == unit) ? unit : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: l10n.stockMappingUnit),
        items: [
          DropdownMenuItem<String?>(child: Text(data.item.inventoryUnit)),
          for (final u in data.item.units) DropdownMenuItem<String?>(value: u.unit, child: Text(u.unit)),
        ],
        onChanged: (v) {
          unit = v;
          refresh();
        },
      ),
    ];
  }
}
