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

  /// #2211 — an audience this field may not have (contact details and
  /// presence stop at my spaces), or chosen spaces on another server,
  /// whose spaces are not listed here.
  audienceNotAllowed,

  /// A profession over 120 characters or a bio over 1000 — the limits
  /// the server's table holds.
  aboutTooLong,
}

/// The longest profession and bio `account_about` stores.
abstract final class AboutLimits {
  static const int profession = 120;
  static const int bio = 1000;
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

  /// My profession and bio, trimmed; who reads them is [VisibilityField.about].
  Future<void> saveAbout(String profession, String bio) {
    final p = profession.trim();
    final b = bio.trim();
    if (p.length > AboutLimits.profession || b.length > AboutLimits.bio) {
      throw const MeRefused(MeRefusal.aboutTooLong);
    }
    return _repository.setAbout(p, b);
  }

  /// Publish ([publish] true) or withdraw my public profile (0389).
  Future<void> publishProfile(bool publish) =>
      _repository.setPublicProfile(publish);

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

  /// #2211 — give [field] the audience [choice] on the linked server
  /// [source], for the account I have there.
  Future<void> chooseOn(
    String source,
    VisibilityField field,
    FieldAudience choice,
  ) {
    if (!field.allowedAudiences.contains(choice.audience) ||
        choice.audience == VisibilityAudience.chosenSpaces) {
      throw const MeRefused(MeRefusal.audienceNotAllowed);
    }
    return _repository.setVisibilityOn(source, field, choice);
  }
}
