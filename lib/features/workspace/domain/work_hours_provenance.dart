// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1307 S4 — where the working day came from (`work_hours_provenance`,
// 0244): the product's defaults, a template, or this workspace.
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
    final template = json['template'] as Map?;
    final values = template?['values'] as Map?;
    return WorkHoursProvenance(
      origin: WorkHoursOrigin.fromWire(json['state'] as String?),
      templateName: template?['name'] as String?,
      templateHours: values == null
          ? null
          : WorkHours.fromRules(Map<String, dynamic>.from(values)),
    );
  }
}
