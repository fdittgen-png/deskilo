// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4169 (B1) -- the places of the business: a list of what is kept (the
// system's own places shown, not editable) and one editor for a place: its
// kind, code, name, barcode, the place it is inside and whether it is in use.
// A save names the revision it read; a refusal says why under the place.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/files/file_delivery.dart';
import '../../../core/files/file_delivery_notice.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/scan/scan_scope.dart';
import '../../../core/text/collation.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../../../core/ui/dropdown_field.dart';
import '../../../core/ui/form_kit.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../application/stock_reads.dart';
import '../domain/place_labels_pdf.dart';
import '../domain/stock_config.dart';
import '../domain/stock_config_check.dart';
import '../domain/stock_config_commands.dart';
import '../domain/stock_drafts.dart';
import '../domain/stock_tags.dart';
import '../providers/stock_providers.dart';
import 'stock_config_text.dart';
import 'stock_read_failed.dart';
import 'stock_screen_scan.dart';
import 'stock_tags_dialog.dart';

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
Widget _placeTile(AppLocalizations l10n, StockPlaceConfig p, String separator, VoidCallback? onTap, {VoidCallback? onTags}) {
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
    trailing: onTags == null
        ? null
        : IconButton(key: ValueKey('stock-place-tags-${p.id}'), icon: const Icon(Icons.nfc), tooltip: l10n.stockTagsOpen, onPressed: onTags),
  );
}

/// What a place is found by: its address (as the person reads it), name, code and barcode.
bool _placeMatches(StockPlaceConfig p, String separator, String query) {
  final q = foldForSearch(query.trim());
  if (q.isEmpty) return true;
  return foldForSearch(stockAddress(p, separator)).contains(q) ||
      foldForSearch(p.name).contains(q) ||
      foldForSearch(p.barcode ?? '').contains(q);
}

/// The places of [workspaceId] as the body of the Places page, each opening
/// its editor; a place is added from the button.
class StockPlacesBody extends ConsumerStatefulWidget {
  const StockPlacesBody({
    super.key,
    required this.workspaceId,
    required this.onChanged,
    this.canEdit = true,
    this.addFirst = false,
  });

  final String workspaceId;
  final VoidCallback onChanged;

  /// Whether the person may add and edit places (the server asks the same).
  final bool canEdit;

  /// #4350 -- the first-run link: the editor of a new place opens once the places are read.
  final bool addFirst;

  @override
  ConsumerState<StockPlacesBody> createState() => _PlacesSheetState();
}

class _PlacesSheetState extends ConsumerState<StockPlacesBody> {
  late Future<List<StockPlaceConfig>> _places = _read();
  String _query = '';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.addFirst && widget.canEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final all = await _places;
        if (mounted) await _edit(all, null);
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The labels of the places shown (the real ones, in use) as a PDF, handed to the file saver.
  Future<void> _printLabels(List<StockPlaceConfig> shown, String separator) async {
    final l10n = context.l10n;
    final labels = [
      for (final p in shown)
        if (p.isAddressable && p.active)
          PlaceLabel(
            address: stockAddress(p, separator),
            barcode: p.barcode ?? stockAddress(p, separator),
            name: p.name,
          ),
    ];
    if (labels.isEmpty) {
      AppSnack.info(context, l10n.stockPlacesLabelsNone);
      return;
    }
    // #4411 -- the shared guarded path: traced at error, and a lost
    // connection or a known refusal said in its own words.
    await runGuarded(
      context,
      domain: 'stock',
      message: 'the place labels were not made',
      errorText: l10n.commonSaveFailed,
      action: () async {
        final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
        final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
        final bytes = await buildPlaceLabelsPdf(
          labels: labels,
          baseFont: pw.Font.ttf(regular),
          boldFont: pw.Font.ttf(bold),
        );
        if (!mounted) return;
        final delivery = await deliverFile(context, ref, bytes: bytes, fileName: 'deskilo-place-labels.pdf');
        if (!mounted) return;
        announceFileDelivery(context, delivery, retry: () => unawaited(_printLabels(shown, separator)));
      },
    );
  }

  // read at the time, so a read that cannot be made is the page's own failure
  Future<List<StockPlaceConfig>> _read() => StockReads(ref.read(stockConfigCommandsProvider)).places(widget.workspaceId);

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

  /// A scanner's code (#4359): a place opens its editor.
  Future<void> _fromScanner(String code) async {
    final answer = await StockScreenScan(ref).resolve(context, widget.workspaceId, code);
    final scanned = answer?.place;
    if (scanned == null || !mounted || !widget.canEdit) return;
    final all = await _places;
    final place = all.where((p) => p.id == scanned.id).firstOrNull;
    if (place != null && mounted) await _edit(all, place);
  }

  @override
  Widget build(BuildContext context) => ScanScope(
    enabled: StockScreenScan(ref).on,
    onScan: (code) => unawaited(_fromScanner(code)),
    child: _content(context),
  );

  Widget _content(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: FutureBuilder<List<StockPlaceConfig>>(
          future: _places,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return StockReadFailed(
                keyName: 'stock-places',
                error: snapshot.error!,
                onRetry: () => setState(() {
                  _places = _read();
                }),
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
                          onTags: p.virtual || !widget.canEdit || !ref.watch(stockTagsProvider)
                              ? null
                              : () => showStockTagsDialog(
                                  context,
                                  workspaceId: widget.workspaceId,
                                  owner: TagOwner.place(p.id),
                                  name: _placeTitle(p),
                                ),
                        ),
                    ],
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('stock-places-print'),
                  icon: const Icon(Icons.print_outlined),
                  label: Text(l10n.stockPlacesPrintLabels),
                  onPressed: () => _printLabels(shown, separator),
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
      e.key: stockRefusalText(l10n, e.value),
  };

  Future<String?> save(AppLocalizations l10n, StockConfigCommands commands, String workspaceId) async {
    return guardSave(
      domain: 'stock',
      message: 'a place was not saved',
      action: () async {
        await commands.savePlace(
          workspaceId,
          place: StockPlaceDraft(
            kind: kind,
            code: fields.text('code'),
            name: fields.text('name'),
            barcode: fields.text('barcode').isEmpty ? null : fields.text('barcode'),
            parentId: isSite ? null : parent,
            active: active,
            receivesFromSuppliers: !isSite || receives,
            pickRole: isSite ? null : role,
          ),
          requestId: requestId,
          placeId: place?.id,
          expectedRevision: place?.revision,
        );
      },
      problem: (e) => stockProblemText(l10n, e),
    );
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
