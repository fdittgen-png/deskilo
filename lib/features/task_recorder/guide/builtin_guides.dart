// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1867 — the guides that ship with the app.
//
// A built-in guide is an ordinary reviewed guide (task_guide.dart): the
// same declarative steps, the same runner, the same host. It is written
// in the reader's language when it starts, so its words are the app's
// own messages. The first one is booking a place — the task the recorder
// was first instrumented for — with its refusal path.

import '../../../l10n/app_localizations.dart';
import '../domain/action_registry.dart';
import 'guide_compiler.dart';
import 'task_guide.dart';

/// The built-in guides, by id.
enum BuiltinGuide { bookAPlace }

String builtinGuideTitle(AppLocalizations? l10n, BuiltinGuide g) => switch (g) {
  BuiltinGuide.bookAPlace => l10n?.guideBuiltinBooking ?? 'Book a place',
};

TaskGuide builtinGuide(AppLocalizations? l10n, BuiltinGuide g) => switch (g) {
  BuiltinGuide.bookAPlace => _bookAPlace(l10n),
};

TaskGuide _bookAPlace(AppLocalizations? l10n) {
  final confirm = recorderRegistry.action(RecorderActions.confirmBooking)!;
  return TaskGuide(
    actionContractVersion: actionContractVersion,
    title: builtinGuideTitle(l10n, BuiltinGuide.bookAPlace),
    steps: [
      GuideStep(
        id: 'g1',
        destination: '/reserve',
        kind: GuideStepKind.instruction,
        text:
            l10n?.guideBuiltinBookingIntro ??
            'This guide shows how to book a place: choose the day and the '
                'period, pick a place, then confirm. Nothing is booked until '
                'you confirm.',
      ),
      // Already on Reserve, or today is the day: these may be skipped.
      const GuideStep(
        id: 'g2',
        kind: GuideStepKind.perform,
        action: RecorderActions.openReserve,
        optional: true,
      ),
      const GuideStep(
        id: 'g3',
        kind: GuideStepKind.perform,
        action: RecorderActions.selectDate,
        optional: true,
      ),
      const GuideStep(
        id: 'g4',
        kind: GuideStepKind.perform,
        action: RecorderActions.selectPeriod,
        optional: true,
      ),
      const GuideStep(
        id: 'g5',
        kind: GuideStepKind.perform,
        action: RecorderActions.selectResource,
      ),
      GuideStep(
        id: 'g6',
        kind: GuideStepKind.perform,
        action: RecorderActions.confirmBooking,
        expectedOutcomes: successOutcomes(confirm),
        recovery: [
          GuideStep(
            id: 'g6r1',
            kind: GuideStepKind.instruction,
            text:
                l10n?.guideBookingRefusedRecovery ??
                'The booking was refused (the place is taken or a rule '
                    'forbids it). Choose another place or period, then '
                    'confirm again.',
          ),
        ],
      ),
    ],
  );
}
