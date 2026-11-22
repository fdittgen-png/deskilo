// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4169 (B1) -- the places of the business: a list of what is kept (the
// system's own places shown, not editable) and one editor for a place: its
// kind, code, name, barcode, the place it is inside and whether it is in use.
// A save names the revision it read; a refusal says why under the place.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/dropdown_field.dart';
import '../../../core/ui/form_kit.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/stock_config.dart';
import '../domain/stock_config_check.dart';
import '../domain/stock_config_commands.dart';
import '../providers/stock_providers.dart';
import 'stock_config_text.dart';

String _kindLabel(AppLocalizations l10n, String kind) => switch (kind) {
  'site' => l10n.stockPlaceKindSite,
  'warehouse' => l10n.stockPlaceKindWarehouse,
  'zone' => l10n.stockPlaceKindZone,
  'aisle' => l10n.stockPlaceKindAisle,
  'bay' => l10n.stockPlaceKindBay,
  'shelf' => l10n.stockPlaceKindShelf,
  'bin' => l10n.stockPlaceKindBin,
  _ => kind,
};

String _placeTitle(StockPlaceConfig p) => p.name.isEmpty ? p.code : '${p.code} · ${p.name}';

String _roleLabel(AppLocalizations l10n, String role) =>
    role == 'reserve' ? l10n.stockPlaceRoleReserve : l10n.stockPlaceRolePicking;

/// One place of the list: its address (as the person reads it), then its kind, name, whether
/// a site receives from suppliers, and its use.
Widget _placeTile(AppLocalizations l10n, StockPlaceConfig p, String separator, VoidCallback? onTap) {
  final site = stockKindLevel(p.kind) == 1;
  return ListTile(
    key: ValueKey('stock-place-${p.id}'),
    title: Text(
      p.virtual ? _placeTitle(p) : stockAddress(p, separator),
      style: p.active ? null : const TextStyle(decoration: TextDecoration.lineThrough),
    ),
    subtitle: Text(
      p.virtual
          ? l10n.stockPlaceVirtual
          : [
              _kindLabel(l10n, p.kind),
              if (p.name.isNotEmpty) p.name,
              if (site && p.receivesFromSuppliers) l10n.stockPlaceReceivesYes,
              if (site && !p.receivesFromSuppliers) l10n.stockPlaceReceivesNo,
              if (p.pickRole != null) _roleLabel(l10n, p.pickRole!),
            ].join(' · '),
    ),
    onTap: onTap,
  );
}

/// What a place is found by: its address (as the person reads it), name, code and barcode.
bool _placeMatches(StockPlaceConfig p, String separator, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return stockAddress(p, separator).toLowerCase().contains(q) ||
      p.name.toLowerCase().contains(q) ||
      (p.barcode ?? '').toLowerCase().contains(q);
}

/// The places of [workspaceId] as the body of the Places page, each opening
/// its editor; a place is added from the button.
class StockPlacesBody extends ConsumerStatefulWidget {
  const StockPlacesBody({
    super.key,
    required this.workspaceId,
    required this.onChanged,
    this.canEdit = true,
  });

  final String workspaceId;
  final VoidCallback onChanged;

  /// Whether the person may add and edit places (the server asks the same).
  final bool canEdit;

  @override
  ConsumerState<StockPlacesBody> createState() => _PlacesSheetState();
}

class _PlacesSheetState extends ConsumerState<StockPlacesBody> {
  late Future<List<StockPlaceConfig>> _places = _read();
  String _query = '';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // read at the time, so a read that cannot be made is the page's own failure
  Future<List<StockPlaceConfig>> _read() async => ref.read(stockConfigCommandsProvider).places(widget.workspaceId);

  Future<void> _edit(List<StockPlaceConfig> all, StockPlaceConfig? place) async {
    final saved = await _showStockPlaceEditor(
      context,
      ref.read(stockConfigCommandsProvider),
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
    return Padding(
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
            final separator = ref.watch(stockAddressSeparatorProvider);
            final shown = [
              for (final p in all)
                if (_placeMatches(p, separator, _query)) p,
            ]..sort((a, b) => a.addressPath.compareTo(b.addressPath));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  key: const ValueKey('stock-places-search'),
                  controller: _search,
                  fieldKey: 'search',
                  label: l10n.stockPlacesSearch,
                  onChanged: (v) => setState(() => _query = v),
                ),
                const FormGap.small(),
                Expanded(
                  child: ListView(
                    children: [
                      for (final p in shown)
                        _placeTile(
                          l10n,
                          p,
                          separator,
                          p.virtual || !widget.canEdit ? null : () => _edit(all, p),
                        ),
                    ],
                  ),
                ),
                if (widget.canEdit)
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
      receives = place?.receivesFromSuppliers ?? true,
      role = place?.pickRole,
      all = [
        for (final p in all)
          if (!p.virtual && p.id != place?.id) p,
      ];

  final StockPlaceConfig? place;
  final FormControllers fields;
  final List<StockPlaceConfig> all;

  /// One per editor: a retry of the same save answers once.
  final String requestId = newRequestId();
  String kind;
  String? parent;
  bool active;
  bool receives;
  String? role;

  /// What the kind says: a site is a root, a place of a level sits under the level above it.
  List<StockPlaceConfig> get parents => stockParentChoices(kind, all);
  bool get isSite => stockKindLevel(kind) == 1;

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
          'parent_id': isSite ? null : parent,
          'active': active,
          'receives_from_suppliers': !isSite || receives,
          'pick_role': isSite ? null : role,
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
          for (final k in {if (!stockPlaceKinds.contains(kind)) kind, ...stockPlaceKinds})
            DropdownMenuItem(value: k, child: Text(_kindLabel(l10n, k))),
        ],
        onChanged: (v) {
          kind = v ?? kind;
          // the parent must be of the level above the new kind
          if (parent != null && !parents.any((p) => p.id == parent)) parent = null;
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
      if (!isSite)
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
      if (isSite)
        SwitchListTile(
          key: const ValueKey('stock-place-receives'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.stockPlaceReceives),
          subtitle: Text(l10n.stockPlaceReceivesHelp),
          value: receives,
          onChanged: (v) {
            receives = v;
            refresh();
          },
        )
      else
        AppDropdownField<String?>(
          key: const ValueKey('stock-place-role'),
          label: l10n.stockPlaceRole,
          value: role,
          items: [
            (null, l10n.stockPlaceRoleNone),
            ('picking', l10n.stockPlaceRolePicking),
            ('reserve', l10n.stockPlaceRoleReserve),
          ],
          onChanged: (v) {
            role = v;
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
