// SPDX-License-Identifier: 0BSD
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, PostgrestException;

/// #1233 — the ONE place that knows what a server error is made of.
///
/// `domain/` is meant to be pure Dart and `presentation/` is meant never
/// to see backend types, and eight files broke both rules for the same
/// small reason: they needed the server's own message out of a
/// `PostgrestException` or an `AuthException` in order to map it to
/// something a person can read.
///
/// That is an infrastructure detail with a one-line answer, so it lives
/// here and the layering lint can hold a zero baseline everywhere else.
/// Swapping Supabase for something else becomes an edit to this file
/// rather than a search across the feature tree.
/// The message the SERVER sent, or null when the failure did not come
/// from one — a socket that never connected, a parse that failed, a bug.
///
/// Callers map the message to their own wording; nobody outside this
/// file needs to know which class carried it.
String? serverErrorMessage(Object error) => switch (error) {
      PostgrestException(:final message) => message,
      AuthException(:final message) => message,
      _ => null,
    };

/// True for an error raised by the DATABASE — a constraint, a policy, or
/// a `raise exception` inside a function — as opposed to authentication
/// or transport.
///
/// The distinction matters where the two want different wording: a
/// refused login is the reader's problem to fix, a refused insert is
/// usually a rule they did not know about.
bool isDatabaseError(Object error) => error is PostgrestException;

/// True for an authentication failure: wrong credentials, an expired
/// session, a provider that declined.
bool isAuthError(Object error) => error is AuthException;
