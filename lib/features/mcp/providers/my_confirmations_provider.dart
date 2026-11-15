// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3978 — the person's own assistant requests for the assistants page:
// read through the active target's confirmation client, as one request is
// (#1625), so each answer goes back to the installation it came from.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../domain/action_confirmation.dart';
import '../domain/mcp_context.dart';
import 'mcp_providers.dart';

/// Every request waiting for the person, then the ones answered in the
/// last [answeredRequestsShown], newest first.
final myActionConfirmationsProvider =
    FutureProvider.autoDispose<List<ActionConfirmation>>((ref) async {
      final since = ref
          .watch(clockProvider)
          .now()
          .subtract(answeredRequestsShown);
      final target = ref.watch(activeMcpTargetProvider.future);
      final commands = ref.watch(mcpCommandsProvider);
      final scope = (await target).instance;
      final mine = await commands.read(
        scope,
        (r) => r.confirmations.mine(answeredSince: since),
        purpose: McpClientPurpose.confirmation,
      );
      return [for (final c in mine) c.withScope(scope)];
    }, retry: (_, _) => null);
