// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2487 (S4 of #2483): the messenger windows are registry settings. The
// defaults reproduce today's literals, the shipped registry carries the
// bounds, and a changed value reaches the reader; the platform reader never
// takes a workspace override.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/settings/messaging_windows.dart';
import 'package:deskilo/core/settings/setting_defaults.g.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';

SettingsSet _settings([
  Map<String, Object> overrides = const {},
  SettingOrigin? origin,
]) {
  final rows = jsonDecode(
    File('assets/instance/settings_registry.json').readAsStringSync(),
  ) as List;
  final defs = [for (final r in rows) SettingDefinition.fromJson(r)];
  final base = SettingsSet.defaults(defs);
  return SettingsSet(
    base.definitions,
    {...base.effective, ...overrides},
    origins: {
      ...base.origins,
      if (origin != null)
        for (final k in overrides.keys) k: origin,
    },
  );
}

void main() {
  test('the registry defaults are the old literals', () {
    final w = MessagingWindows.fromSettings(_settings());
    expect(w.editWindow, const Duration(minutes: 15));
    expect(w.accountEditWindow, const Duration(minutes: 15));
    expect(w.threadPoll, const Duration(seconds: 15));
    expect(w.inboxPoll, const Duration(seconds: 30));
    expect(SettingDefaults.messagingEditWindowMinutes, 15);
    expect(MessagingWindows.defaults.threadPoll, w.threadPoll);
  });

  test('the shipped registry carries the bounds and scopes', () {
    final d = _settings().definitions;
    final edit = d['messaging.edit_window_minutes']!;
    expect([edit.min, edit.max], [1, 1440]);
    expect(edit.scopes, {SettingScope.platform, SettingScope.workspace});
    expect(
      [
        d['messaging.thread_poll_seconds']!.min,
        d['messaging.thread_poll_seconds']!.max,
      ],
      [5, 300],
    );
    expect(
      [
        d['messaging.inbox_poll_seconds']!.min,
        d['messaging.inbox_poll_seconds']!.max,
      ],
      [10, 600],
    );
    expect(edit.check(0), SettingProblem.belowMin);
    expect(edit.check(1441), SettingProblem.aboveMax);
    expect(
      d['messaging.thread_poll_seconds']!.check(4),
      SettingProblem.belowMin,
    );
    expect(
      d['messaging.inbox_poll_seconds']!.check(9),
      SettingProblem.belowMin,
    );
  });

  test('a changed value reaches the reader', () {
    final w = MessagingWindows.fromSettings(
      _settings({
        'messaging.edit_window_minutes': 30,
        'messaging.thread_poll_seconds': 60,
        'messaging.inbox_poll_seconds': 120,
      }, SettingOrigin.platform),
    );
    expect(w.editWindow, const Duration(minutes: 30));
    expect(w.accountEditWindow, const Duration(minutes: 30));
    expect(w.threadPoll, const Duration(seconds: 60));
    expect(w.inboxPoll, const Duration(seconds: 120));
  });

  test(
    'a workspace override moves the workspace window, never the account one',
    () {
      final w = MessagingWindows.fromSettings(
        _settings({
          'messaging.edit_window_minutes': 30,
        }, SettingOrigin.workspace),
      );
      expect(w.editWindow, const Duration(minutes: 30));
      expect(w.accountEditWindow, const Duration(minutes: 15));
    },
  );

  test('a registry that predates the keys keeps the defaults', () {
    final w = MessagingWindows.fromSettings(SettingsSet(const {}, const {}));
    expect(w.editWindow, MessagingWindows.defaults.editWindow);
    expect(w.threadPoll, MessagingWindows.defaults.threadPoll);
    expect(w.inboxPoll, MessagingWindows.defaults.inboxPoll);
  });
}
