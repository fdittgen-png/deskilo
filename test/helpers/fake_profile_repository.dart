// SPDX-License-Identifier: MIT
import 'dart:typed_data';

import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:deskilo/features/profile/domain/profile_repository.dart';

/// In-memory [ProfileRepository] for widget/unit tests (#223).
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({List<Profile>? profiles, this.myUserId = 'user-1'})
      : profiles = profiles ??
            [const Profile(id: 'user-1', displayName: 'Test User')];

  final List<Profile> profiles;
  final String myUserId;

  /// When true, every write throws — for failure-path tests.
  bool failing = false;

  /// Number of [touchLastSeen] calls (heartbeat assertions).
  int touchCount = 0;

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

  @override
  Future<void> touchLastSeen() async {
    if (failing) throw StateError('touchLastSeen failing (test)');
    touchCount += 1;
    final mine = _mine ?? Profile(id: myUserId);
    _replaceMine(mine.copyWith(lastSeenAt: DateTime.now().toUtc()));
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
