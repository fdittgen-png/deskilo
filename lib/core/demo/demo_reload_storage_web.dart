// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:web/web.dart' as web;

import 'demo_reload_marker.dart';

const _key = 'deskilo.demo.visit.v1';

class _TabStorage implements DemoReloadMarkerStorage {
  const _TabStorage();
  @override
  String? read() => web.window.sessionStorage.getItem(_key);

  @override
  void write(String value) => web.window.sessionStorage.setItem(_key, value);

  @override
  void clear() => web.window.sessionStorage.removeItem(_key);
}

DemoReloadMarker createDemoReloadMarker() =>
    const DemoReloadMarker(_TabStorage());
