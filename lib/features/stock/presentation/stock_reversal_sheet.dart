// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4172 (B) -- a return or a correction of ONE movement, as a small form: the
// source is shown first (what moved, between which places, how much), then how
// much of it can still be reversed and what was reversed already, so the person
// decides with the figures in front of them. A customer return names the real
// place the goods come back to, a supplier return the real place they leave
// from, a correction nothing. Nothing is paid, refunded or credited by it: the
// sheet says so. A refusal says why under the sheet and moves nothing; one set
// of identities per form (the return, its line and the request) makes a retry
// answer once. The quantity is read exactly, as it was typed.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show ExactQuantity;
import 'package:flutter/material.dart';

import '../../../core/i18n/app_format.dart';
import '../../../core/i18n/format_controller.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/refusal_text.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/form_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/stock_config.dart';
import '../domain/stock_page.dart';
import '../domain/stock_reversals.dart';
import '../domain/stock_sites.dart';
import 'stock_config_text.dart';
import 'stock_move_sheets.dart' show StockPickField;
import 'stock_quantity_field.dart';

String _placeTitle(StockPlaceConfig p) => p.name.isEmpty ? p.code : '${p.code} · ${p.name}';

/// What a person can do with [source]: a sale comes back from a customer, a
/// receipt goes back to its supplier, any other movement (but an opening or a
/// leg of a transfer through the road) is corrected.
StockReturnKind? stockReturnKindOf(StockMovementRow source) => switch (source.reason) {
  'sale' => StockReturnKind.customer,
  'receipt' => StockReturnKind.supplier,
  'opening' => null,
  _ => StockReturnKind.correction,
};

/// Opens the form for [kind] over [source]; true when the return was made.
Future<bool> showStockReversalSheet(
  BuildContext context,
  StockReversals reversals, {
  required StockMovementRow source,
  required StockReversible allows,
  required StockReturnKind kind,
  required List<StockPlaceConfig> places,
}) {
  final l10n = context.l10n;
  final draft = _ReversalDraft(
    source: source,
    allows: allows,
    kind: kind,
    places: stockRealPlaces(places),
    format: appFormatOf(context),
  );
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: switch (kind) {
        StockReturnKind.customer => l10n.stockReversalCustomerTitle,
        StockReturnKind.supplier => l10n.stockReversalSupplierTitle,
        StockReturnKind.correction => l10n.stockReversalCorrectionTitle,
      },
      submitLabel: l10n.stockReversalSubmit,
      submitKey: const ValueKey('stock-reversal-submit'),
      onDispose: draft.fields.dispose,
      validate: () => draft.validate(l10n),
      onSubmit: () => draft.submit(l10n, reversals, source.workspaceId),
      builder: draft.build,
    ),
  );
}

class _ReversalDraft {
  _ReversalDraft({
    required this.source,
    required this.allows,
    required this.kind,
    required this.places,
    required this.format,
  }) : fields = FormControllers({'quantity': format.quantity(allows.remaining, grouped: false), 'note': ''});

  final StockMovementRow source;
  final StockReversible allows;
  final StockReturnKind kind;
  final List<StockPlaceConfig> places;
  /// The member's format: what the quantity field is written and read in.
  final AppFormat format;
  String get locale => format.locale;
  final FormControllers fields;

  /// One identity of each per form: the return, its line and the request, so a
  /// retry of the same submit answers once.
  final String returnId = newRequestId();
  final String lineId = newRequestId();
  final String requestId = newRequestId();
  String? place;

  bool get needsPlace => kind != StockReturnKind.correction;

  ExactQuantity? get quantity => stockQuantityOrNull(fields.text('quantity'), locale: locale);

  FieldErrors validate(AppLocalizations l10n) {
    final q = quantity;
    return {
      if (needsPlace && place == null) 'place': stockReasonText(l10n, 'location_foreign'),
      if (q == null || q <= ExactQuantity.zero) 'quantity': stockReasonText(l10n, 'quantity_invalid'),
      if (q != null && q > allows.remaining) 'quantity': l10n.stockReversalMoreThanRemains(format.quantity(allows.remaining), source.unit),
    };
  }

  Future<String?> submit(AppLocalizations l10n, StockReversals reversals, String workspaceId) async {
    try {
      await reversals.makeReturn(
        workspaceId,
        returnId,
        kind,
        [
          (
            lineId: lineId,
            sourceMovementId: source.id,
            quantity: quantity!.text,
            locationId: needsPlace ? place : null,
            note: fields.text('note').trim(),
          ),
        ],
        requestId,
      );
      return null;
    } on Object catch (e, st) {
      TraceLogger.instance.warn('stock', 'goods were not reversed', error: e, stackTrace: st);
      return knownRefusalText(l10n, e) ?? stockSaveProblem(l10n, e);
    }
  }

  List<Widget> build(BuildContext context, VoidCallback refresh) {
    final l10n = context.l10n;
    final theme = Theme.of(context).textTheme.bodyMedium;
    final options = [for (final p in places) (p.id, _placeTitle(p))];
    return [
      Text(
        key: const ValueKey('stock-reversal-source'),
        l10n.stockReversalSource(source.itemLabel, source.fromLocationCode, source.toLocationCode, appFormatOf(context).quantity(source.quantity), source.unit),
        style: theme,
      ),
      const FormGap(),
      Text(
        key: const ValueKey('stock-reversal-remaining'),
        allows.fullyReversed
            ? l10n.stockReversalFully
            : l10n.stockReversalRemaining(appFormatOf(context).quantity(allows.remaining), source.unit, appFormatOf(context).quantity(allows.reversed)),
        style: theme,
      ),
      const FormGap(),
      if (needsPlace) ...[
        StockPickField(
          keyName: 'place',
          label: kind == StockReturnKind.customer ? l10n.stockReversalBackTo : l10n.stockReversalLeavesFrom,
          value: place,
          options: options,
          onPicked: (v) {
            place = v;
            refresh();
          },
        ),
        const FormGap(),
      ],
      StockQuantityField(
        key: const ValueKey('stock-reversal-quantity'),
        controller: fields['quantity'],
        fieldKey: 'quantity',
        label: l10n.stockMoveQuantity(source.unit),
      ),
      const FormGap(),
      AppTextField(
        key: const ValueKey('stock-reversal-note'),
        controller: fields['note'],
        fieldKey: 'note',
        label: l10n.stockReversalNote,
      ),
      const FormGap(),
      Text(
        key: const ValueKey('stock-reversal-no-money'),
        l10n.stockReversalNoMoney,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ];
  }
}
