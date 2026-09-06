// SPDX-License-Identifier: 0BSD
import 'package:deskilo/core/demo/demo_mode.dart';
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
