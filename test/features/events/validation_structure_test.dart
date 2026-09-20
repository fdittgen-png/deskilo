// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1221 — the validation rules, read as the process they interrupt.
//
// The screen was twenty-four cards in one hand-ordered column, each
// saying "2 required · All admins · Owner must always validate" — three
// true facts in a row, none of which says what HAPPENS, in what order,
// or what is waiting meanwhile. Finding the rule that was holding
// something up meant already knowing which event type that thing
// emitted.
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/events/presentation/validation_workflow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'validation_settings_screen_test.dart' show pumpValidationSettings;

void main() {
  test('every event type belongs to a workflow, and each workflow is used',
      () {
    final used = {for (final t in EventType.values) workflowOf(t)};
    expect(used, ValidationWorkflow.values.toSet(),
        reason: 'a workflow with no rules in it is a heading over nothing');
  });

  testWidgets('the rules are grouped by the process they interrupt',
      (tester) async {
    await pumpValidationSettings(tester);

    for (final workflow in ValidationWorkflow.values) {
      expect(
        find.byKey(ValueKey('validation-workflow-${workflow.name}')),
        findsOneWidget,
        reason: workflow.name,
      );
    }
  });

  testWidgets('each heading says what is at stake while a rule waits',
      (tester) async {
    await pumpValidationSettings(tester);
    expect(
      find.text('Until it is accepted, the seat stays as it was.'),
      findsOneWidget,
      reason: 'the half of the answer the old summary never gave',
    );
  });

  testWidgets('a rule reads as three steps, and names the self-validation '
      'state on the first', (tester) async {
    await pumpValidationSettings(tester);
    // Who asks — and that it is never themselves, which is the
    // invariant every rule sits on.
    expect(find.text('Someone asks · Never your own'), findsWidgets);
    // Who decides, and how many.
    expect(find.text('All admins — any 1'), findsWidgets);
    // What happens then.
    expect(find.text('it takes effect'), findsWidgets);
  });
}
