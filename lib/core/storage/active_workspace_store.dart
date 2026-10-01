// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'prefs_stores.dart';


part 'active_workspace_store.g.dart';

/// Persists which workspace (profile) is active across restarts (#89).
///
/// #1823 — per ACCOUNT. The key used to be device-global, so the next
/// person to sign in on a shared device opened in the previous person's
/// last space whenever they were a member of it too. Every read and
/// write now names the account it is about; `signOutAndForget` clears
/// the leaving account's entry.
abstract class ActiveWorkspaceStore {
  Future<String?> read(String account);
  Future<void> write(String account, String? workspaceId);
}

/// The device-global key every build before #1823 wrote. Never read
/// again: a write for any account removes it, and so does a sign-out.
const String legacyActiveWorkspaceKey = 'active_workspace_id';

/// The device-global default-profile cache before #1823.
const String legacyDefaultWorkspaceKey = 'default_workspace_id';

class PrefsActiveWorkspaceStore implements ActiveWorkspaceStore {
  const PrefsActiveWorkspaceStore();

  PrefsStringStore _of(String account) =>
      PrefsStringStore('$legacyActiveWorkspaceKey.$account');

  @override
  Future<String?> read(String account) => _of(account).read();

  @override
  Future<void> write(String account, String? workspaceId) async {
    await _of(account).write(workspaceId);
    await const PrefsStringStore(legacyActiveWorkspaceKey).write(null);
  }
}

@Riverpod(keepAlive: true)
ActiveWorkspaceStore activeWorkspaceStore(Ref ref) =>
    const PrefsActiveWorkspaceStore();

/// Persists the user-chosen DEFAULT profile (#322): the workspace the
/// app opens on at every start, regardless of what was active last.
/// Null = no default — the last active profile wins (the #89 behavior).
///
/// It is an offline cache of `profiles.default_workspace_id` (#458), and
/// since #1823 it is kept per account like [ActiveWorkspaceStore]: a
/// cached server answer belongs to the person the server gave it to.
abstract class DefaultWorkspaceStore {
  Future<String?> read(String account);
  Future<void> write(String account, String? workspaceId);
}

class PrefsDefaultWorkspaceStore implements DefaultWorkspaceStore {
  const PrefsDefaultWorkspaceStore();

  PrefsStringStore _of(String account) =>
      PrefsStringStore('$legacyDefaultWorkspaceKey.$account');

  @override
  Future<String?> read(String account) => _of(account).read();

  @override
  Future<void> write(String account, String? workspaceId) async {
    await _of(account).write(workspaceId);
    await const PrefsStringStore(legacyDefaultWorkspaceKey).write(null);
  }
}

@Riverpod(keepAlive: true)
DefaultWorkspaceStore defaultWorkspaceStore(Ref ref) =>
    const PrefsDefaultWorkspaceStore();
