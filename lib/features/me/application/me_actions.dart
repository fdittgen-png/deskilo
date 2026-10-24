// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — the account layer's decisions, apart from the widgets that ask
// for them (ADR 0024). Each says what the request IS before anything is
// written; the server remains the authority for all of it.
import '../domain/linked_me_repository.dart';
import '../domain/me_repository.dart';
import '../domain/visibility.dart';
import '../domain/workspace_access_repository.dart';

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

  /// #2558 — the field names, or would name, a chosen space on another
  /// installation. Today's writer takes local ids of this home only; such
  /// a field is read-only here until the network writer exists (#2563 C2),
  /// and its reference is never read as a local id.
  spaceElsewhere,
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
  const MeActions(this._repository, this._linked, this._access);

  final MeRepository _repository;
  final LinkedMeRepository _linked;

  /// #2563 — what acts inside a workspace, on that workspace's host.
  final WorkspaceAccessRepository _access;

  /// Leave [workspaceId]. My data stays with the space; erasing it is the
  /// separate action under Privacy.
  Future<void> leave(String workspaceId, {required bool isOwner}) {
    if (isOwner) throw const MeRefused(MeRefusal.ownerMustHandOver);
    return _access.leaveSpace(workspaceId);
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
  Future<void> publishProfile({required bool publish}) =>
      _repository.setPublicProfile(publish: publish);

  /// Give [field] the audience [choice]: one this field may have, and with
  /// a space when the audience is chosen spaces. #2558 — [saved] is what
  /// the personal home answered: the chosen spaces are its network
  /// references, and each is written as the local id of THIS home; a
  /// field that names a space elsewhere, or a choice that would, is
  /// refused before any call, so no saved reference is dropped silently.
  Future<void> choose(
    VisibilityField field,
    FieldAudience choice, {
    MyVisibility saved = MyVisibility.defaults,
  }) {
    if (!field.allowedAudiences.contains(choice.audience)) {
      throw const MeRefused(MeRefusal.audienceNotAllowed);
    }
    if (choice.incomplete) throw const MeRefused(MeRefusal.noSpaceChosen);
    if (saved.namesSpaceElsewhere(field)) {
      throw const MeRefused(MeRefusal.spaceElsewhere);
    }
    if (choice.audience != VisibilityAudience.chosenSpaces) {
      return _repository.setVisibility(field, FieldAudience(choice.audience));
    }
    final local = <String>{};
    for (final ref in choice.workspaces) {
      final id = saved.localIdOf(ref);
      if (id == null) throw const MeRefused(MeRefusal.spaceElsewhere);
      local.add(id);
    }
    return _repository.setVisibility(
      field,
      FieldAudience(choice.audience, local),
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
    return _linked.setVisibility(source, field, choice);
  }
}
