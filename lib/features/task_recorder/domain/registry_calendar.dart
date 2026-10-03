// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1881 B — the calendar's part of the registry: the hub (agenda, week,
// month) and the classic month calendar share one surface, so a guide
// written on one reads on the other where the step exists on both.
//
// What a step keeps: which view, which way the dates moved, how far the
// chosen day is from today, which KIND of entry was filtered or opened,
// and whose calendar it is as mine / someone else's / everyone's — never
// a member, an entry, a name or a date. Opening a reservation is not a
// calendar step: the reservation's own sheet records it (one action, one
// step, wherever it was opened from).
part of 'action_registry.dart';

/// The calendar's entry kinds, by their wire names (CalendarKind.wire);
/// pinned to the enum by test/features/task_recorder/calendar_journey_test.
const Set<String> calendarKindKeys = {
  'reservation',
  'checkin',
  'checkout',
  'event',
  'message',
  'invoice',
  'payment',
  'consumption',
  'reminder',
  'due',
  'scheduled',
  'validation',
};

/// The filter's own target for "every kind".
const String calendarAllKinds = 'all';

const List<ActionSpec> _calendarActions = [
  ActionSpec(
    RecorderActions.calendarSwitchView,
    surface: RecorderSurfaces.calendar,
    kind: ActionKind.select,
    payloadFields: {'view_mode'},
  ),
  ActionSpec(
    RecorderActions.calendarMove,
    surface: RecorderSurfaces.calendar,
    kind: ActionKind.select,
    payloadFields: {'direction'},
  ),
  ActionSpec(
    RecorderActions.calendarSelectDay,
    surface: RecorderSurfaces.calendar,
    kind: ActionKind.select,
    payloadFields: {'date_relation'},
  ),
  ActionSpec(
    RecorderActions.calendarFilterKind,
    surface: RecorderSurfaces.calendar,
    kind: ActionKind.select,
    targets: {...calendarKindKeys, calendarAllKinds},
    payloadFields: {'switch_to'},
  ),
  ActionSpec(
    RecorderActions.calendarChooseWhose,
    surface: RecorderSurfaces.calendar,
    kind: ActionKind.select,
    payloadFields: {'calendar_of'},
  ),
  ActionSpec(
    RecorderActions.calendarOpenItem,
    surface: RecorderSurfaces.calendar,
    kind: ActionKind.open,
    payloadFields: {'item_kind'},
  ),
  ActionSpec(
    RecorderActions.calendarCancelReservation,
    surface: RecorderSurfaces.calendar,
    kind: ActionKind.submit,
    payloadFields: {'repeat'},
    outcomes: {
      RecorderOutcomes.cancelled,
      RecorderOutcomes.reservationRefused,
      RecorderOutcomes.reservationUnknown,
    },
  ),
  ActionSpec(
    RecorderActions.decideEvent,
    surface: RecorderSurfaces.eventDecisions,
    kind: ActionKind.submit,
    payloadFields: {'decision'},
    outcomes: {
      RecorderOutcomes.eventDecided,
      RecorderOutcomes.eventNotConfirmed,
    },
  ),
];

const List<OutcomeSpec> _calendarOutcomes = [
  OutcomeSpec(RecorderOutcomes.eventDecided, state: ObservationState.confirmed),
  // The decide path reports a failure as text only, so the recorder
  // cannot tell a refusal from a lost answer: it claims neither.
  OutcomeSpec(
    RecorderOutcomes.eventNotConfirmed,
    state: ObservationState.outcomeUnknown,
  ),
];
