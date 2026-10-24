// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings.dart';

/// The settings snapshot of the active workspace, for code that reads a
/// window or a limit without importing the workspace feature (#2486). Null
/// until the composition root puts the live snapshot in its scope's
/// overrides (`activeSettingsFromWorkspace`); readers then use the
/// registry defaults.
final activeSettingsProvider = Provider<SettingsSet?>((ref) => null);

/// #2553 C2 -- the personal home's platform settings (the registry's
/// platform scope with no workspace) for the signed-in person, for code
/// that reads them without importing the workspace feature. Null until the
/// composition root puts `platformSettingsFromWorkspace` in its scope's
/// overrides, and null signed out: no literal stands in for them.
final platformSettingsProvider = FutureProvider<SettingsSet?>((ref) async => null);
