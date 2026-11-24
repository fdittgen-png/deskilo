// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4442 -- the words of the units of measure: a unit's name (the business's own word, else the symbol every language shares,
// else the app's word for a piece), what a dimension is called, and the sentence under a field the app checks itself.
import '../../../l10n/app_localizations.dart';
import '../domain/measure_unit_form.dart';
import '../domain/workspace_units.dart';

/// How a unit reads: the label the business gave it, else its symbol (km, kg, m²), else the app's word for a piece.
String measureUnitName(AppLocalizations l10n, WorkspaceUnit unit) => unit.label ?? switch (unit.code) {
  'piece' => l10n.standaloneUnitPiece,
  'm2' => 'm²',
  final code => code,
};

String measureDimensionText(AppLocalizations l10n, UnitDimension d) => switch (d) {
  UnitDimension.count => l10n.measureDimensionCount,
  UnitDimension.mass => l10n.measureDimensionMass,
  UnitDimension.volume => l10n.measureDimensionVolume,
  UnitDimension.length => l10n.measureDimensionLength,
  UnitDimension.area => l10n.measureDimensionArea,
  UnitDimension.time => l10n.measureDimensionTime,
};

/// The sentence under the field a problem is on.
String measureUnitProblemText(AppLocalizations l10n, MeasureUnitField field) => switch (field) {
  MeasureUnitField.code => l10n.stockReasonCodeMalformed,
  MeasureUnitField.name => l10n.measureReasonName,
  MeasureUnitField.dimension => l10n.measureReasonDimension,
  MeasureUnitField.factor => l10n.stockReasonOutOfRange,
  MeasureUnitField.unEceCode => l10n.measureReasonEce,
};
