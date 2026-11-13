// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3906 — an accounting target's sign-in the browser was sent back with.
// Held in memory only: the router takes it out of the address at once, so
// the address left (`/accounting/connected`) can wait through a sign-in
// like any other, and the page that completes it takes it once.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/accounting_sign_in_return.dart';

class ArrivedAccountingSignIn {
  SignInReturn? _held;

  void hold(SignInReturn back) => _held = back;

  /// The held return, once: a second read finds nothing.
  SignInReturn? take() {
    final back = _held;
    _held = null;
    return back;
  }
}

final arrivedAccountingSignInProvider = Provider<ArrivedAccountingSignIn>(
  (ref) => ArrivedAccountingSignIn(),
);
