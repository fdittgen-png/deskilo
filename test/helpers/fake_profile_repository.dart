// SPDX-License-Identifier: 0BSD
import 'package:deskilo/core/i18n/format_prefs.dart';
import 'dart:typed_data';

import 'package:deskilo/core/privacy/privacy_policy.dart';
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:deskilo/features/profile/domain/personal_info.dart';
import 'package:deskilo/features/profile/domain/profile_repository.dart';

import '../helpers/test_clock.dart';

/// In-memory [ProfileRepository] for widget/unit tests (#223).
class FakeProfileRepository implements ProfileRepository {
  @override
  Future<void> updateAddress(String address) async {
    if (failing) throw StateError('address write failed');
    final mine = _mine;
    if (mine != null) _replaceMine(mine.copyWith(address: address.trim()));
  }

  /// #886 — the last identity written, for assertions.
  PersonalInfo? lastPersonalInfo;

  @override
  Future<void> updatePersonalInfo(PersonalInfo info) async {
    final mine = _mine;
    if (mine == null) throw StateError('not signed in');
    final n = info.normalized();
    lastPersonalInfo = n;
    _replaceMine(mine.copyWith(
        identity: n, countryCode: n.countryCode, vatId: n.vatId));
  }

  @override
  Future<void> updateTaxIdentity({
    required String countryCode,
    required String vatId,
  }) async {
    if (failing) throw StateError('tax identity write failed');
    final mine = _mine;
    if (mine != null) {
      _replaceMine(mine.copyWith(
        countryCode: countryCode.trim().toUpperCase(),
        vatId: vatId.trim(),
      ));
    }
  }

  /// #751 — every seeded profile counts as having accepted the current
  /// policy unless [accepted] is false: the consent gate belongs to
  /// consent_test, not to every other widget test.
  FakeProfileRepository({
    List<Profile>? profiles,
    this.myUserId = 'user-1',
    bool accepted = true,
  }) : profiles = (profiles ??
            [
              // #751 — accepted, so the consent gate stays out of every
              // other test's way; consent_test seeds an unaccepted one.
              Profile(
                id: 'user-1',
                displayName: 'Test User',
                privacyAcceptedVersion: kPrivacyPolicyVersion,
                privacyAcceptedAt: DateTime.utc(2026, 8, 30),
              ),
            ])
            .map((p) => accepted && p.privacyAcceptedVersion == null
                ? p.copyWith(
                    privacyAcceptedVersion: kPrivacyPolicyVersion,
                    privacyAcceptedAt: DateTime.utc(2026, 8, 30),
                  )
                : p)
            .toList();

  final List<Profile> profiles;
  final String myUserId;

  /// When true, every write throws — for failure-path tests.
  bool failing = false;

  /// Number of [touchLastSeen] calls (heartbeat assertions).
  int touchCount = 0;

  /// #751 — versions accepted through [acceptPrivacyPolicy].
  final acceptedPolicyVersions = <String>[];

  @override
  Future<void> acceptPrivacyPolicy(String version) async {
    if (failing) throw StateError('failing');
    acceptedPolicyVersions.add(version);
    final mine = _mine;
    _replaceMine((mine ?? Profile(id: myUserId)).copyWith(
      privacyAcceptedVersion: version,
      privacyAcceptedAt: DateTime.utc(2026, 8, 30, 10),
    ));
  }

  Profile? get _mine {
    final index = profiles.indexWhere((p) => p.id == myUserId);
    return index == -1 ? null : profiles[index];
  }

  void _replaceMine(Profile updated) {
    final index = profiles.indexWhere((p) => p.id == myUserId);
    if (index == -1) {
      profiles.add(updated);
    } else {
      profiles[index] = updated;
    }
  }

  @override
  Future<Profile?> fetchMyProfile() async => _mine;

  @override
  Future<List<Profile>> fetchProfiles(List<String> userIds) async =>
      profiles.where((p) => userIds.contains(p.id)).toList();

  @override
  Future<void> updateWhatsapp(String whatsapp) async {
    if (failing) throw StateError('updateWhatsapp failing (test)');
    final mine = _mine ?? Profile(id: myUserId);
    _replaceMine(mine.copyWith(whatsapp: whatsapp));
  }


  @override
  Future<void> updateStatusText(String statusText) async {
    if (failing) throw StateError('updateStatusText failing (test)');
    final mine = _mine ?? Profile(id: myUserId);
    _replaceMine(mine.copyWith(statusText: statusText));
  }

  /// #496 — the last preferred-locale write.
  String preferredLocale = '';

  @override
  Future<void> setPreferredLocale(String locale) async {
    preferredLocale = locale;
  }

  /// #711 — the last saved format preferences, for assertions.
  FormatPrefs formatPrefs = FormatPrefs.defaults;

  @override
  Future<void> setFormatPrefs(FormatPrefs prefs) async {
    formatPrefs = prefs;
    final updated = [for (final p in profiles) p.copyWith(formatPrefs: prefs)];
    profiles
      ..clear()
      ..addAll(updated);
  }

  @override
  Future<void> touchLastSeen() async {
    if (failing) throw StateError('touchLastSeen failing (test)');
    touchCount += 1;
    final mine = _mine ?? Profile(id: myUserId);
    _replaceMine(mine.copyWith(lastSeenAt: kTestNow.toUtc()));
  }

  /// userId → avatar bytes, seeded by tests or written by [setAvatar].
  final avatarBytes = <String, Uint8List>{};

  @override
  Future<void> setAvatar({
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (failing) throw StateError('setAvatar failing (test)');
    avatarBytes[myUserId] = bytes;
    final mine = _mine ?? Profile(id: myUserId);
    _replaceMine(mine.copyWith(avatarPath: '$myUserId/avatar'));
  }

  @override
  Future<void> clearAvatar() async {
    if (failing) throw StateError('clearAvatar failing (test)');
    avatarBytes.remove(myUserId);
    final index = profiles.indexWhere((p) => p.id == myUserId);
    if (index != -1) {
      final mine = profiles[index];
      profiles[index] = Profile(
        id: mine.id,
        displayName: mine.displayName,
        whatsapp: mine.whatsapp,
        statusText: mine.statusText,
        lastSeenAt: mine.lastSeenAt,
        // avatarPath deliberately dropped — copyWith can't null it.
      );
    }
  }

  @override
  Future<Uint8List?> fetchAvatarBytes(String userId) async =>
      avatarBytes[userId];
}
