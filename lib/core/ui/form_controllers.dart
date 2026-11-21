// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/widgets.dart';

/// The text controllers of one form: asked for by name, created on first
/// use, disposed together.
///
/// ```dart
/// final fields = FormControllers({'name': profile.name});
/// AppTextField(controller: fields['name'], label: …);
/// fields.text('name'); // trimmed
/// fields.dispose();    // once, in the State's dispose
/// ```
class FormControllers {
  FormControllers([Map<String, String> initial = const {}]) {
    initial.forEach(
      (key, value) => _all[key] = TextEditingController(text: value),
    );
  }

  final Map<String, TextEditingController> _all = {};
  bool _disposed = false;

  /// The controller of [key], created empty the first time it is asked for.
  TextEditingController operator [](String key) {
    assert(!_disposed, 'FormControllers used after dispose');
    return _all.putIfAbsent(key, TextEditingController.new);
  }

  /// The trimmed text of [key].
  String text(String key) => this[key].text.trim();

  /// Every field's trimmed text, by key.
  Map<String, String> get values => {
    for (final e in _all.entries) e.key: e.value.text.trim(),
  };

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final c in _all.values) {
      c.dispose();
    }
    _all.clear();
  }
}
