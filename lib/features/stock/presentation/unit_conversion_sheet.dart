// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4479 -- the form of one general conversion (Settings > Units of measure): from one unit of the business to another, and how many of
// the second are in one of the first. It works both ways; writing the pair again replaces the one that was. The factor is typed as
// the member writes a number and sent as the exact fraction. A packaging unit is not offered: it converts through an item's own factor.
// The server decides what is refused and the sheet says it in words.
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
import '../domain/stock_config.dart';
import '../domain/unit_conversions.dart';
import '../domain/workspace_units.dart';
import 'measure_unit_text.dart';
import 'stock_config_text.dart';

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
    'factor': conversion == null ? '' : _factorText(conversion, locale),
  });
  final requestId = newRequestId();
  String? from = conversion?.fromUnit;
  String? to = conversion?.toUnit;
  ExactQuantity? factor() => exactQuantityFromInput(fields['factor'].text, locale: locale).value;
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: conversion == null ? l10n.unitConversionNew : l10n.unitConversionEdit,
      submitLabel: l10n.commonSave,
      submitKey: const ValueKey('unit-conversion-save'),
      onDispose: fields.dispose,
      validate: () => {
        if (from == null) 'from_unit': l10n.stockReasonUnitUnknown,
        if (to == null) 'to_unit': l10n.stockReasonUnitUnknown else if (to == from) 'to_unit': l10n.stockReasonConversionSameUnit,
        if (factor() == null || factorOfQuantity(factor()!) == null) 'factor': l10n.stockReasonFactorInvalid,
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
        // the sheet's builder runs above the form's error scope: the dropdowns read it from inside
        Builder(
          builder: (scope) => AppDropdownField<String>(
            key: const ValueKey('unit-conversion-from'),
            label: l10n.unitConversionFrom,
            value: from,
            error: FormErrorsScope.maybeOf(scope)?.errors['from_unit'],
            items: [for (final u in offered) (u.code, measureUnitName(l10n, u))],
            onChanged: conversion != null
                ? null
                : (v) {
                    from = v;
                    FormErrorsScope.maybeOf(scope)?.onEdit('from_unit');
                    refresh();
                  },
          ),
        ),
        const FormGap(),
        Builder(
          builder: (scope) => AppDropdownField<String>(
            key: const ValueKey('unit-conversion-to'),
            label: l10n.unitConversionTo,
            value: to,
            error: FormErrorsScope.maybeOf(scope)?.errors['to_unit'],
            items: [for (final u in offered) (u.code, measureUnitName(l10n, u))],
            onChanged: conversion != null
                ? null
                : (v) {
                    to = v;
                    FormErrorsScope.maybeOf(scope)?.onEdit('to_unit');
                    refresh();
                  },
          ),
        ),
        const FormGap(),
        AppTextField(
          key: const ValueKey('unit-conversion-factor'),
          controller: fields['factor'],
          fieldKey: 'factor',
          label: l10n.unitConversionFactor,
          helper: from == null || to == null ? null : l10n.unitConversionFactorHelp(_nameOf(l10n, offered, from!), _nameOf(l10n, offered, to!)),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        ),
      ],
    ),
  );
}

String _nameOf(AppLocalizations l10n, List<WorkspaceUnit> units, String code) {
  final unit = units.where((u) => u.code == code).firstOrNull;
  return unit == null ? code : measureUnitName(l10n, unit);
}

String _factorText(UnitConversion c, String locale) => conversionFactorText(c).replaceAll('.', decimalSeparatorOf(locale));
