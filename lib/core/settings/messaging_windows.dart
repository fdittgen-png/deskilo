// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2487 (S4 of #2483) -- the windows the messenger reads: how long the author
// may correct a message and how often an open conversation and the inbox
// refresh. Registry values (`messaging.edit_window_minutes`,
// `messaging.thread_poll_seconds`, `messaging.inbox_poll_seconds`); the
// defaults are the registry's own. A timer setting says how often a visible
// view asks; it does not stop a hidden view's timer or hide a read mark.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'active_settings.dart';
import 'setting_defaults.g.dart';
import 'settings.dart';

class MessagingWindows {
  const MessagingWindows({
    this.editWindow = const Duration(
      minutes: SettingDefaults.messagingEditWindowMinutes,
    ),
    this.accountEditWindow = const Duration(
      minutes: SettingDefaults.messagingEditWindowMinutes,
    ),
    this.threadPoll = const Duration(
      seconds: SettingDefaults.messagingThreadPollSeconds,
    ),
    this.inboxPoll = const Duration(
      seconds: SettingDefaults.messagingInboxPollSeconds,
    ),
  });

  static const defaults = MessagingWindows();

  /// The edit window of a message that belongs to the active workspace.
  final Duration editWindow;

  /// The edit window of a personal, group or inquiry message: the platform
  /// value, never the selected workspace's override (the server reads the
  /// platform row for these). When the active workspace overrides the key the
  /// platform value is not in the snapshot, so the registry default stands.
  final Duration accountEditWindow;

  final Duration threadPoll;
  final Duration inboxPoll;

  /// A registry that predates a key (an older server) keeps its default.
  factory MessagingWindows.fromSettings(SettingsSet settings) {
    const edit = 'messaging.edit_window_minutes';
    const thread = 'messaging.thread_poll_seconds';
    const inbox = 'messaging.inbox_poll_seconds';
    final hasEdit = settings.definitions.containsKey(edit);
    final editMinutes = hasEdit
        ? settings.read<int>(edit)
        : SettingDefaults.messagingEditWindowMinutes;
    return MessagingWindows(
      editWindow: Duration(minutes: editMinutes),
      accountEditWindow: Duration(
        minutes: hasEdit && settings.originOf(edit) == SettingOrigin.workspace
            ? SettingDefaults.messagingEditWindowMinutes
            : editMinutes,
      ),
      threadPoll: Duration(
        seconds: settings.definitions.containsKey(thread)
            ? settings.read<int>(thread)
            : SettingDefaults.messagingThreadPollSeconds,
      ),
      inboxPoll: Duration(
        seconds: settings.definitions.containsKey(inbox)
            ? settings.read<int>(inbox)
            : SettingDefaults.messagingInboxPollSeconds,
      ),
    );
  }
}

/// #2487 -- the messenger windows; the registry defaults stand while the
/// settings load or when they cannot be reached.
final messagingWindowsProvider = Provider<MessagingWindows>((ref) {
  final settings = ref.watch(activeSettingsProvider);
  return settings == null
      ? MessagingWindows.defaults
      : MessagingWindows.fromSettings(settings);
});
