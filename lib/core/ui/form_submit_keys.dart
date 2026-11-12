// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3608 (desk K3) — the keys that submit a form: Ctrl/Cmd+Enter any form,
// plain Enter a short task's form from a one-line field. Both run the form's
// own guarded submit (which runs once while busy). A word still being
// composed, a multi-line field's Return and Enter on a button are left to
// the field and the button; an event taken here is consumed, so no outer
// scope submits it again.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'adaptive/task_surface.dart';
import 'composer_send_keys.dart';

/// Submits the form around [child] through [onSubmit] from the keyboard.
class FormSubmitKeys extends StatelessWidget {
  const FormSubmitKeys({
    super.key,
    required this.onSubmit,
    required this.child,
  });

  final Future<void> Function() onSubmit;
  final Widget child;

  /// The text field that has the focus, if one has.
  static EditableText? _focusedText() => FocusManager
      .instance
      .primaryFocus
      ?.context
      ?.findAncestorWidgetOfExactType<EditableText>();

  KeyEventResult _onKey(BuildContext context, KeyEvent event) {
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    final chord = keyboard.isControlPressed || keyboard.isMetaPressed;
    final field = _focusedText();
    if (field != null && isComposingText(field.controller.value)) {
      return KeyEventResult.ignored;
    }
    final short = TaskSession.maybeOf(context)?.size == TaskSize.short;
    if (!chord && (!short || field == null || field.maxLines != 1)) {
      return KeyEventResult.ignored;
    }
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (event is KeyDownEvent) unawaited(onSubmit());
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onKeyEvent: (node, event) => _onKey(context, event),
    child: child,
  );
}
