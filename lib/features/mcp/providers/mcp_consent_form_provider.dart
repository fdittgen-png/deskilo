// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2394 — the consent screen's form state: what the person ticked (the
// operations per workspace, and the optional fields per workspace), whether
// an approval or refusal is in flight, and how the last one ended. The
// screen reads this and calls the transitions below.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/mcp_connection.dart';
import '../presentation/mcp_consent_refusal.dart';

part 'mcp_consent_form_provider.g.dart';

class McpConsentFormState {
  const McpConsentFormState({
    this.chosen = const {},
    this.fields = const {},
    this.busy = false,
    this.outcome,
    this.refusal,
    this.failed = false,
  });

  /// Workspace id → the operations chosen there; absent = not chosen.
  final Map<String, Set<String>> chosen;

  /// #1809 — workspace id → the optional fields consented there; only
  /// ever the ones that workspace offers, and none unless ticked.
  final Map<String, Set<String>> fields;
  final bool busy;
  final String? outcome;

  /// #2145 — why the last approval was refused, when the server said; a
  /// refusal it did not explain is [failed].
  final McpConsentRefusal? refusal;
  final bool failed;

  bool get anyChosen => chosen.values.any((ops) => ops.isNotEmpty);

  McpConsentFormState _with({
    Map<String, Set<String>>? chosen,
    Map<String, Set<String>>? fields,
    bool? busy,
  }) => McpConsentFormState(
    chosen: chosen ?? this.chosen,
    fields: fields ?? this.fields,
    busy: busy ?? this.busy,
    outcome: outcome,
    refusal: refusal,
    failed: failed,
  );
}

@riverpod
class McpConsentForm extends _$McpConsentForm {
  @override
  McpConsentFormState build() => const McpConsentFormState();

  /// Ticking a workspace chooses all its operations; clearing it drops
  /// its operations and its fields.
  void toggleWorkspace(ConsentWorkspace w, {required bool on}) {
    final chosen = {...state.chosen};
    final fields = {...state.fields};
    if (on) {
      chosen[w.id] = {...w.operations};
    } else {
      chosen.remove(w.id);
      fields.remove(w.id);
    }
    state = state._with(chosen: chosen, fields: fields);
  }

  void toggleOperation(String workspaceId, String op, {required bool on}) =>
      state = state._with(chosen: _toggled(state.chosen, workspaceId, op, on));

  void toggleField(String workspaceId, String field, {required bool on}) =>
      state = state._with(
        fields: _toggled(state.fields, workspaceId, field, on),
      );

  /// Marks an approval or refusal as running; false when one already is.
  bool begin() {
    if (state.busy) return false;
    state = state._with(busy: true);
    return true;
  }

  /// Ends the running request with how it ended.
  void finish({
    String? outcome,
    McpConsentRefusal? refusal,
    bool failed = false,
  }) {
    state = McpConsentFormState(
      chosen: state.chosen,
      fields: state.fields,
      outcome: outcome,
      refusal: refusal,
      failed: failed,
    );
  }

  /// The outcome alone changed (an eligibility request was sent).
  void setOutcome(String outcome) => state = McpConsentFormState(
    chosen: state.chosen,
    fields: state.fields,
    busy: state.busy,
    outcome: outcome,
    refusal: state.refusal,
    failed: state.failed,
  );

  static Map<String, Set<String>> _toggled(
    Map<String, Set<String>> from,
    String key,
    String value,
    bool on,
  ) {
    final next = {
      for (final e in from.entries) e.key: {...e.value},
    };
    final set = next.putIfAbsent(key, () => {});
    on ? set.add(value) : set.remove(value);
    return next;
  }
}
