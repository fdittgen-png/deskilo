// SPDX-License-Identifier: 0BSD
import 'package:deskilo/core/demo/demo_mode.dart';
import 'package:deskilo/app/shell/shell_bar_visibility.dart';
import 'package:deskilo/core/navigation/navigation_style.dart';

/// In-memory stores for the per-device preferences (#969, #970), so no
/// widget test touches SharedPreferences and every provider that watches
/// them resolves at once.
class InMemoryDemoModeStore implements DemoModeStore {
  InMemoryDemoModeStore({this.value});
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? value) async => this.value = value;
}

class InMemoryNavigationStyleStore implements NavigationStyleStore {
  InMemoryNavigationStyleStore({this.style});
  String? style;
  @override
  Future<String?> read() async => style;
  @override
  Future<void> write(String? style) async => this.style = style;
}

/// #1173 — the two shell flags (bar swiped away, swipe hint seen).
class InMemoryShellFlagStore implements ShellFlagStore {
  InMemoryShellFlagStore([this.value = false]);

  bool value;

  /// How many times the flag was written — the proof a choice persists.
  int writes = 0;

  @override
  Future<bool> read() async => value;

  @override
  Future<void> write(bool next) async {
    value = next;
    writes++;
  }
}
