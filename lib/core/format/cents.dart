// SPDX-License-Identifier: AGPL-3.0-or-later

// Cent-amount helpers — formerly three identical private `_money` clones
// (billing, services, accessories editors) and two inline amount parsers.
//
// #1077 — "cents" is a euro word. These read the workspace's GRAIN
// through [WorkspaceCurrency]: a yen amount has no minor unit at all, so
// hardcoding 100 stored a hundred times what the owner typed and then
// showed it back unchanged, which is why nothing looked wrong until an
// invoice went out.

import '../i18n/workspace_currency.dart';
import 'decimal_input.dart';

/// Major-unit editor display of [minor]: whole amounts without decimals
/// ('150'), fractional ones at the currency's own precision ('12.50').
/// NOT a currency rendering — screens showing money to members use
/// `AppFormat.formatMinor`.
String centsToMajor(int minor) {
  final per = WorkspaceCurrency.minorPerMajor;
  if (per == 1 || minor % per == 0) return '${minor ~/ per}';
  return (minor / per).toStringAsFixed(WorkspaceCurrency.minorDigits);
}

/// #3487 — a user-typed major-unit amount ('12', '12.5', '12,50',
/// '1.234,56', '1 234,56') in the currency's minor units, read by the one
/// decimal input parser in the member's format locale. Empty input reads as
/// 0 (editors treat blank as free); malformed or negative input returns
/// null.
int? parseMinorInput(String raw, {String? locale}) {
  if (raw.trim().isEmpty) return 0;
  final value = parseDecimalInput(
    raw,
    locale: locale,
    allowNegative: false,
    threeDecimals: WorkspaceCurrency.minorDigits >= 3,
  );
  if (value == null) return null;
  return (value * WorkspaceCurrency.minorPerMajor).round();
}
