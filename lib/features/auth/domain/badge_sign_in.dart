// SPDX-License-Identifier: 0BSD

/// The two-step badge sign-in (#662): a scan says WHO, a PIN says
/// it is really them.
///
/// The split is the point. It lets the form greet you by name before
/// asking for a secret, and it is what makes "set a PIN on the member
/// who just scanned" a coherent thing to do — the user asked for
/// exactly that sequencing.
library;

/// Why a badge step did not go through.
///
/// There are only two, and that is deliberate: an unknown badge, a badge
/// whose owner never set a PIN, a badge nobody armed and a wrong PIN all
/// come back as [refused]. Telling them apart would turn a kiosk into an
/// oracle that sorts a stolen stack of cards into real and fake.
enum BadgeSignInFailure {
  /// Any refusal. The message must stay the same for all of them.
  refused,

  /// Too many wrong PINs — the one distinction worth making, because a
  /// member who is locked out needs to know that waiting is the answer,
  /// and by then the attempt rows already exist, so it reveals nothing
  /// a wrong guesser did not already cause.
  locked,

  /// The function is not deployed, or the network is down. Not a
  /// refusal: nothing about the badge was judged, and saying "wrong PIN"
  /// here would send someone hunting for a mistake they did not make.
  unavailable,
}

/// Who the badge belongs to. Deliberately no e-mail address: a scanned
/// tag must not become a way to harvest addresses off a shared tablet.
class BadgeIdentity {
  const BadgeIdentity({
    required this.userId,
    required this.displayName,
    required this.hasAvatar,
  });

  final String userId;
  final String displayName;

  /// Whether to try to load a face for the PIN prompt. The photo itself
  /// is fetched by the widget through the usual avatar path.
  final bool hasAvatar;
}

/// The outcome of either step: the value, or why not.
class BadgeStepResult<T> {
  const BadgeStepResult.ok(this.value) : failure = null;
  const BadgeStepResult.failed(BadgeSignInFailure this.failure) : value = null;

  final T? value;
  final BadgeSignInFailure? failure;

  bool get ok => failure == null;
}
