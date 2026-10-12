// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2394 — the policy screen's form state: the draft being edited, the
// policy it started from, whether a save is in flight and how the last one
// ended. The screen keeps nothing of it; it reads this and calls the
// transitions below.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/mcp_policy_editor.dart';
import '../domain/mcp_admin.dart';

part 'mcp_policy_form_provider.g.dart';

class McpPolicyFormState {
  const McpPolicyFormState({
    this.draft,
    this.base,
    this.busy = false,
    this.outcome,
  });

  /// Null until the first edit or save: the screen then shows the policy.
  final McpPolicyDraft? draft;
  final McpPolicy? base;
  final bool busy;

  /// The last save's status name, shown as a banner.
  final String? outcome;

  McpPolicyFormState _with({
    McpPolicyDraft? draft,
    McpPolicy? base,
    bool? busy,
    String? outcome,
    bool restart = false,
  }) => McpPolicyFormState(
    draft: restart ? null : draft ?? this.draft,
    base: restart ? null : base ?? this.base,
    busy: busy ?? this.busy,
    outcome: outcome ?? this.outcome,
  );
}

@riverpod
class McpPolicyForm extends _$McpPolicyForm {
  @override
  McpPolicyFormState build() => const McpPolicyFormState();

  /// The draft being edited, or a fresh one over [policy] to show.
  McpPolicyDraft draftFor(McpPolicy policy) =>
      state.draft ?? McpPolicyDraft.from(policy);

  /// Applies [change] to the draft (started from [policy] on the first
  /// edit) and tells the screen.
  void edit(McpPolicy policy, void Function(McpPolicyDraft draft) change) {
    final draft = draftFor(policy);
    change(draft);
    state = state._with(draft: draft, base: state.base ?? policy);
  }

  /// Starts a save of the draft over [policy]; null when one is running.
  McpPolicyDraft? beginSave(McpPolicy policy) {
    if (state.busy) return null;
    final draft = draftFor(policy);
    state = state._with(draft: draft, base: state.base ?? policy, busy: true);
    return draft;
  }

  /// Ends a save. A save that happened, or a conflict to review, starts
  /// again from what the server holds now; a transient failure ([result]
  /// null) keeps the draft.
  void endSave(PolicySaveResult? result) {
    state = state._with(
      busy: false,
      outcome: result?.status.name,
      restart: result != null,
    );
  }
}
