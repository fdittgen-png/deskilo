// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4350 -- a NEW item from the Stock page: one sheet with its name, price, VAT rate, stock unit, barcode and
// home place. Saving is one command (#4402, `create_stock_item_v1`): the service, its stock settings (kept in
// stock, bought, sold, the unit, the barcode) and its home place are made together or not at all, under one
// request id, so a lost answer never makes a second item and a closed sheet never leaves half of one. A refusal
// is said under the sheet; the mistakes the screen can see are said under their field first.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/format_controller.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/dropdown_field.dart';
import '../../../core/ui/form_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/stock_config.dart';
import '../domain/stock_config_commands.dart';
import '../domain/stock_drafts.dart';
import '../domain/stock_service_creator.dart';
import '../domain/stock_sites.dart';
import '../domain/workspace_units.dart';
import 'measure_unit_text.dart';
import 'stock_config_text.dart';

/// What the sheet reads from and writes through.
typedef NewStockItemPorts = ({StockServiceCreator creator, StockConfigCommands commands});

/// What the sheet chooses from: the VAT rates, the places (and their address separator) and the currency.
typedef NewStockItemChoices = ({List<StockVatChoice> vat, List<StockPlaceConfig> places, String separator, String currency, String unit, List<WorkspaceUnit> units});

/// Opens the sheet; true when the item was made.
Future<bool> showNewStockItemSheet(
  BuildContext context,
  NewStockItemPorts ports, {
  required String workspaceId,
  required NewStockItemChoices choices,
}) {
  final l10n = context.l10n;
  final draft = _NewItemDraft(ports, choices.vat, choices.places, choices.separator, choices.currency, choices.units)
    ..unit = choices.units.any((u) => u.code == choices.unit) ? choices.unit : choices.units.first.code;
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.stockItemNewTitle,
      submitLabel: l10n.stockEditSave,
      submitKey: const ValueKey('stock-new-item-save'),
      onDispose: draft.fields.dispose,
      validate: () => draft.validate(context, l10n),
      onSubmit: () => draft.save(context, l10n, workspaceId),
      builder: draft.build,
    ),
  );
}

class _NewItemDraft {
  _NewItemDraft(this.ports, this.vat, List<StockPlaceConfig> places, this.separator, this.currency, this.units)
    : places = stockRealPlaces(places),
      vatId = vat.isEmpty ? null : vat.first.id,
      fields = FormControllers({'name': '', 'price': '', 'barcode': ''});

  final NewStockItemPorts ports;

  /// The units the item may be counted in: the business's own that are not archived (the six of before while the feature is off).
  final List<WorkspaceUnit> units;
  final List<StockVatChoice> vat;
  final List<StockPlaceConfig> places;
  final String separator;
  final String currency;
  final FormControllers fields;

  /// #4402 -- one request id for the whole of the new item: a retry after a lost answer is the same request.
  String _request = newRequestId();
  String? vatId;
  String unit = 'piece';
  String? home;

  FieldErrors validate(BuildContext context, AppLocalizations l10n) {
    final errors = <String, String>{};
    if (fields.text('name').trim().isEmpty) errors['name'] = l10n.stockItemNewNameRequired;
    if (_price(context) == null) errors['price'] = l10n.stockItemNewPriceInvalid;
    return errors;
  }

  /// The price in minor units; an empty field is a price of nothing.
  int? _price(BuildContext context) {
    final text = fields.text('price').trim();
    return text.isEmpty ? 0 : appFormatOf(context).parseMinor(text);
  }

  Future<String?> save(BuildContext context, AppLocalizations l10n, String workspaceId) {
    final barcode = fields.text('barcode').trim();
    final item = NewStockItemDraft(
      name: fields.text('name').trim(),
      priceCents: _price(context) ?? 0,
      vatRateId: vatId,
      inventoryUnit: unit,
      barcode: barcode.isEmpty ? null : barcode,
      homeLocationId: home,
    );
    return guardSave(
      domain: 'stock',
      message: 'a new item was not made',
      action: () => ports.commands.createItem(workspaceId, item, _request),
      problem: (e) {
        // a refusal is an answer and nothing was made: the next try is a new request; an unknown outcome (the
        // connection) keeps its id, so the retry answers the item if it was made
        if (e is StockConfigFailure) _request = newRequestId();
        return stockProblemText(l10n, e);
      },
    );
  }

  List<Widget> build(BuildContext context, VoidCallback refresh) {
    final l10n = context.l10n;
    return [
      AppTextField(key: const ValueKey('stock-new-item-name'), controller: fields['name'], fieldKey: 'name', label: l10n.stockItemNewName, autofocus: true),
      const FormGap(),
      AppTextField(
        key: const ValueKey('stock-new-item-price'),
        controller: fields['price'],
        fieldKey: 'price',
        label: l10n.stockItemNewPrice(currency),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      ),
      if (vat.isNotEmpty) ...[
        const FormGap(),
        AppDropdownField<String?>(
          key: const ValueKey('stock-new-item-vat'),
          label: l10n.vatServiceRate,
          value: vatId,
          items: [for (final v in vat) (v.id, v.label)],
          onChanged: (v) {
            vatId = v;
            refresh();
          },
        ),
      ],
      const FormGap(),
      AppDropdownField<String>(
        key: const ValueKey('stock-new-item-unit'),
        label: l10n.stockItemNewUnit,
        value: unit,
        items: [for (final u in units) (u.code, measureUnitName(l10n, u))],
        onChanged: (v) {
          unit = v ?? unit;
          refresh();
        },
      ),
      const FormGap(),
      AppTextField(key: const ValueKey('stock-new-item-barcode'), controller: fields['barcode'], fieldKey: 'barcode', label: l10n.stockItemNewBarcode),
      if (places.isNotEmpty) ...[
        const FormGap(),
        AppDropdownField<String?>(
          key: const ValueKey('stock-new-item-home'),
          label: l10n.stockItemNewHome,
          value: home,
          items: [(null, l10n.stockItemNewNoHome), for (final p in places) (p.id, stockAddress(p, separator))],
          onChanged: (v) {
            home = v;
            refresh();
          },
        ),
      ],
    ];
  }
}
