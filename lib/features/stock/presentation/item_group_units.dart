// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4479 -- the unit proposals of an item group: the unit its items are BOUGHT in and the unit they are SOLD in, each with what one of it
// makes of the inventory unit, and for the sale unit its price. Proposals are copied into a new item as a starting point, never inherited
// and never linked. One class holds their fields, what they send, what they refuse and how they look in the group's sheet, so the sheet
// itself only places them.
import 'package:flutter/material.dart';

import '../../../core/format/amount_input.dart';
import '../../../core/i18n/app_format.dart';
import '../../../core/ui/form_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/item_groups.dart';
import '../domain/purchase_factor.dart';
import '../domain/workspace_units.dart';
import 'stock_unit_picker.dart';

class GroupUnitProposals {
  GroupUnitProposals(this.fields, this.format, this.workspaceId, this.units);

  final FormControllers fields;
  final AppFormat format;
  final String workspaceId;

  /// The units of the business a proposal may name.
  final List<WorkspaceUnit> units;

  /// The starting text of each field, from the parameters [params] (a group's own, or the values in force for an item).
  static Map<String, String> initial(Map<String, Object?> params, AppFormat format) {
    String factor(String numKey, String denKey) => params[numKey] == null
        ? ''
        : purchaseFactorText((params[numKey]! as num).toInt(), ((params[denKey] ?? 1) as num).toInt());
    final price = params[groupParamSalePrice];
    return {
      'purchaseUnit': '${params[groupParamPurchaseUnit] ?? ''}',
      'purchaseFactor': factor(groupParamPurchaseFactorNum, groupParamPurchaseFactorDen),
      'saleUnit': '${params[groupParamSaleUnit] ?? ''}',
      'saleFactor': factor(groupParamSaleFactorNum, groupParamSaleFactorDen),
      'salePrice': price == null ? '' : amountInputText((price as num).toInt(), currency: format.currencyCode, locale: format.locale),
    };
  }

  PurchaseFactor? _factorOf(String key) => fields.text(key).isEmpty ? null : parsePurchaseFactor(fields.text(key));

  int? get _price => fields.text('salePrice').isEmpty
      ? null
      : readAmountInput(fields.text('salePrice'), locale: format.locale, currency: format.currencyCode, allowNegative: false).minor;

  /// What is sent for these units: the group's values, or an item's own.
  Map<String, Object?> parameters() => {...purchaseParameters(), ...saleParameters()};

  /// The purchase block: the unit and its factor.
  Map<String, Object?> purchaseParameters() => {
    groupParamPurchaseUnit: fields.text('purchaseUnit').isEmpty ? null : fields.text('purchaseUnit'),
    groupParamPurchaseFactorNum: _factorOf('purchaseFactor')?.num,
    groupParamPurchaseFactorDen: _factorOf('purchaseFactor')?.den,
  };

  /// The sale block: the unit, its factor and its price.
  Map<String, Object?> saleParameters() => {
    groupParamSaleUnit: fields.text('saleUnit').isEmpty ? null : fields.text('saleUnit'),
    groupParamSaleFactorNum: _factorOf('saleFactor')?.num,
    groupParamSaleFactorDen: _factorOf('saleFactor')?.den,
    groupParamSalePrice: _price,
  };

  /// A unit and its factor go together, the factor is one number or a fraction above zero, the unit is one of the business's, and a price is an amount.
  FieldErrors errors(AppLocalizations l10n) => {
    for (final (unit, factor) in [('purchaseUnit', 'purchaseFactor'), ('saleUnit', 'saleFactor')]) ...{
      if (fields.text(factor).isNotEmpty && _factorOf(factor) == null) factor: l10n.stockReasonOutOfRange,
      if (fields.text(unit).isNotEmpty && fields.text(factor).isEmpty) factor: l10n.stockReasonOutOfRange,
      if (fields.text(unit).isEmpty && fields.text(factor).isNotEmpty) unit: l10n.stockReasonNameMalformed,
      if (fields.text(unit).isNotEmpty && !units.any((u) => u.code == fields.text(unit))) unit: l10n.masterDataUnlisted,
    },
    if (fields.text('salePrice').isNotEmpty && _price == null) 'salePrice': l10n.stockReasonOutOfRange,
  };

  /// The fields of the sheet; [edit] redraws it and [touched] drops its preview.
  List<Widget> widgets(AppLocalizations l10n, void Function(void Function()) edit, VoidCallback touched) =>
      [...purchaseWidgets(l10n, edit, touched), ...saleWidgets(l10n, edit, touched)];

  /// The purchase block's fields.
  List<Widget> purchaseWidgets(AppLocalizations l10n, void Function(void Function()) edit, VoidCallback touched) => [
    StockUnitPicker(
      key: const ValueKey('item-group-purchase-unit'),
      workspaceId: workspaceId,
      fieldKey: 'purchaseUnit',
      value: fields.text('purchaseUnit'),
      label: l10n.itemGroupPurchaseUnit,
      none: l10n.masterDataNoUnit,
      onChanged: (code) => edit(() {
        fields['purchaseUnit'].text = code;
        touched();
      }),
    ),
    const FormGap(),
    AppTextField(key: const ValueKey('item-group-factor'), controller: fields['purchaseFactor'], fieldKey: 'purchaseFactor', label: l10n.itemGroupPurchaseFactor, onChanged: (_) => touched()),
    const FormGap(),
  ];

  /// The sale block's fields.
  List<Widget> saleWidgets(AppLocalizations l10n, void Function(void Function()) edit, VoidCallback touched) => [
    StockUnitPicker(
      key: const ValueKey('item-group-sale-unit'),
      workspaceId: workspaceId,
      fieldKey: 'saleUnit',
      value: fields.text('saleUnit'),
      label: l10n.itemGroupSaleUnit,
      none: l10n.masterDataNoUnit,
      onChanged: (code) => edit(() {
        fields['saleUnit'].text = code;
        touched();
      }),
    ),
    const FormGap(),
    AppTextField(key: const ValueKey('item-group-sale-factor'), controller: fields['saleFactor'], fieldKey: 'saleFactor', label: l10n.itemGroupSaleFactor, onChanged: (_) => touched()),
    const FormGap(),
    AppAmountField(
      key: const ValueKey('item-group-sale-price'),
      controller: fields['salePrice'],
      fieldKey: 'salePrice',
      label: l10n.itemGroupSalePrice,
      helper: l10n.stockEditUnitPriceHelp,
      currency: format.currencyCode,
      allowNegative: false,
      onChanged: (_) => touched(),
    ),
    const FormGap(),
  ];
}

/// The label of a unit proposal of a group, or null when [param] is none.
String? groupUnitParamLabel(AppLocalizations l10n, String param) => switch (param) {
  groupParamPurchaseUnit => l10n.itemGroupPurchaseUnit,
  groupParamPurchaseFactorNum || groupParamPurchaseFactorDen => l10n.itemGroupPurchaseFactor,
  groupParamSaleUnit => l10n.itemGroupSaleUnit,
  groupParamSaleFactorNum || groupParamSaleFactorDen => l10n.itemGroupSaleFactor,
  groupParamSalePrice => l10n.itemGroupSalePrice,
  _ => null,
};
