// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/widgets.dart';

/// Builds a thread's composer from its seed (the text it opens with), what
/// it reports as the person types, and its send (true: the field empties).
typedef ComposerBuild = Widget Function(
  String? seed,
  ValueChanged<String> onChanged,
  Future<bool> Function(String body) onSend,
);

/// Puts a thread's own composer under the messenger's draft and delivery
/// rules: [attempt] is the thread's send, [build] its composer.
typedef ComposerFrame = Widget Function(
  Future<bool> Function(String body) attempt,
  ComposerBuild build,
);
