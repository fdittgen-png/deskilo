// SPDX-License-Identifier: 0BSD
import '../../l10n/app_localizations.dart';
import '../data/server_error.dart';

/// #1305 S2 — the refusals every surface can meet, whatever it was doing.
///
/// `runGuarded` used to show its caller's `errorText` for any failure —
/// 180 call sites passing "Something went wrong. Please try again." A
/// member refused for lack of a permission read that as a fault to retry,
/// and retried. These four families are not faults and not domain
/// specific: the server said *who may*, *who you are*, *it already
/// happened*, or *the thing moved*. Each gets its own sentence, once, at
/// the single point every guarded action passes through.
///
/// Booking refusals keep their own mapper (`bookingErrorText`), which
/// knows the booking vocabulary; this one knows only what any screen can
/// hit. Substrings are pinned against the migrations by
/// `test/core/trace/refusal_text_test.dart` — a server message that stops
/// being raised fails there, not silently in front of a member.
enum KnownRefusal { permission, session, alreadyDecided, changedMeanwhile }

/// Substrings of server refusals that mean "you may not".
const List<String> permissionRefusalSubstrings = [
  'not an admin of this workspace',
  'not the owner of this workspace',
  'admins only',
  'platform owners only',
  'only role managers may',
  'only owners may',
  'only admins may',
  'only workspace settings managers may',
  'not allowed to manage this profile',
  // #1561 — the READ behind the same rule (0161's managed_identity_of).
  'not allowed to read this profile',
  'violates row-level security policy',
];

/// Substrings that mean the session is gone.
const List<String> sessionRefusalSubstrings = [
  'not authenticated',
  'jwt expired',
];

/// Substrings that mean somebody else already acted.
const List<String> alreadyDecidedSubstrings = [
  'already decided',
];

/// Substrings that mean the record moved under the reader's feet.
const List<String> changedMeanwhileSubstrings = [
  'invoice is voided',
  'invoice is matched',
  'invoice already replaced',
  'invoice already matched',
];

/// Which family [error] belongs to, or null when it is none of them.
KnownRefusal? knownRefusalOf(Object error) {
  // 42501 is Postgres's own insufficient_privilege — an RLS refusal or a
  // revoked grant, which never carries one of our sentences.
  if (serverErrorCode(error) == '42501') return KnownRefusal.permission;
  final message = serverErrorMessage(error)?.toLowerCase();
  if (message == null) return null;
  if (isAuthError(error) &&
      (message.contains('expired') || message.contains('refresh token'))) {
    return KnownRefusal.session;
  }
  bool any(List<String> needles) => needles.any(message.contains);
  if (any(sessionRefusalSubstrings)) return KnownRefusal.session;
  if (any(permissionRefusalSubstrings)) return KnownRefusal.permission;
  if (any(alreadyDecidedSubstrings)) return KnownRefusal.alreadyDecided;
  if (any(changedMeanwhileSubstrings)) return KnownRefusal.changedMeanwhile;
  return null;
}

/// The sentence for [error] when it is a known refusal, else null — the
/// caller keeps its own text for everything else.
String? knownRefusalText(AppLocalizations? l10n, Object error) =>
    switch (knownRefusalOf(error)) {
      KnownRefusal.permission => l10n?.refusalPermission ??
          'You do not have the permission for this. An owner of the space '
              'can grant it in Role management.',
      KnownRefusal.session => l10n?.refusalSession ??
          'Your session has ended. Sign in again, then retry.',
      KnownRefusal.alreadyDecided => l10n?.refusalAlreadyDecided ??
          'Someone has already decided this. The list shows the outcome.',
      KnownRefusal.changedMeanwhile => l10n?.refusalChangedMeanwhile ??
          'This changed in the meantime. Reopen it to see where it stands.',
      null => null,
    };
