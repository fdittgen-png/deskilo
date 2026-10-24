// SPDX-License-Identifier: AGPL-3.0-or-later

/// Where a message the person sent stands while its conversation's
/// composer waits on it.
enum SendPhase {
  /// The send has not answered yet: the composer neither sends again nor
  /// shows the text a second time.
  inFlight,

  /// The send did not answer within [ConversationDelivery.unconfirmedAfter]:
  /// it may or may not have arrived. Nothing resends it by itself; the
  /// person reads the conversation again and decides.
  unconfirmed,
}

/// The delivery's fixed sizes: protocol constants, not choices.
abstract final class ConversationDelivery {
  /// How long a send may go unanswered before it is said to be
  /// unconfirmed — the wait of a request to a connected server.
  static const unconfirmedAfter = Duration(seconds: 20);
}
