// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2145 — what a refused connection request means. The consent functions
// (0276, 0342) and Auth answer a refusal as a sentence; each known one is
// named here so the consent screen can say what to do next and who does
// it. An unknown error is not classified: nothing is guessed from it.
import '../../../core/data/server_error.dart';

enum McpConsentRefusal {
  /// The operator has not approved this assistant on the installation.
  clientNotApproved,

  /// This database has not approved assistants for the person yet.
  notEligible,

  /// The account has no Google identity: assistants use Google only.
  linkGoogle,

  /// Google is linked, but this session was opened another way.
  signInWithGoogle,

  /// The account's identity on this database is not confirmed.
  noIdentity,

  /// A chosen workspace or operation is no longer offered.
  offerChanged,

  /// The request from the assistant is unknown, used or expired.
  requestExpired,
}

/// The refusal [error] carries, or null when it is not one this screen
/// knows how to explain.
McpConsentRefusal? mcpConsentRefusal(Object error) {
  final text = _message(error).toLowerCase();
  if (text.isEmpty) return null;
  bool has(String s) => text.contains(s);
  if (has('assistant is not approved on this instance')) {
    return McpConsentRefusal.clientNotApproved;
  }
  if (has('has not approved mcp for you')) return McpConsentRefusal.notEligible;
  if (has('link your google account first')) {
    return McpConsentRefusal.linkGoogle;
  }
  if (has('sign in with google to connect')) {
    return McpConsentRefusal.signInWithGoogle;
  }
  if (has('no verified identity binding')) return McpConsentRefusal.noIdentity;
  if (has('cannot be offered') || has('is not available there')) {
    return McpConsentRefusal.offerChanged;
  }
  if (has('unknown authorization') ||
      has('authorization not found') ||
      has('authorization request not found') ||
      has('expired')) {
    return McpConsentRefusal.requestExpired;
  }
  return null;
}

String _message(Object error) => serverErrorMessage(error) ?? '$error';
