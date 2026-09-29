// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1619/#1449 — answering an assistant's confirmation request. The
// decision is the server's (mcp_confirm_action re-checks eligibility,
// permission and the target revision); the screen asks this command, so
// it resolves no repository itself.
//
// #1625 — the answer goes to the installation and account the
// confirmation was read from, through that target's confirmation client,
// as one intent per (target, confirmation, answer): a retry is the same
// request, a double tap sends once.
import '../domain/action_confirmation.dart';
import '../domain/mcp_context.dart';
import 'mcp_commands.dart';

typedef ConfirmationAnswer = ({String id, bool accept});

class ConfirmationAnswers {
  ConfirmationAnswers(this._commands);
  final McpCommands _commands;
  final _intents = <(McpInstanceRef, String, bool), McpMutation<Object?>>{};

  Future<ConfirmationStatus> answer(
    ActionConfirmation confirmation, {
    required bool accept,
  }) {
    final scope = confirmation.scope;
    if (scope == null) throw const McpTargetUnverified('');
    final intent = _intents.putIfAbsent(
      (scope, confirmation.id, accept),
      () => McpMutation<Object?>(
        scope: scope,
        operation: 'mcp_confirm_action',
        payload: (id: confirmation.id, accept: accept),
        purpose: McpClientPurpose.confirmation,
      ),
    );
    return _commands.execute(intent, (repositories, m) {
      final p = m.payload! as ConfirmationAnswer;
      return repositories.confirmations.respond(p.id, accept: p.accept);
    });
  }
}
