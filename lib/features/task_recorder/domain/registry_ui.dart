// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2142 — the generic layer: what the recorder notes on ANY screen, the
// ones with no seam of their own included. A screen's own seam stays the
// precise layer and wins where both would speak.
//
//   * a screen opened, named by its route PATTERN (never an id or query)
//     and, when it is one of the app's own words, its title;
//   * a tap, named by the control's string key (a literal of the source,
//     or its pattern with the dynamic parts as `{}`) and, when it is one
//     of the app's own words, its label — stored as the message key and
//     shown back in the reader's language;
//   * a field left, named the same way, never its value;
//   * a guarded command, named by its runGuarded message, attempt first
//     and its real result after;
//   * a window (dialog, sheet) opened and closed.
//
// The names come from ui_vocabulary.g.dart (tool/recorder_vocabulary.dart).
// Anything outside it is a visible gap ("an unnamed control"), never raw
// text; and an older reader drops a name it does not know rather than
// refusing the file (soft targets and values).
part of 'action_registry.dart';

/// A tapped control with no listed key.
const String uiUnkeyed = 'unkeyed';

const List<ActionSpec> _uiActions = [
  ActionSpec(
    RecorderActions.uiOpenScreen,
    surface: RecorderSurfaces.anyScreen,
    kind: ActionKind.navigate,
    targets: uiRoutes,
    payloadFields: {'label', 'me_tab'},
    softTargets: true,
  ),
  ActionSpec(
    RecorderActions.uiTap,
    surface: RecorderSurfaces.anyScreen,
    kind: ActionKind.select,
    targets: {...uiKeys, ...uiKeyPatterns, uiUnkeyed},
    payloadFields: {'label'},
    softTargets: true,
  ),
  ActionSpec(
    RecorderActions.uiCommitField,
    surface: RecorderSurfaces.anyScreen,
    kind: ActionKind.fieldCommit,
    targets: {...uiKeys, ...uiKeyPatterns, uiUnkeyed},
    payloadFields: {'label'},
    softTargets: true,
  ),
  ActionSpec(
    RecorderActions.uiCommand,
    surface: RecorderSurfaces.anyScreen,
    kind: ActionKind.submit,
    targets: uiCommandMessages,
    softTargets: true,
    outcomes: {
      RecorderOutcomes.commandDone,
      RecorderOutcomes.commandPending,
      RecorderOutcomes.commandRefused,
      RecorderOutcomes.commandUnknown,
    },
  ),
  ActionSpec(
    RecorderActions.uiOpenWindow,
    surface: RecorderSurfaces.anyScreen,
    kind: ActionKind.open,
  ),
  ActionSpec(
    RecorderActions.uiCloseWindow,
    surface: RecorderSurfaces.anyScreen,
    kind: ActionKind.cancel,
  ),
];

const List<OutcomeSpec> _uiOutcomes = [
  OutcomeSpec(RecorderOutcomes.commandDone, state: ObservationState.confirmed),
  OutcomeSpec(RecorderOutcomes.commandPending, state: ObservationState.pending),
  OutcomeSpec(
    RecorderOutcomes.commandRefused,
    state: ObservationState.refused,
    payloadFields: {'refusal'},
  ),
  OutcomeSpec(
    RecorderOutcomes.commandUnknown,
    state: ObservationState.outcomeUnknown,
  ),
];
