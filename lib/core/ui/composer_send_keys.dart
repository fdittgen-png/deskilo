// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Whether an input method is still composing a word in [value] (a
/// candidate being chosen): no key sends or submits then. The one check for
/// the message composer and the form kit.
bool isComposingText(TextEditingValue value) => value.composing.isValid;

/// The keys of a message composer around its multiline [child] field:
/// Return inserts a newline (the field's own behaviour, never a send);
/// Ctrl+Enter or Cmd+Enter sends through [onSend], the same command the
/// Send button runs; and while an input method is still composing a word
/// (a candidate being chosen), nothing sends.
class ComposerSendKeys extends StatelessWidget {
  const ComposerSendKeys({
    super.key,
    required this.controller,
    required this.onSend,
    required this.child,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final Widget child;

  void _send() {
    if (isComposingText(controller.value)) return;
    onSend();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      for (final key in const [
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.numpadEnter,
      ]) ...{
        SingleActivator(key, control: true): _send,
        SingleActivator(key, meta: true): _send,
      },
    },
    child: child,
  );
}
