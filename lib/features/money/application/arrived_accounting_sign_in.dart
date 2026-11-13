// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3906 — an accounting target's sign-in the browser was sent back with.
// Held in memory only: the router takes it out of the address at once, so
// the address left (`/accounting/connected`) can wait through a sign-in
// like any other, and the page that completes it uses it once.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/accounting_sign_in_return.dart';

class ArrivedAccountingSignIn {
  SignInReturn? _held;

  void hold(SignInReturn back) => _held = back;

  /// The return waiting to be completed, or null.
  SignInReturn? get held => _held;

  /// Whether the page's route stays open: a return waits, or the page is
  /// showing how one ended — even before the workspace's switches are read
  /// (the server decides switch and right).
  bool get holds => _held != null || _answering;
  bool _answering = false;

  /// The page took the held return and shows its answer until it closes.
  void answering() => _answering = true;

  /// Used once: the code and the state go when the completion answered; the
  /// page's hold goes when it closes — a reload after that meets the guard.
  void clear({bool closed = false}) {
    _held = null;
    if (closed) _answering = false;
  }
}

final arrivedAccountingSignInProvider = Provider<ArrivedAccountingSignIn>(
  (ref) => ArrivedAccountingSignIn(),
);
