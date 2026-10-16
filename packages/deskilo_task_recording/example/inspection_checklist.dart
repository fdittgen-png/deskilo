// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A neutral host: an equipment-inspection checklist. It supplies its own
// catalogue and payload vocabulary; the core knows nothing else.

import 'package:deskilo_task_recording/deskilo_task_recording.dart';

abstract final class Inspection {
  static const screen = 'inspection.checklist';
  static const check = 'inspection.check_item';
  static const submit = 'inspection.submit_report';
  static const reportFiled = 'inspection.report_filed';
  static const reportRefused = 'inspection.report_refused';
}

const Map<String, SafeField> inspectionFields = {
  'verdict': SafeField('verdict', {'pass', 'fail'}),
};

ActionRegistry inspectionCatalogue({int contractVersion = 1}) => ActionRegistry(
  contractVersion: contractVersion,
  surfaces: const [RecorderSurface(Inspection.screen)],
  actions: const [
    ActionSpec(
      Inspection.check,
      surface: Inspection.screen,
      kind: ActionKind.select,
      payloadFields: {'verdict'},
    ),
    ActionSpec(
      Inspection.submit,
      surface: Inspection.screen,
      kind: ActionKind.submit,
      outcomes: {Inspection.reportFiled, Inspection.reportRefused},
    ),
  ],
  outcomes: const [
    OutcomeSpec(Inspection.reportFiled, state: ObservationState.confirmed),
    OutcomeSpec(Inspection.reportRefused, state: ObservationState.refused),
  ],
  prerequisites: const [],
  safeFields: inspectionFields,
  acceptsPage: (page) => page == '/inspections',
);
