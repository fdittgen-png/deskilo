// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4169 (B1) -- the places of the business: a list of what is kept (the
// system's own places shown, not editable) and one editor for a place: its
// kind, code, name, barcode, the place it is inside and whether it is in use.
// A save names the revision it read; a refusal says why under the place.
import 'package:flutter/material.dart';

import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/form_kit.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/stock_config.dart';
import '../domain/stock_config_check.dart';
import '../domain/stock_config_commands.dart';
import 'stock_config_text.dart';

String _kindLabel(AppLocalizations l10n, String kind) => switch (kind) {
  'warehouse' => l10n.stockPlaceKindWarehouse,
  'zone' => l10n.stockPlaceKindZone,
  'shelf' => l10n.stockPlaceKindShelf,
  'bin' => l10n.stockPlaceKindBin,
  _ => kind,
};

String _placeTitle(StockPlaceConfig p) => p.name.isEmpty ? p.code : '${p.code} · ${p.name}';

/// The places of [workspaceId], each opening its editor; a place is added
/// from the button.
Future<void> showStockPlaces(
  BuildContext context,
  StockConfigCommands commands, {
  required String workspaceId,
  required VoidCallback onChanged,
}) => showAppSheet<void>(
  context: context,
  isScrollControlled: true,
  // recorder-key-exempt: a data callback, not a control
  builder: (_) => _PlacesSheet(commands: commands, workspaceId: workspaceId, onChanged: onChanged),
);

class _PlacesSheet extends StatefulWidget {
  const _PlacesSheet({required this.commands, required this.workspaceId, required this.onChanged});

  final StockConfigCommands commands;
  final String workspaceId;
  final VoidCallback onChanged;

  @override
  State<_PlacesSheet> createState() => _PlacesSheetState();
}

class _PlacesSheetState extends State<_PlacesSheet> {
  late Future<List<StockPlaceConfig>> _places = _read();

  Future<List<StockPlaceConfig>> _read() => widget.commands.places(widget.workspaceId);

  Future<void> _edit(List<StockPlaceConfig> all, StockPlaceConfig? place) async {
    final saved = await _showStockPlaceEditor(
      context,
      widget.commands,
      workspaceId: widget.workspaceId,
      place: place,
      all: all,
    );
    if (saved && mounted) {
      widget.onChanged();
      setState(() {
        _places = _read();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: FutureBuilder<List<StockPlaceConfig>>(
          future: _places,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Column(
                key: const ValueKey('stock-places-failed'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.stockReadFailed),
                  TextButton(
                    key: const ValueKey('stock-places-retry'),
                    onPressed: () => setState(() {
                      _places = _read();
                    }),
                    child: Text(l10n.identityConnectRetry),
                  ),
                ],
              );
            }
            final all = snapshot.data;
            if (all == null) return const LoadingView();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.stockPlacesTitle, style: Theme.of(context).textTheme.titleMedium),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final p in all)
                        ListTile(
                          key: ValueKey('stock-place-${p.id}'),
                          title: Text(
                            _placeTitle(p),
                            style: p.active ? null : const TextStyle(decoration: TextDecoration.lineThrough),
                          ),
                          subtitle: Text(
                            p.virtual ? l10n.stockPlaceVirtual : _kindLabel(l10n, p.kind),
                          ),
                          onTap: p.virtual ? null : () => _edit(all, p),
                        ),
                    ],
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('stock-place-add'),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.stockPlacesAdd),
                  onPressed: () => _edit(all, null),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The editor of one place ([place] null: a new one); true when saved.
Future<bool> _showStockPlaceEditor(
  BuildContext context,
  StockConfigCommands commands, {
  required String workspaceId,
  required StockPlaceConfig? place,
  required List<StockPlaceConfig> all,
}) {
  final l10n = context.l10n;
  final draft = _PlaceDraft(place, all);
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.stockPlaceEditTitle,
      submitLabel: l10n.stockEditSave,
      submitKey: const ValueKey('stock-place-save'),
      onDispose: draft.fields.dispose,
      validate: () => draft.validate(l10n),
      onSubmit: () => draft.save(l10n, commands, workspaceId),
      builder: draft.build,
    ),
  );
}

class _PlaceDraft {
  _PlaceDraft(this.place, List<StockPlaceConfig> all)
    : fields = FormControllers({
        'code': place?.code ?? '',
        'name': place?.name ?? '',
        'barcode': place?.barcode ?? '',
      }),
      kind = place?.kind ?? stockPlaceKinds.first,
      parent = place?.parentId,
      active = place?.active ?? true,
      parents = [
        for (final p in all)
          if (!p.virtual && p.id != place?.id) p,
      ];

  final StockPlaceConfig? place;
  final FormControllers fields;
  final List<StockPlaceConfig> parents;

  /// One per editor: a retry of the same save answers once.
  final String requestId = newRequestId();
  String kind;
  String? parent;
  bool active;

  FieldErrors validate(AppLocalizations l10n) => {
    for (final e in checkStockPlace(
      code: fields.text('code'),
      name: fields.text('name'),
      barcode: fields.text('barcode'),
    ).entries)
      e.key: stockReasonText(l10n, e.value),
  };

  Future<String?> save(AppLocalizations l10n, StockConfigCommands commands, String workspaceId) async {
    try {
      await commands.savePlace(
        workspaceId,
        place: {
          'kind': kind,
          'code': fields.text('code'),
          'name': fields.text('name'),
          'barcode': fields.text('barcode').isEmpty ? null : fields.text('barcode'),
          'parent_id': parent,
          'active': active,
        },
        requestId: requestId,
        placeId: place?.id,
        expectedRevision: place?.revision,
      );
      return null;
    } on Object catch (e, st) {
      TraceLogger.instance.warn('stock', 'a place was not saved: $e', stackTrace: st);
      return stockSaveProblem(l10n, e);
    }
  }

  List<Widget> build(BuildContext context, VoidCallback refresh) {
    final l10n = context.l10n;
    return [
      DropdownButtonFormField<String>(
        key: const ValueKey('stock-place-kind'),
        initialValue: kind,
        isExpanded: true,
        decoration: InputDecoration(labelText: l10n.stockPlaceKind),
        items: [
          for (final k in stockPlaceKinds)
            DropdownMenuItem(value: k, child: Text(_kindLabel(l10n, k))),
        ],
        onChanged: (v) {
          kind = v ?? kind;
          refresh();
        },
      ),
      const FormGap(),
      AppTextField(
        key: const ValueKey('stock-place-code'),
        controller: fields['code'],
        fieldKey: 'code',
        label: l10n.stockPlaceCode,
      ),
      const FormGap(),
      AppTextField(
        key: const ValueKey('stock-place-name'),
        controller: fields['name'],
        fieldKey: 'name',
        label: l10n.stockPlaceName,
      ),
      const FormGap(),
      AppTextField(
        key: const ValueKey('stock-place-barcode'),
        controller: fields['barcode'],
        fieldKey: 'barcode',
        label: l10n.stockPlaceBarcode,
      ),
      const FormGap(),
      DropdownButtonFormField<String?>(
        key: const ValueKey('stock-place-parent'),
        initialValue: parent,
        isExpanded: true,
        decoration: InputDecoration(labelText: l10n.stockPlaceParent),
        items: [
          DropdownMenuItem<String?>(child: Text(l10n.stockPlaceNoParent)),
          for (final p in parents) DropdownMenuItem<String?>(value: p.id, child: Text(_placeTitle(p))),
        ],
        onChanged: (v) {
          parent = v;
          refresh();
        },
      ),
      SwitchListTile(
        key: const ValueKey('stock-place-active'),
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
