// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2495 — who is signed in, as core areas need to know it. The auth
// feature implements [SessionSource] (its repository does) and the
// composition root hands it over with an override; core never imports the
// feature. Unwired, the session is signed out: the safe answer.
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The session as core sees it.
abstract interface class SessionSource {
  /// Emits the signed-in user id, or null when signed out; the current
  /// state to a new listener immediately.
  Stream<String?> authStateChanges();

  /// The signed-in user id, or null.
  String? get currentUserId;
}

class _SignedOut implements SessionSource {
  const _SignedOut();

  @override
  Stream<String?> authStateChanges() => Stream.value(null);

  @override
  String? get currentUserId => null;
}

/// The session source. Overridden by the composition root (see
/// `sessionSourceFromAuth` in the auth feature); signed out until then.
final sessionSourceProvider = Provider<SessionSource>(
  (ref) => const _SignedOut(),
);

/// The signed-in user id as a stream; what core providers watch to rebuild
/// when the person signs in or out.
final sessionStateProvider = StreamProvider<String?>(
  (ref) => ref.watch(sessionSourceProvider).authStateChanges(),
);
