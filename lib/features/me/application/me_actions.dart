// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — the account layer's decisions, apart from the widgets that ask
// for them (ADR 0024). Each says what the request IS before anything is
// written; the server remains the authority for all of it.
import '../domain/linked_me_repository.dart';
import '../domain/me_repository.dart';
import '../domain/visibility.dart';
import '../domain/visibility_write.dart';
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

  /// #2558 — a chosen space that is not named by its network reference
  /// (`<installation id>:<local id>`). A bare local id is never sent to the
  /// personal home, which would not know which installation it means.
  unqualifiedSpace,
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
  /// a space when the audience is chosen spaces. #2558 C2 — the personal
  /// home's checked writer: the chosen spaces travel as network references
  /// and [saved] (what the person last read) is the expected value, so a
  /// field changed meanwhile is a [VisibilityConflict] carrying the value
  /// saved now, and nothing is written.
  ///
  /// A lost reply ([VisibilityReplyLost]) is read back: the
  /// intended value saved means saved; anything else is a conflict to
  /// review ([VisibilityConflict.unconfirmed]) — never a blind resend. A
  /// refusal of the server is rethrown as it is, and no weaker writer is
  /// tried.
  ///
  /// [epoch] names the account and home the write is for; when it changed
  /// before the reply arrived, the reply is an older epoch's and the result
  /// is null (a conflict of that epoch is dropped too).
  Future<MyVisibility?> choose(
    VisibilityField field,
    FieldAudience choice, {
    MyVisibility saved = MyVisibility.defaults,
    String Function()? epoch,
  }) async {
    if (!field.allowedAudiences.contains(choice.audience)) {
      throw const MeRefused(MeRefusal.audienceNotAllowed);
    }
    if (choice.incomplete) throw const MeRefused(MeRefusal.noSpaceChosen);
    final intended = choice.audience == VisibilityAudience.chosenSpaces
        ? choice
        : FieldAudience(choice.audience);
    if (!intended.workspaces.every(FieldAudience.isNetworkRef)) {
      throw const MeRefused(MeRefusal.unqualifiedSpace);
    }
    final at = epoch?.call();
    bool current() => epoch == null || epoch() == at;
    try {
      final result = await _repository.setVisibilityIfUnchanged(
        field,
        intended,
        expected: saved.of(field),
      );
      return current() ? result : null;
    } on VisibilityConflict {
      if (!current()) return null;
      throw VisibilityConflict(current: await _readBack(field));
    } on VisibilityReplyLost catch (_, st) {
      // trace-exempt: the outcome is read back; an unknown one is reviewed.
      if (!current()) return null;
      final now = await _readBackView();
      if (now == null) rethrow;
      if (now.of(field) == intended) return now;
      Error.throwWithStackTrace(
        VisibilityConflict(current: now.of(field), unconfirmed: true),
        st,
      );
    }
  }

  /// The saved view now, or null when it cannot be read either.
  Future<MyVisibility?> _readBackView() async {
    try {
      return await _repository.myVisibility();
    } on Object {
      // trace-exempt: an unreadable read-back leaves the outcome unknown.
      return null;
    }
  }

  Future<FieldAudience?> _readBack(VisibilityField field) async =>
      (await _readBackView())?.of(field);

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
