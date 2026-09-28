// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/backend/federation_handoff.dart';

export '../../../core/backend/federation_handoff.dart';

/// Where "Continue with Deskilo" leads, in the only terms a member needs:
/// the server they return to and the authority that confirms who they are.
/// Host names only — never a client id, key, UUID or schema.
typedef FederationDestination = ({String server, String authority});

/// #1648 — one explicit-target "Sign in with Deskilo" handoff, as the
/// sign-in and linked-accounts screens see it. Implemented over the
/// installation's callback guard and the isolated native federation flow.
abstract class FederationPort {
  /// The destination to explain before anything opens; null when this
  /// server does not offer Deskilo sign-in.
  Future<FederationDestination?> destination();

  /// Opens the system browser once and answers the flow id. Throws
  /// [FederationStartFailure] when nothing was opened.
  Future<String> begin({required bool link});

  /// Every claim and result, tagged with its flow.
  Stream<FederationEvent> get events;

  /// The last event, for a screen that subscribes after it happened.
  FederationEvent? get lastEvent;

  /// A flow begun before this process started (the app was stopped while
  /// the browser was open), still waiting for its return.
  ({String flow, bool link})? get pending;

  /// Still waiting for its browser return. Asking never relaunches.
  bool awaiting(String flow);

  /// Its return was claimed and is being completed right now.
  bool completing(String flow);

  /// Abandons [flow]: a later return for it is refused, not exchanged.
  Future<void> cancel(String flow);
}
