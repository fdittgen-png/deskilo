// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1307 S4 — where the working day came from (`work_hours_provenance`,
// 0244): the product's defaults, a template, or this workspace.
import '../../../core/data/json_reader.dart';
import '../../../core/time/work_hours.dart';

enum WorkHoursOrigin {
  productDefault,
  template,
  workspace;

  static WorkHoursOrigin fromWire(String? raw) => switch (raw) {
        'template' => template,
        'workspace' => workspace,
        _ => productDefault,
      };
}

class WorkHoursProvenance {
  const WorkHoursProvenance({
    required this.origin,
    this.templateName,
    this.templateHours,
  });

  static const WorkHoursProvenance productDefault =
      WorkHoursProvenance(origin: WorkHoursOrigin.productDefault);

  final WorkHoursOrigin origin;

  /// The latest template application that carried the working day, when
  /// there is one — whether or not the values still match it.
  final String? templateName;
  final WorkHours? templateHours;

  /// "Reset to template" is offered when a template delivered hours and the
  /// workspace no longer holds exactly them.
  bool get canResetToTemplate =>
      templateHours != null && origin != WorkHoursOrigin.template;

  /// "Reset to product default" is offered whenever some value is set.
  bool get canResetToDefault => origin != WorkHoursOrigin.productDefault;

  factory WorkHoursProvenance.fromJson(Map<String, dynamic> json) {
    final r = JsonReader(json, context: 'work_hours_provenance');
    final template = r.objectOrNull('template');
    final values = template?.objectOrNull('values');
    return WorkHoursProvenance(
      origin: WorkHoursOrigin.fromWire(r.stringOrNull('state')),
      templateName: template?.stringOrNull('name'),
      templateHours: values == null ? null : WorkHours.fromRules(values.json),
    );
  }
}
