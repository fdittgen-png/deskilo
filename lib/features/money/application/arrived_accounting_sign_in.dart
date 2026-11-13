// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3906 — an accounting target's sign-in the browser was sent back with.
// Held in memory only: the router takes it out of the address at once, so
// the address left (`/accounting/connected`) can wait through a sign-in
// like any other, and the page that completes it uses it once.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_source.dart';
import '../../../core/time/clock.dart';
import '../domain/accounting_sign_in_return.dart';

/// #3906 — how long a held return is worth completing: the server's state
/// lifetime. An older one is dropped unread.
const Duration signInReturnLifetime = Duration(minutes: 10);

class ArrivedAccountingSignIn {
  ArrivedAccountingSignIn(this._now);

  final DateTime Function() _now;
  SignInReturn? _held;
  DateTime? _heldAt;
  bool _answering = false;

  void hold(SignInReturn back) {
    _held = back;
    _heldAt = _now();
  }

  /// The return waiting to be completed, or null — also once it is older
  /// than [signInReturnLifetime], when it is dropped.
  SignInReturn? get held {
    final at = _heldAt;
    if (at != null && _now().difference(at) > signInReturnLifetime) {
      _held = null;
      _heldAt = null;
    }
    return _held;
  }

  /// Whether the page's route stays open: a return waits, or the page is
  /// showing how one ended — even before the workspace's switches are read
  /// (the server decides switch and right).
  bool get holds => held != null || _answering;

  /// The page took the held return and shows its answer until it closes.
  void answering() => _answering = true;

  /// Used once: the code and the state go when the completion answered; the
  /// page's hold goes when it closes — a reload after that meets the guard.
  void clear({bool closed = false}) {
    _held = null;
    _heldAt = null;
    if (closed) _answering = false;
  }

  /// Sign-out, or another account: nothing held is completed by whoever
  /// comes next.
  void forget() => clear(closed: true);
}

final arrivedAccountingSignInProvider = Provider<ArrivedAccountingSignIn>((
  ref,
) {
  final arrived = ArrivedAccountingSignIn(() => ref.read(clockProvider).now());
  // A person who signs in to complete keeps it; one who signs out, or
  // another account, does not.
  ref.listen(sessionStateProvider, (before, after) {
    final was = before?.value;
    if (was != null && was != after.value) arrived.forget();
  });
  return arrived;
});
