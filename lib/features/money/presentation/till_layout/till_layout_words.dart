// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4448 -- the words of the layout editor: what each widget, function, step, template and size is called.
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/till_layout.dart';
import '../../domain/till_layout_edits.dart';
import '../../domain/till_layout_templates.dart';

String tillWidgetName(AppLocalizations l10n, TillWidgetKind kind) => switch (kind) {
  TillWidgetKind.itemKey => l10n.tillLayoutKindItem,
  TillWidgetKind.categoryKey => l10n.tillLayoutKindCategory,
  TillWidgetKind.functionKey => l10n.tillLayoutKindFunction,
  TillWidgetKind.keypad => l10n.tillLayoutKindKeypad,
  TillWidgetKind.calculator => l10n.tillLayoutKindCalculator,
  TillWidgetKind.scanField => l10n.tillScanLabel,
  TillWidgetKind.basket => l10n.tillBasketTitle,
  TillWidgetKind.totalDisplay => l10n.tillLayoutKindTotal,
  TillWidgetKind.customerNote => l10n.tillLayoutKindCustomer,
  TillWidgetKind.studioPasses => l10n.tillLayoutKindPasses,
  TillWidgetKind.cashNotes => l10n.tillLayoutKindCashNotes,
  TillWidgetKind.unknown => l10n.tillLayoutKindUnknown,
};

String tillFunctionName(AppLocalizations l10n, TillFunction f) => switch (f) {
  TillFunction.payCash => l10n.tillPayCash,
  TillFunction.payCard => l10n.tillLayoutFnCard,
  TillFunction.nextCustomer => l10n.tillNextCustomer,
  TillFunction.voidLine => l10n.tillLayoutFnVoid,
  TillFunction.lineDiscount => l10n.tillLayoutFnDiscount,
  TillFunction.quantityTimes => l10n.tillLayoutFnQuantity,
  TillFunction.priceOverride => l10n.tillLayoutFnPrice,
  TillFunction.depositReturn => l10n.tillLayoutFnDeposit,
  TillFunction.openDrawer => l10n.tillLayoutFnDrawer,
  TillFunction.reprintLast => l10n.tillLayoutFnReprint,
  TillFunction.unknown => l10n.tillLayoutKindUnknown,
};

String tillTemplateName(AppLocalizations l10n, TillLayoutTemplate t) => switch (t) {
  TillLayoutTemplate.retail => l10n.tillLayoutTemplateRetail,
  TillLayoutTemplate.bakery => l10n.tillLayoutTemplateBakery,
  TillLayoutTemplate.cafe => l10n.tillLayoutTemplateCafe,
  TillLayoutTemplate.studio => l10n.tillLayoutTemplateStudio,
  TillLayoutTemplate.hardware => l10n.tillLayoutTemplateHardware,
};

String tillTemplatePageName(AppLocalizations l10n, TillTemplatePage p) => switch (p) {
  TillTemplatePage.sale => l10n.tillLayoutPageSale,
  TillTemplatePage.drinks => l10n.tillLayoutPageDrinks,
  TillTemplatePage.food => l10n.tillLayoutPageFood,
  TillTemplatePage.desk => l10n.tillLayoutPageDesk,
};

String tillSizeName(AppLocalizations l10n, TillLayoutSize s) => switch (s) {
  TillLayoutSize.phone => l10n.tillLayoutSizePhone,
  TillLayoutSize.tablet => l10n.tillLayoutSizeTablet,
  TillLayoutSize.desk => l10n.tillLayoutSizeDesk,
};

/// Each step's words and icon, in the order the toolbar shows them.
List<(TillCellStep, String, IconData)> tillSteps(AppLocalizations l10n) => [
  (TillCellStep.left, l10n.tillLayoutStepLeft, Icons.arrow_back),
  (TillCellStep.right, l10n.tillLayoutStepRight, Icons.arrow_forward),
  (TillCellStep.up, l10n.tillLayoutStepUp, Icons.arrow_upward),
  (TillCellStep.down, l10n.tillLayoutStepDown, Icons.arrow_downward),
  (TillCellStep.wider, l10n.tillLayoutStepWider, Icons.unfold_more_double),
  (TillCellStep.narrower, l10n.tillLayoutStepNarrower, Icons.unfold_less_double),
  (TillCellStep.taller, l10n.tillLayoutStepTaller, Icons.expand),
  (TillCellStep.shorter, l10n.tillLayoutStepShorter, Icons.compress),
];
