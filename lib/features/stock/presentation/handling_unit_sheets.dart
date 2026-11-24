// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4435 (G20) -- the forms of the handling units: make a unit from loose stock, move one to another place, repack the content of
// one into boxes of the store's own. Each is one request with its own id; a refusal (the unit changed, the content does not fit)
// is told in words and nothing is kept. The server decides; the form only names what the person chose.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/format/decimal_input.dart';
import '../../../core/i18n/format_controller.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/dropdown_field.dart';
import '../../../core/ui/form_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/handling_units.dart';
import '../domain/stock_config.dart';
import '../domain/stock_page.dart';
import 'stock_config_text.dart';

String unitKindText(AppLocalizations l10n, HandlingUnitKind kind) => switch (kind) {
  HandlingUnitKind.pallet => l10n.stockUnitKindPallet,
  HandlingUnitKind.carton => l10n.stockUnitKindCarton,
  HandlingUnitKind.crate => l10n.stockUnitKindCrate,
  HandlingUnitKind.box => l10n.stockUnitKindBox,
  HandlingUnitKind.other => l10n.stockUnitKindOther,
  HandlingUnitKind.unknown => l10n.stockStateUnknown,
};

/// A quantity typed in the member's format (1,5 or 1.5) as the exact text the server reads; what is no quantity is
/// sent as typed, for the server to refuse.
String _typed(BuildContext context, String raw) =>
    exactQuantityFromInput(raw, locale: appFormatOf(context).locale).value?.text ?? raw.trim();

/// What a command of a unit answered, or the words of why it did not: null when it worked.
Future<String?> _guard(AppLocalizations l10n, Future<void> Function() act) async {
  try {
    await act();
    return null;
  } on StockConfigFailure catch (e, stack) {
    TraceLogger.instance.warn('stock', 'a handling unit command was refused', error: e, stackTrace: stack);
    return stockSaveProblem(l10n, e);
  }
}

/// Make a unit at a place from the stock that is loose there: one line of content (item and quantity) in this form; more lines
/// are added by making the unit again with the same code's content moved in a repack.
Future<void> showMakeUnitSheet(
  BuildContext context,
  StockHandlingUnits units, {
  required String workspaceId,
  required List<StockPlaceConfig> places,
  required List<StockItem> items,
  required Future<void> Function(HandlingUnit made) onDone,
}) {
  final l10n = context.l10n;
  final fields = FormControllers({'code': '', 'label': '', 'quantity': ''});
  final requestId = newRequestId();
  var kind = HandlingUnitKind.box;
  String? place = places.firstOrNull?.id;
  String? item = items.firstOrNull?.id;
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.stockUnitMake,
      submitLabel: l10n.stockUnitMake,
      submitKey: const ValueKey('stock-unit-make-save'),
      onDispose: fields.dispose,
      onSubmit: () => _guard(l10n, () async {
        final made = await units.make(
          workspaceId,
          requestId,
          UnitDraft(
            code: fields['code'].text.trim(),
            labelCode: fields['label'].text.trim(),
            kind: kind,
            locationId: place ?? '',
            lines: [UnitLineDraft(itemId: item ?? '', quantity: _typed(context, fields['quantity'].text))],
          ),
        );
        await onDone(made);
      }),
      builder: (context, refresh) => [
        AppTextField(key: const ValueKey('stock-unit-code'), controller: fields['code'], label: l10n.stockUnitCode),
        const FormGap(),
        AppTextField(key: const ValueKey('stock-unit-label'), controller: fields['label'], label: l10n.stockUnitLabelCode),
        const FormGap(),
        AppDropdownField<HandlingUnitKind>(
          key: const ValueKey('stock-unit-kind'),
          label: l10n.stockUnitKind,
          value: kind,
          items: [for (final k in HandlingUnitKind.values) (k, unitKindText(l10n, k))],
          onChanged: (v) {
            kind = v ?? kind;
            refresh();
          },
        ),
        const FormGap(),
        AppDropdownField<String>(
          key: const ValueKey('stock-unit-place'),
          label: l10n.stockUnitPlace,
          value: place,
          items: [for (final p in places) (p.id, p.code)],
          onChanged: (v) {
            place = v;
            refresh();
          },
        ),
        const FormGap(),
        AppDropdownField<String>(
          key: const ValueKey('stock-unit-item'),
          label: l10n.expenseSupplyItem,
          value: item,
          items: [for (final i in items) (i.id, i.name)],
          onChanged: (v) {
            item = v;
            refresh();
          },
        ),
        const FormGap(),
        AppTextField(
          key: const ValueKey('stock-unit-quantity'),
          controller: fields['quantity'],
          label: l10n.purchasesQuantity,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        ),
      ],
    ),
  );
}

/// Move a unit, with its whole content, to another place.
Future<void> showMoveUnitSheet(
  BuildContext context,
  StockHandlingUnits units, {
  required String workspaceId,
  required HandlingUnit unit,
  required List<StockPlaceConfig> places,
  required Future<void> Function(HandlingUnit moved, String placeCode) onDone,
}) {
  final l10n = context.l10n;
  final requestId = newRequestId();
  final others = [for (final p in places) if (p.id != unit.locationId) p];
  String? to = others.firstOrNull?.id;
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.stockUnitMove,
      submitLabel: l10n.stockUnitMove,
      submitKey: const ValueKey('stock-unit-move-save'),
      onSubmit: () => _guard(l10n, () async {
        final moved = await units.move(workspaceId, requestId, unitId: unit.id, toLocationId: to ?? '', revision: unit.revision);
        await onDone(moved, others.firstWhere((p) => p.id == to).code);
      }),
      builder: (context, refresh) => [
        AppDropdownField<String>(
          key: const ValueKey('stock-unit-move-to'),
          label: l10n.stockUnitMoveTo,
          value: to,
          items: [for (final p in others) (p.id, p.code)],
          onChanged: (v) {
            to = v;
            refresh();
          },
        ),
      ],
    ),
  );
}

/// Repack one line of a unit into [boxes] boxes of the store's own, [each] in each (the rest stays in the unit).
Future<void> showRepackSheet(
  BuildContext context,
  StockHandlingUnits units, {
  required String workspaceId,
  required HandlingUnitDetail detail,
  required Future<void> Function(List<HandlingUnit> made) onDone,
}) {
  final l10n = context.l10n;
  final fields = FormControllers({'boxes': '2', 'each': ''});
  final requestId = newRequestId();
  final lines = [for (final l in detail.lines) if (l.pieces.isEmpty) l];
  HandlingUnitLine? line = lines.firstOrNull;
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.stockUnitRepack,
      submitLabel: l10n.stockUnitRepack,
      submitKey: const ValueKey('stock-unit-repack-save'),
      onDispose: fields.dispose,
      onSubmit: () => _guard(l10n, () async {
        final l = line;
        final n = int.tryParse(fields['boxes'].text.trim()) ?? 0;
        final each = exactQuantityFromInput(fields['each'].text, locale: appFormatOf(context).locale).value;
        if (each == null) throw const StockConfigRefused('each', 'quantity_invalid');
        var total = ExactQuantity.zero;
        for (var i = 0; i < n; i++) {
          total = total + each;
        }
        final made = await units.repack(
          workspaceId,
          requestId,
          sources: [
            RepackSource(
              unitId: detail.unit.id,
              revision: detail.unit.revision,
              line: UnitLineDraft(itemId: l?.itemId ?? '', variantId: l?.variantId, lotId: l?.lotId, quantity: total.text),
            ),
          ],
          targets: [
            for (var i = 1; i <= n; i++)
              UnitDraft(
                code: '${detail.unit.code}-$i',
                kind: HandlingUnitKind.box,
                locationId: detail.unit.locationId,
                lines: [UnitLineDraft(itemId: l?.itemId ?? '', variantId: l?.variantId, lotId: l?.lotId, quantity: each.text)],
              ),
          ],
        );
        await onDone(made);
      }),
      builder: (context, refresh) => [
        AppDropdownField<HandlingUnitLine>(
          key: const ValueKey('stock-unit-repack-item'),
          label: l10n.stockUnitRepackItem,
          value: line,
          items: [for (final l in lines) (l, '${l.itemName} · ${appFormatOf(context).quantity(l.quantity)} ${l.unit}')],
          onChanged: (v) {
            line = v;
            refresh();
          },
        ),
        const FormGap(),
        AppTextField(
          key: const ValueKey('stock-unit-repack-boxes'),
          controller: fields['boxes'],
          label: l10n.stockUnitRepackBoxes,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const FormGap(),
        AppTextField(
          key: const ValueKey('stock-unit-repack-each'),
          controller: fields['each'],
          label: l10n.stockUnitRepackEach,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        ),
      ],
    ),
  );
}
