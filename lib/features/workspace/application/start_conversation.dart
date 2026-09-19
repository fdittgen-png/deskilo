// SPDX-License-Identifier: 0BSD
//
// #1449 / #1234 — starting a conversation is two decisions, not a form.
//
// **Which kind of thread this is.** Inside the messages hub it is
// whatever the Group switch says. Outside it, picking a second person
// MAKES it a group — nobody chose a mode, they chose people — and a
// group needs a name while a one-to-one is titled by the person.
//
// **A name already taken is a refusal, not a failure.** It is one word
// to change, and saying so is the whole difference between a dead end
// and a correction. The sheet matched the server's wording with
// `'$e'.contains(…)` inside its catch, which meant the rule could only
// be exercised by pumping a sheet and reading a snackbar — and that a
// reworded server message would silently downgrade the correction back
// into "something went wrong".
//
// ADR 0024's shape, like `Payments` and `LegalIdentity`: the repository
// handed in, outcomes as types, so both rules are ordinary unit tests.
import '../domain/workspace_repository.dart';

/// What happened to a conversation somebody tried to start.
sealed class StartConversationOutcome {
  const StartConversationOutcome();
}

/// The thread exists; [id] is it.
class ConversationStarted extends StartConversationOutcome {
  const ConversationStarted(this.id);
  final String id;
}

/// A group of that name is already here. Its own outcome, so the caller
/// says "pick another" instead of "something went wrong".
class GroupNameTaken extends StartConversationOutcome {
  const GroupNameTaken();
}

/// The wording the server refuses with (#694). Kept next to the rule it
/// serves rather than inside a catch block, so the coupling to the
/// server's sentence is visible to whoever changes either side.
const kGroupNameTakenError = 'a group with that name already exists';

/// Conversations, as the decisions behind starting one.
class Conversations {
  const Conversations(this._workspace);

  final WorkspaceRepository _workspace;

  /// Whether picking [selected] people in [hub] means a group.
  ///
  /// Two people is a group whatever the switch says outside the hub:
  /// somebody who picked two people did not ask for a one-to-one.
  static bool isGroup({required bool hub, required bool groupMode, required int selected}) =>
      hub ? groupMode : selected > 1;

  /// Opens the thread, or says why it could not.
  ///
  /// Rethrows anything that is not the taken-name refusal: a real
  /// failure is the caller's to report, and swallowing it here would
  /// turn every server problem into "pick another name".
  Future<StartConversationOutcome> start({
    required String workspaceId,
    required bool group,
    required String title,
    required List<String> memberIds,
  }) async {
    try {
      final id = group
          ? await _workspace.createGroupConversation(
              workspaceId,
              title: title.trim(),
              memberIds: memberIds,
            )
          : await _workspace.openDirectConversation(
              workspaceId,
              otherMemberId: memberIds.single,
            );
      return ConversationStarted(id);
      // ignore: catch_no_st
    } catch (e) {
      // Only the refusal is turned into an answer; everything else is
      // rethrown for the caller to trace and report.
      if ('$e'.contains(kGroupNameTakenError)) return const GroupNameTaken();
      rethrow;
    }
  }
}
