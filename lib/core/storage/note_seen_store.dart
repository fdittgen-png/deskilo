// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'prefs_stores.dart';

part 'note_seen_store.g.dart';

/// Per-device member-note read state (#464). Two independent stamps:
///
///  * NOTIFIED — the newest note the device has already raised a
///    system notification for. Advances whenever notifications fire,
///    so a note is announced exactly once per device — including the
///    CATCH-UP case: notes that arrived while the app was closed are
///    announced on next start (no push endpoint exists without the
///    owner's Firebase setup, so this is the only closed-app path).
///  * SEEN — the newest note the user has actually looked at (the
///    Events screen marks it on open). Drives the unread counters on
///    the bell and the app icon.
abstract class NoteSeenStore {
  Future<DateTime?> readNotified();
  Future<void> writeNotified(DateTime value);
  Future<DateTime?> readSeen();
  Future<void> writeSeen(DateTime value);
}

class PrefsNoteSeenStore implements NoteSeenStore {
  const PrefsNoteSeenStore();

  static const _notified = PrefsStringStore('member_notes_notified_until');
  static const _seen = PrefsStringStore('member_notes_seen_until');

  @override
  Future<DateTime?> readNotified() async =>
      DateTime.tryParse(await _notified.read() ?? '');

  @override
  Future<void> writeNotified(DateTime value) =>
      _notified.write(value.toUtc().toIso8601String());

  @override
  Future<DateTime?> readSeen() async =>
      DateTime.tryParse(await _seen.read() ?? '');

  @override
  Future<void> writeSeen(DateTime value) =>
      _seen.write(value.toUtc().toIso8601String());
}

/// Test double — also handy for platforms without SharedPreferences.
class InMemoryNoteSeenStore implements NoteSeenStore {
  DateTime? notified;
  DateTime? seen;

  @override
  Future<DateTime?> readNotified() async => notified;
  @override
  Future<void> writeNotified(DateTime value) async => notified = value;
  @override
  Future<DateTime?> readSeen() async => seen;
  @override
  Future<void> writeSeen(DateTime value) async => seen = value;
}

@Riverpod(keepAlive: true)
NoteSeenStore noteSeenStore(Ref ref) => const PrefsNoteSeenStore();
