// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4479 -- the form of one general conversion (Settings > Units of measure): from one unit of the business to another, and how many of
// the second are in one of the first. It works both ways; writing the pair again replaces the one that was. The factor is typed as
// the member writes a number and sent as the exact fraction. A packaging unit is not offered: it converts through an item's own factor.
// The server decides what is refused and the sheet says it in words.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter/material.dart';

import '../../../core/format/decimal_input.dart';
import '../../../core/i18n/format_controller.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/dropdown_field.dart';
import '../../../core/ui/form_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/stock_config.dart';
import '../domain/unit_conversions.dart';
import '../domain/workspace_units.dart';
import 'measure_unit_text.dart';
import 'stock_config_text.dart';
import 'stock_quantity_field.dart';

const _fromField = 'from';
const _toField = 'to';
const _factorField = 'factor';

/// Opens the form of [conversion] (null: a new one) over the business's [units]. [onDone] runs once it is saved.
Future<void> showUnitConversionSheet(
  BuildContext context,
  UnitConversions port, {
  required String workspaceId,
  required List<WorkspaceUnit> units,
  required Future<void> Function() onDone,
  UnitConversion? conversion,
}) {
  final l10n = context.l10n;
  final locale = appFormatOf(context).locale;
  final offered = [
    for (final u in units)
      if (!u.archived && u.dimension != UnitDimension.package) u,
  ];
  final fields = FormControllers({
    _factorField: conversion == null ? '' : _factorText(conversion, locale),
  });
  final requestId = newRequestId();
  String? from = conversion?.fromUnit;
  String? to = conversion?.toUnit;
  ExactQuantity? factor() => exactQuantityFromInput(fields[_factorField].text, locale: locale).value;
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: conversion == null ? l10n.unitConversionNew : l10n.unitConversionEdit,
      submitLabel: l10n.commonSave,
      submitKey: const ValueKey('unit-conversion-save'),
      onDispose: fields.dispose,
      validate: () => {
        if (from == null) _fromField: l10n.stockReasonUnitUnknown,
        if (to == null) _toField: l10n.stockReasonUnitUnknown else if (to == from) _toField: l10n.stockReasonConversionSameUnit,
        if (factor() == null || factorOfQuantity(factor()!) == null) _factorField: l10n.stockReasonFactorInvalid,
      },
      onSubmit: () async {
        final fraction = factorOfQuantity(factor()!)!;
        try {
          await port.save(
            workspaceId,
            requestId: requestId,
            conversion: UnitConversion(fromUnit: from!, toUnit: to!, factorNum: fraction.num, factorDen: fraction.den),
          );
          await onDone();
          return null;
        } on StockConfigRefused catch (e, stack) {
          TraceLogger.instance.warn('stock', 'a conversion was refused: ${e.field}: ${e.reason}', error: e, stackTrace: stack);
          return stockRefusalText(l10n, e.reason, subject: StockSubject.measureUnit);
        }
      },
      builder: (context, refresh) => [
        _unitField(_fromField, l10n.unitConversionFrom, from, offered, conversion != null ? null : (v) {
          from = v;
          refresh();
        }),
        const FormGap(),
        _unitField(_toField, l10n.unitConversionTo, to, offered, conversion != null ? null : (v) {
          to = v;
          refresh();
        }),
        const FormGap(),
        StockQuantityField(
          key: const ValueKey('unit-conversion-factor'),
          controller: fields[_factorField],
          fieldKey: _factorField,
          label: l10n.unitConversionFactor,
          helper: from == null || to == null ? null : l10n.unitConversionFactorHelp(_nameOf(l10n, offered, from!), _nameOf(l10n, offered, to!)),
        ),
      ],
    ),
  );
}

/// One unit dropdown of the form: the problem under it is the sheet's, and picking clears it. A null [onPick] shows the unit, unchanged.
Widget _unitField(String errorKey, String label, String? value, List<WorkspaceUnit> offered, void Function(String)? onPick) => Builder(
  builder: (scope) => AppDropdownField<String>(
    key: ValueKey('unit-conversion-$errorKey'),
    label: label,
    value: value,
    error: FormErrorsScope.maybeOf(scope)?.errors[errorKey],
    items: [for (final u in offered) (u.code, measureUnitName(scope.l10n, u))],
    onChanged: onPick == null
        ? null
        : (v) {
            FormErrorsScope.maybeOf(scope)?.onEdit(errorKey);
            if (v != null) onPick(v);
          },
  ),
);

String _nameOf(AppLocalizations l10n, List<WorkspaceUnit> units, String code) {
  final unit = units.where((u) => u.code == code).firstOrNull;
  return unit == null ? code : measureUnitName(l10n, unit);
}

String _factorText(UnitConversion c, String locale) => conversionFactorText(c).replaceAll('.', decimalSeparatorOf(locale));
