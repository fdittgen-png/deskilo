// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2394 — the eligibility review screen's state: whether a decision or a
// save is in flight, how the last decision ended, and the disclosure
// maximum being edited. The screen reads this and calls the transitions.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/mcp_admin.dart';

part 'eligibility_review_form_provider.g.dart';

class EligibilityReviewFormState {
  const EligibilityReviewFormState({
    this.busy = false,
    this.outcome,
    this.maximum,
    this.maximumOutcome,
  });

  final bool busy;

  /// The last decision's status name; null before one.
  final String? outcome;

  /// #1809 — the maximum being edited; null until the server's is read.
  final Set<String>? maximum;

  /// `saved` or `refused`, after a save of the maximum.
  final String? maximumOutcome;
}

@riverpod
class EligibilityReviewForm extends _$EligibilityReviewForm {
  @override
  EligibilityReviewFormState build() => const EligibilityReviewFormState();

  void _set({
    bool? busy,
    String? Function()? outcome,
    Set<String>? Function()? maximum,
    String? maximumOutcome,
  }) => state = EligibilityReviewFormState(
    busy: busy ?? state.busy,
    outcome: outcome == null ? state.outcome : outcome(),
    maximum: maximum == null ? state.maximum : maximum(),
    maximumOutcome: maximumOutcome ?? state.maximumOutcome,
  );

  /// Marks a request as running; false when one already is.
  bool begin() {
    if (state.busy) return false;
    _set(busy: true);
    return true;
  }

  /// Ends the running request without changing what the page says.
  void release() => _set(busy: false);

  /// Ends a decision; [outcome] is its status name, null when it failed.
  void decided(String? outcome) => _set(busy: false, outcome: () => outcome);

  /// Ends a save of the maximum: a saved one starts again from the server's.
  void maximumSaved({required bool saved}) => _set(
    busy: false,
    maximumOutcome: saved ? 'saved' : 'refused',
    maximum: saved ? () => null : null,
  );

  /// The maximum being edited: the first edit starts from [read].
  Set<String> maximumFor(McpDisclosureMaximum read) =>
      state.maximum ?? {...read.fields};

  void toggleMaximumField(
    McpDisclosureMaximum read,
    String field, {
    required bool on,
  }) {
    final next = {...maximumFor(read)};
    on ? next.add(field) : next.remove(field);
    _set(maximum: () => next);
  }
}
