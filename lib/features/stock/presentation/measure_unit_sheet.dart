// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4442 -- the form of one unit of measure: a new unit (its code, name, what it measures, its factor to the base unit, its
// UN/ECE code) or an existing one. A built-in unit takes only a word of the business's own and a UN/ECE code; a unit that is
// in use keeps its dimension and factor, which the server refuses to change (told in words, nothing is kept). The factor is
// typed as the member writes a number and sent as the exact fraction; the rules of the fields are pure
// (`measureUnitProblems`).
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
import '../../../core/ui/master_data_field.dart';
import '../domain/measure_unit_form.dart';
import '../domain/stock_config.dart';
import '../domain/unece_unit_codes.dart';
import '../domain/workspace_units.dart';
import 'measure_unit_text.dart';
import 'stock_config_text.dart';

/// The UN/ECE codes the form offers (#4479): the Recommendation 20 / 21 list.
final _eceOptions = [for (final e in uneceUnitCodes.entries) MasterDataOption(code: e.key, name: e.value)];

/// Opens the form of [unit] (null: a new unit) over the business's [all] units. [onDone] runs once it is saved.
Future<void> showMeasureUnitSheet(
  BuildContext context,
  WorkspaceUnits port, {
  required String workspaceId,
  required List<WorkspaceUnit> all,
  required Future<void> Function() onDone,
  WorkspaceUnit? unit,
}) {
  final l10n = context.l10n;
  final locale = appFormatOf(context).locale;
  final isNew = unit == null;
  final fixed = unit?.builtIn ?? false;
  final storedEce = unit?.unEceCode ?? '';
  final fields = FormControllers({
    'code': unit?.code ?? '',
    'name': unit?.label ?? '',
    'factor': unit == null ? '' : factorText(unit).replaceAll('.', decimalSeparatorOf(locale)),
    'ece': storedEce,
  });
  final requestId = newRequestId();
  var dimension = unit?.dimension;
  ExactQuantity? factor() => exactQuantityFromInput(fields['factor'].text, locale: locale).value;
  Set<MeasureUnitField> problems() => measureUnitProblems(
    MeasureUnitInput(
      isNew: isNew,
      fixed: fixed,
      code: fields['code'].text,
      name: fields['name'].text,
      dimension: dimension,
      factor: factor(),
      unEceCode: fields['ece'].text,
      storedUnEceCode: storedEce,
    ),
  );
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: isNew ? l10n.measureUnitNew : l10n.measureUnitEdit,
      submitLabel: l10n.commonSave,
      submitKey: const ValueKey('measure-unit-save'),
      onDispose: fields.dispose,
      validate: () => {for (final p in problems()) p.name: measureUnitProblemText(l10n, p)},
      onSubmit: () async {
        final exact = factor();
        final fraction = exact == null ? null : factorOfQuantity(exact);
        try {
          await port.save(
            workspaceId,
            requestId: requestId,
            draft: MeasureUnitDraft(
              code: fields['code'].text.trim(),
              label: fields['name'].text.trim().isEmpty ? null : fields['name'].text.trim(),
              clearLabel: !isNew && fields['name'].text.trim().isEmpty && unit.label != null,
              dimension: isNew ? dimension : null,
              factorNum: fixed ? null : fraction?.num,
              factorDen: fixed ? null : fraction?.den,
              unEceCode: fields['ece'].text.trim().isEmpty ? null : fields['ece'].text.trim(),
            ),
          );
          await onDone();
          return null;
        } on StockConfigRefused catch (e, stack) {
          TraceLogger.instance.warn('stock', 'a unit was refused: ${e.field}: ${e.reason}', error: e, stackTrace: stack);
          return stockRefusalText(l10n, e.reason, subject: StockSubject.measureUnit);
        }
      },
      builder: (context, refresh) => [
        if (isNew) ...[
          AppTextField(
            key: const ValueKey('measure-unit-code'),
            controller: fields['code'],
            fieldKey: MeasureUnitField.code.name,
            label: l10n.measureUnitCodeField,
            helper: l10n.measureUnitCodeHelp,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]'))],
          ),
          const FormGap(),
        ],
        AppTextField(
          key: const ValueKey('measure-unit-name'),
          controller: fields['name'],
          fieldKey: MeasureUnitField.name.name,
          label: l10n.measureUnitNameField,
        ),
        const FormGap(),
        if (isNew)
          // the sheet's builder runs above the form's error scope: the dropdown reads it from inside
          Builder(
            builder: (scope) => AppDropdownField<UnitDimension>(
              key: const ValueKey('measure-unit-dimension'),
              label: l10n.measureUnitDimensionField,
              value: dimension,
              error: FormErrorsScope.maybeOf(scope)?.errors[MeasureUnitField.dimension.name],
              items: [for (final d in UnitDimension.values) (d, measureDimensionText(l10n, d))],
              onChanged: (v) {
                dimension = v;
                FormErrorsScope.maybeOf(scope)?.onEdit(MeasureUnitField.dimension.name);
                refresh();
              },
            ),
          )
        else
          Text(measureDimensionText(l10n, unit.dimension), key: const ValueKey('measure-unit-dimension-fixed')),
        const FormGap(),
        AppTextField(
          key: const ValueKey('measure-unit-factor'),
          controller: fields['factor'],
          fieldKey: MeasureUnitField.factor.name,
          label: l10n.measureUnitFactorField,
          helper: dimension == null ? null : l10n.measureUnitFactorHelp(measureUnitName(l10n, baseUnitOf(all, dimension!) ?? unit ?? all.first)),
          enabled: !fixed,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        ),
        const FormGap(),
        // #4479 -- the code is chosen from the Recommendation 20 / 21 list; one stored before it stays until changed
        MasterDataField(
          textKey: const ValueKey('measure-unit-ece'),
          controller: fields['ece'],
          fieldKey: MeasureUnitField.unEceCode.name,
          label: l10n.measureUnitEceField,
          options: _eceOptions,
        ),
      ],
    ),
  );
}
