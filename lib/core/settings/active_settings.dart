// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings.dart';

/// The settings snapshot of the active workspace, for code that reads a
/// window or a limit without importing the workspace feature (#2486). Null
/// until the composition root puts the live snapshot in its scope's
/// overrides (`activeSettingsFromWorkspace`); readers then use the
/// registry defaults.
final activeSettingsProvider = Provider<SettingsSet?>((ref) => null);
