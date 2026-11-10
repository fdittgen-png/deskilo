// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3545 step B -- the four steps of getting started, derived from facts the
// app already holds (no stored flag): the account exists, a place was joined
// or asked for, a booking was ever made, the profile has a name and a photo.
// A fact still being read, or whose source failed, is `null`: the step is not
// shown as done, and nothing is claimed about it.

/// The steps, in the order they are done.
enum StartedStep { account, space, booking, profile }

/// How a step is drawn: finished, the one to do now, or later.
enum StartedState { done, next, later }

/// Each step with its state: the first step not done is the next one.
List<({StartedStep step, StartedState state})> startedRows(
  Map<StartedStep, bool?> facts,
) {
  var nextTaken = false;
  return [
    for (final step in StartedStep.values)
      (
        step: step,
        state: facts[step] == true
            ? StartedState.done
            : nextTaken
            ? StartedState.later
            : () {
                nextTaken = true;
                return StartedState.next;
              }(),
      ),
  ];
}

/// Every step is done: the card is shown no more.
bool startedComplete(Map<StartedStep, bool?> facts) =>
    StartedStep.values.every((s) => facts[s] == true);
