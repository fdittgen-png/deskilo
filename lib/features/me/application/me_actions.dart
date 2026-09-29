// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — the account layer's decisions, apart from the widgets that ask
// for them (ADR 0024). Each says what the request IS before anything is
// written; the server remains the authority for all of it.
import '../domain/me_repository.dart';
import '../domain/visibility.dart';

/// Why a request was refused before it reached the server.
enum MeRefusal {
  /// An owner leaving would leave the space without its owner: the space
  /// has to be handed over first (Settings › Roles).
  ownerMustHandOver,

  /// "Chosen spaces" with no space chosen would hide the field from
  /// everybody while claiming to show it to some.
  noSpaceChosen,
}

class MeRefused implements Exception {
  const MeRefused(this.reason);
  final MeRefusal reason;

  @override
  String toString() => 'MeRefused($reason)';
}

class MeActions {
  const MeActions(this._repository);

  final MeRepository _repository;

  /// Leave [workspaceId]. My data stays with the space; erasing it is the
  /// separate action under Privacy.
  Future<void> leave(String workspaceId, {required bool isOwner}) {
    if (isOwner) throw const MeRefused(MeRefusal.ownerMustHandOver);
    return _repository.leaveSpace(workspaceId);
  }

  /// Give [field] the audience [choice].
  Future<void> choose(VisibilityField field, FieldAudience choice) {
    if (choice.incomplete) throw const MeRefused(MeRefusal.noSpaceChosen);
    return _repository.setVisibility(
      field,
      choice.audience == VisibilityAudience.chosenSpaces
          ? choice
          : FieldAudience(choice.audience),
    );
  }
}
