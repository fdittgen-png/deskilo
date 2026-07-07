// SPDX-License-Identifier: MIT
import 'dart:async';

import 'package:deskilo/features/auth/domain/auth_repository.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:flutter_riverpod/misc.dart';

/// In-memory [AuthRepository] for widget/unit tests (fakes over mocks).
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({String? userId}) : _userId = userId;

  FakeAuthRepository.signedIn() : this(userId: 'user-1');

  String? _userId;
  final _controller = StreamController<String?>.broadcast();

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
      throw StateError('invalid credentials');
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
      throw StateError('sign up failed');
    }
    _setUser('user-1');
  }

  @override
  Future<void> signOut() async => _setUser(null);
}

/// Baseline overrides for widget tests: a signed-in user. Always start from
/// these and add feature-specific overrides on top.
List<Override> standardTestOverrides({AuthRepository? auth}) {
  return [
    authRepositoryProvider
        .overrideWithValue(auth ?? FakeAuthRepository.signedIn()),
  ];
}
