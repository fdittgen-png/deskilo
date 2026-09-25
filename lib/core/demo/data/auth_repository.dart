// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ADR 0028 (#1373) — moved out of test/helpers/mock_providers.dart so the
// Demo environment can run the real app against it. The suite reaches it
// through the same import as before.

import 'dart:async';
import 'package:deskilo/features/auth/domain/auth_outcome.dart';
import 'package:deskilo/features/auth/domain/auth_repository.dart';
import 'package:deskilo/features/auth/domain/badge_sign_in.dart';
import 'package:deskilo/features/auth/domain/social_provider.dart';

/// In-memory [AuthRepository] for widget/unit tests (fakes over mocks).
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({String? userId}) : _userId = userId;

  FakeAuthRepository.signedIn() : this(userId: 'user-1');

  String? _userId;
  final _controller = StreamController<String?>.broadcast();

  /// Social sign-in/link calls, for assertions (0051).
  final socialSignIns = <SocialProvider>[];
  final socialLinks = <SocialProvider>[];
  final unlinked = <LinkedIdentity>[];

  /// Identities the fake reports; seeded by tests.
  List<LinkedIdentity> identities = [
    (id: 'ident-email', provider: 'email'),
  ];

  /// When set, social calls throw (models a provider not enabled).
  Object? socialError;

  @override
  Future<void> signInWithSocial(SocialProvider provider) async {
    if (socialError != null) throw socialError!;
    socialSignIns.add(provider);
  }

  @override
  Future<List<LinkedIdentity>> linkedIdentities() async => identities;

  @override
  Future<void> linkSocial(SocialProvider provider) async {
    if (socialError != null) throw socialError!;
    socialLinks.add(provider);
    identities = [
      ...identities,
      (id: 'ident-${provider.wireName}', provider: provider.wireName),
    ];
  }

  @override
  Future<void> unlinkIdentity(LinkedIdentity identity) async {
    unlinked.add(identity);
    identities =
        identities.where((i) => i.id != identity.id).toList();
  }

  // ── badge sign-in (#662) ────────────────────────────────────────────

  /// Badge uid -> who it identifies. A uid absent from the map is an
  /// unknown badge, which the real server refuses.
  final Map<String, BadgeIdentity> badges = {};

  /// The PIN [signInWithBadge] accepts. Any other value is refused.
  String? badgePin;

  /// When set, both badge steps report this instead of consulting the
  /// map — models a lockout or an undeployed function.
  BadgeSignInFailure? badgeFailure;

  /// Every PIN written through [setBadgePin], in order.
  final List<String> setPins = [];
  bool badgePinCleared = false;
  final List<({String badgeId, bool enabled})> badgeAuthToggles = [];

  @override
  Future<BadgeStepResult<BadgeIdentity>> identifyBadge(String uid) async {
    if (badgeFailure != null) return BadgeStepResult.failed(badgeFailure!);
    final who = badges[uid];
    return who == null
        ? const BadgeStepResult.failed(BadgeSignInFailure.refused)
        : BadgeStepResult.ok(who);
  }

  @override
  Future<BadgeStepResult<void>> signInWithBadge({
    required String uid,
    required String pin,
  }) async {
    if (badgeFailure != null) return BadgeStepResult.failed(badgeFailure!);
    if (badges[uid] == null || badgePin == null || pin != badgePin) {
      return const BadgeStepResult.failed(BadgeSignInFailure.refused);
    }
    _setUser(badges[uid]!.userId);
    return const BadgeStepResult.ok(null);
  }

  @override
  Future<bool> hasBadgePin() async => badgePin != null;

  @override
  Future<void> setBadgePin(String pin) async {
    setPins.add(pin);
    badgePin = pin;
  }

  @override
  Future<void> clearBadgePin() async {
    badgePinCleared = true;
    badgePin = null;
  }

  @override
  Future<void> setBadgeAuthEnabled({
    required String badgeId,
    required bool enabled,
  }) async =>
      badgeAuthToggles.add((badgeId: badgeId, enabled: enabled));

  /// Emails for which [signInWithPassword]/[signUp] should throw.
  final Set<String> failingEmails = {};

  @override
  Stream<String?> authStateChanges() async* {
    yield _userId;
    yield* _controller.stream;
  }

  @override
  String? get currentUserId => _userId;

  /// Signs in as [id] without a network round trip (#1376): the Demo
  /// persona switch, and nothing else, uses it.
  void signInAs(String id) => _setUser(id);

  void _setUser(String? id) {
    _userId = id;
    _controller.add(id);
  }

  // ── typed outcomes (#1649) ──────────────────────────────────────────

  /// Scripted answers. When set, the operation answers with it instead of
  /// consulting [failingEmails] / [failingCodes]; an `authenticated` or
  /// `completed` script still signs the fake in, like the server would.
  AuthResult? signInResult;
  AuthResult? signUpResult;
  AuthResult? resendResult;

  /// When set, every operation waits for it before answering — a test
  /// holds the screen mid-flight, closes or changes it, and only then
  /// lets the answer land.
  Completer<void>? gate;

  /// Every sign-up and every resend, in call order — two entries where
  /// one was pressed is the duplicate-submission bug.
  final signUps = <String>[];
  final resends = <String>[];

  Future<AuthResult> _answer(AuthResult result) async {
    if (gate != null) await gate!.future;
    if (result.outcome == AuthOutcome.authenticated ||
        result.outcome == AuthOutcome.completed) {
      _setUser('user-1');
    }
    return result;
  }

  @override
  Future<AuthResult> signInWithPassword({
    required String email,
    required String password,
  }) =>
      _answer(signInResult ??
          (failingEmails.contains(email)
              ? const AuthResult.refused(AuthRefusal.credentials)
              : const AuthResult.authenticated()));

  @override
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String displayName,
  }) {
    signUps.add(email);
    return _answer(signUpResult ??
        (failingEmails.contains(email)
            ? const AuthResult.refused(AuthRefusal.credentials)
            : const AuthResult.authenticated()));
  }

  @override
  Future<AuthResult> resendSignUpVerification(String email) {
    resends.add(email);
    return _answer(resendResult ?? const AuthResult.verificationRequired());
  }

  @override
  Future<void> signOut() async => _setUser(null);

  /// Emails passed to [requestPasswordReset], in call order.
  final resetRequests = <String>[];

  /// (email, code, newPassword) tuples of successful confirmations.
  final confirmedResets = <(String, String, String)>[];

  /// Codes for which [confirmPasswordReset] answers `codeInvalid`.
  final Set<String> failingCodes = {};

  /// Scripted recovery answers (#1649). A `completed` still signs the
  /// fake in; a `recoverySessionReadyButPasswordNotUpdated` does NOT,
  /// like the real adapter's held-back session.
  AuthResult? resetRequestResult;
  AuthResult? confirmResetResult;
  AuthResult? updatePasswordResult;

  /// Every [updateRecoveredPassword], in call order.
  final passwordUpdates = <String>[];
  bool recoveryCancelled = false;

  @override
  Future<AuthResult> requestPasswordReset(String email) {
    resetRequests.add(email);
    return _answer(
        resetRequestResult ?? const AuthResult.recoveryVerificationRequired());
  }

  @override
  Future<AuthResult> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final result = await _answer(confirmResetResult ??
        (failingCodes.contains(code)
            ? const AuthResult.refused(AuthRefusal.codeInvalid)
            : const AuthResult.completed()));
    if (result.outcome == AuthOutcome.completed) {
      confirmedResets.add((email, code, newPassword));
    }
    return result;
  }

  @override
  Future<AuthResult> updateRecoveredPassword(String newPassword) {
    passwordUpdates.add(newPassword);
    return _answer(updatePasswordResult ?? const AuthResult.completed());
  }

  @override
  Future<void> cancelPasswordRecovery() async => recoveryCancelled = true;
}
