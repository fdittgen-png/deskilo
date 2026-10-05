// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Pin and archive for the Me messenger: a person's own marks on their
// conversations, kept on this device (like the help hints). Muting needs the
// server (it silences pushes) and is not offered here.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/trace/trace_logger.dart';

class InboxMarksState {
  const InboxMarksState({this.pinned = const {}, this.archived = const {}});
  final Set<String> pinned;
  final Set<String> archived;

  InboxMarksState copyWith({Set<String>? pinned, Set<String>? archived}) =>
      InboxMarksState(
        pinned: pinned ?? this.pinned,
        archived: archived ?? this.archived,
      );
}

/// The marks, by conversation key (`source|kind|contextId`).
class InboxMarks extends Notifier<InboxMarksState> {
  static const _pinnedKey = 'inbox_pinned';
  static const _archivedKey = 'inbox_archived';

  @override
  InboxMarksState build() {
    _load();
    return const InboxMarksState();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = InboxMarksState(
        pinned: (prefs.getStringList(_pinnedKey) ?? const <String>[]).toSet(),
        archived:
            (prefs.getStringList(_archivedKey) ?? const <String>[]).toSet(),
      );
    } catch (e, st) {
      TraceLogger.instance.warn('messenger', 'inbox marks unreadable',
          error: e, stackTrace: st);
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_pinnedKey, state.pinned.toList()..sort());
      await prefs.setStringList(_archivedKey, state.archived.toList()..sort());
    } catch (e, st) {
      TraceLogger.instance.warn('messenger', 'inbox marks not saved',
          error: e, stackTrace: st);
    }
  }

  void togglePin(String key) {
    final next = {...state.pinned};
    if (!next.remove(key)) next.add(key);
    state = state.copyWith(pinned: next);
    _save();
  }

  void toggleArchive(String key) {
    final next = {...state.archived};
    if (!next.remove(key)) next.add(key);
    state = state.copyWith(archived: next);
    _save();
  }
}

final inboxMarksProvider =
    NotifierProvider<InboxMarks, InboxMarksState>(InboxMarks.new);
