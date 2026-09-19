// SPDX-License-Identifier: 0BSD
//
// ADR 0028 (#1373) — moved out of test/helpers/mock_providers.dart so the
// Demo environment can run the real app against it. The suite reaches it
// through the same import as before.

import 'dart:async';
import 'package:deskilo/features/auth/domain/auth_repository.dart';
import 'package:deskilo/features/auth/domain/badge_sign_in.dart';
import 'package:deskilo/features/auth/domain/social_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

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

  void _setUser(String? id) {
    _userId = id;
    _controller.add(id);
  }

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (failingEmails.contains(email)) {
      throw const AuthException('invalid credentials');
    }
    _setUser('user-1');
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (failingEmails.contains(email)) {
      throw const AuthException('sign up failed');
    }
    _setUser('user-1');
  }

  @override
  Future<void> signOut() async => _setUser(null);

  /// Emails passed to [requestPasswordReset], in call order.
  final resetRequests = <String>[];

  /// (email, code, newPassword) tuples of successful confirmations.
  final confirmedResets = <(String, String, String)>[];

  /// Codes for which [confirmPasswordReset] throws (invalid/expired).
  final Set<String> failingCodes = {};

  @override
  Future<void> requestPasswordReset(String email) async {
    resetRequests.add(email);
  }

  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (failingCodes.contains(code)) {
      throw const AuthException('otp_expired');
    }
    confirmedResets.add((email, code, newPassword));
    _setUser('user-1');
  }
}
