// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'auth_callback_guard.dart';

/// The process's one dispatcher, set at start-up (null in widget tests).
AuthCallbackDispatcher? bootAuthCallbackDispatcher;

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

  /// #1834 — flows that connect ANOTHER installation. Each has its own
  /// guard (its target's origin, its own flow id); this dispatcher stays
  /// the only owner of every incoming URI and hands a return to the one
  /// flow that claims it. The main client never exchanges these.
  final _secondary = <AuthCallbackGuard, Future<void> Function(Uri)>{};

  void routeSecondary(
    AuthCallbackGuard target,
    Future<void> Function(Uri) complete,
  ) => _secondary[target] = complete;

  void unrouteSecondary(AuthCallbackGuard target) => _secondary.remove(target);

  /// True only when the main SDK client should exchange [uri] itself.
  bool call(Uri uri) {
    if (!guard.claim(uri, account: currentUser())) {
      for (final entry in _secondary.entries.toList()) {
        if (entry.key.claim(uri, account: currentUser())) {
          unawaited(entry.value(uri));
          return false;
        }
      }
      return false;
    }
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
