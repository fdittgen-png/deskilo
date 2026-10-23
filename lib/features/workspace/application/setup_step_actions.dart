// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2869 (0545) — the setup guide's own actions on a step. A step the
// server cannot verify is marked done, an optional one set aside for
// later, and either taken back; a required step the server verifies
// offers neither — it has to be set up. The server applies the same rules
// (acknowledge_setup_step) and refuses what this would not offer.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/local_setup.dart';
import '../domain/setup_status.dart';
import '../providers/local_setup_providers.dart';

part 'setup_step_actions.g.dart';

/// What a step offers.
enum SetupStepOffer { later, done, undo }

class SetupStepActions {
  const SetupStepActions(this._repository);
  final LocalSetupRepository _repository;

  /// The one action [step] offers, or null.
  static SetupStepOffer? offerFor(SetupStepStatus step) {
    final open = step.state == SetupStepState.needsConfiguration;
    if (step.state == SetupStepState.deferred ||
        (step.manual && step.state == SetupStepState.ready)) {
      return SetupStepOffer.undo;
    }
    if (step.manual && open) return SetupStepOffer.done;
    if (!step.required && open) return SetupStepOffer.later;
    return null;
  }

  /// Does what [step] offers in [workspaceId]. Returns false, writing
  /// nothing, when it offers nothing; a server refusal propagates.
  Future<bool> run(String workspaceId, SetupStepStatus step) async {
    switch (offerFor(step)) {
      case null:
        return false;
      case SetupStepOffer.undo:
        await _repository.clearStepAcknowledgement(workspaceId, step.step);
      case SetupStepOffer.later || SetupStepOffer.done:
        await _repository.acknowledgeStep(workspaceId, step.step);
    }
    return true;
  }
}

/// #2869 (0545) — the guide's Later, Mark as done and Undo.
@riverpod
SetupStepActions setupStepActions(Ref ref) =>
    SetupStepActions(ref.watch(localSetupRepositoryProvider));
