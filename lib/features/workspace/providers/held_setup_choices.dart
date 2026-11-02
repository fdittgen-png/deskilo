// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3235 — the choices a person had not applied on "Set up by level" when
// they opened the demo example from it.
//
// The demo replaces the live tree, so the screen's local state goes; this
// holds exactly those answers in the live container, for that account and
// that workspace, until the screen takes them back. It is not a draft
// store: nothing is saved anywhere, nothing is applied, and a different
// account, a sign-out or the end of the return forgets them.
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/setup_levels.dart';
import 'workspace_providers.dart';

part 'held_setup_choices.g.dart';

@immutable
class HeldSetupChoices {
  const HeldSetupChoices({
    required this.userId,
    required this.workspaceId,
    required this.answers,
    required this.answered,
    required this.chosen,
    required this.unknown,
  });

  final String userId;
  final String workspaceId;
  final SetupAnswers answers;

  /// Whether the owner answered a question (the levels then follow the
  /// recommendation).
  final bool answered;

  /// The levels set by hand or by a quick start.
  final Map<SetupProcess, String> chosen;

  /// The questions left at "not sure yet".
  final Set<String> unknown;
}

@Riverpod(keepAlive: true)
class HeldSetupChoicesController extends _$HeldSetupChoicesController {
  @override
  HeldSetupChoices? build() {
    ref.listen(currentAccountIdProvider, (_, next) {
      if (state != null && next != state!.userId) state = null;
    });
    return null;
  }

  void hold(HeldSetupChoices choices) => state = choices;

  /// The choices held for [userId] in [workspaceId], or null.
  HeldSetupChoices? heldFor(String? userId, String workspaceId) {
    final held = state;
    return held != null &&
            held.userId == userId &&
            held.workspaceId == workspaceId
        ? held
        : null;
  }

  void clear() => state = null;
}
