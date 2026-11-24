// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4350 -- a NEW item from the Stock page: one sheet with its name, price, VAT rate, stock unit, barcode and
// home place. Saving makes the service (the money feature's command, through the port the app wires), then
// its stock settings (`save_stock_item_v1`: kept in stock, bought, sold, the unit, the barcode), then its home
// place. One sheet, one request id per step: a retry after a step succeeded does not repeat it (the service
// is made once, the settings and the home are answered again), so a lost answer never makes a second item. A
// refusal is said under the sheet; the mistakes the screen can see are said under their field first.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/format_controller.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/refusal_text.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/dropdown_field.dart';
import '../../../core/ui/form_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/stock_config.dart';
import '../domain/stock_config_commands.dart';
import '../domain/stock_registry.dart';
import '../domain/stock_service_creator.dart';
import '../domain/stock_sites.dart';
import '../domain/workspace_units.dart';
import 'measure_unit_text.dart';
import 'stock_config_text.dart';

/// What the sheet reads from and writes through.
typedef NewStockItemPorts = ({StockServiceCreator creator, StockConfigCommands commands, StockRegistry registry});

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

  /// One request id per step, per sheet: a retry answers once.
  final String _settingsRequest = newRequestId();
  final String _homeRequest = newRequestId();

  /// #4376 -- one request id for the creation of the item: a retry after a lost answer is the same request.
  final String _serviceRequest = newRequestId();
  String? vatId;
  String unit = 'piece';
  String? home;

  // what a failed save already did: the next try goes on from there
  String? _serviceId;
  bool _settingsSaved = false;
  bool _homeSaved = false;

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

  Future<String?> save(BuildContext context, AppLocalizations l10n, String workspaceId) async {
    try {
      final id = _serviceId ??= await ports.creator.create(
        workspaceId,
        name: fields.text('name').trim(),
        priceCents: _price(context) ?? 0,
        vatRateId: vatId,
        requestId: _serviceRequest,
      );
      if (!_settingsSaved) {
        final config = await ports.commands.item(workspaceId, id);
        if (config == null) return l10n.stockReadFailed;
        final barcode = fields.text('barcode').trim();
        await ports.commands.saveItem(
          workspaceId,
          StockItemConfig(
            itemId: id,
            revision: config.revision,
            stockable: true,
            purchasable: true,
            sellable: true,
            inventoryUnit: unit,
            tracking: 'none',
            shelfLifeDays: null,
            units: const [],
            codes: barcode.isEmpty ? const [] : [StockCodeDraft(code: barcode, kind: 'own')],
          ),
          _settingsRequest,
        );
        _settingsSaved = true;
      }
      final place = home;
      if (place != null && !_homeSaved) {
        await ports.registry.setHome(workspaceId, itemId: id, variantId: null, placeId: place, requestId: _homeRequest);
        _homeSaved = true;
      }
      return null;
    } on Object catch (e, st) {
      TraceLogger.instance.warn('stock', 'a new item was not saved', error: e, stackTrace: st);
      return knownRefusalText(l10n, e) ?? stockSaveProblem(l10n, e);
    }
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
