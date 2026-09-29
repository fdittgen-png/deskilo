// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'auth_callback_guard.dart';

/// #1648 — the ONE owner of an incoming auth URI.
///
/// The SDK asks [call] through its documented `detectSessionInUriPredicate`.
/// A return the guard does not claim (another installation, a cancelled or
/// expired flow, a replay) is refused: nothing is exchanged and nothing
/// navigates. A federation return is handed to the isolated target flow and
/// never to the main client, so two clients never consume one deep link.
class AuthCallbackDispatcher {
  AuthCallbackDispatcher(this.guard, {required this.currentUser});

  final AuthCallbackGuard guard;
  final String? Function() currentUser;
  Future<void> Function(Uri)? _complete;
  final _early = <Uri>[];

  /// True only when the main SDK client should exchange [uri] itself.
  bool call(Uri uri) {
    if (!guard.claim(uri, account: currentUser())) return false;
    if (guard.purpose?.startsWith('federation') != true) return true;
    final complete = _complete;
    if (complete == null) {
      _early.add(uri);
    } else {
      unawaited(complete(uri));
    }
    return false; // The isolated target client owns this exchange.
  }

  /// Connects the federation completion once the SDK exists, and replays a
  /// return that arrived while the app was still starting.
  Future<void> attach(Future<void> Function(Uri) complete) async {
    _complete = complete;
    final early = List.of(_early);
    _early.clear();
    for (final uri in early) {
      await complete(uri);
    }
  }
}
