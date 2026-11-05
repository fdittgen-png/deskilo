// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demo_reload_marker.dart';
import 'demo_reload_storage.dart';

/// The outer app owns the tab hint; Demo data remains in its own scope.
final demoReloadMarkerProvider = Provider<DemoReloadMarker?>(
  (ref) => createDemoReloadMarker(),
);
