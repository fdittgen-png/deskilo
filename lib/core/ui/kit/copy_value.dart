// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3611 — a value people copy (an invoice number, an amount, an address)
// carries a visible copy button while a mouse is the pointer.
//
// Privacy (#2552): the button is built beside the value, in the same
// subtree. Put a [CopyValue] INSIDE a `PrivateValue`'s child, so a masked
// value builds neither the text nor the button and no raw value waits in
// a callback; hiding the value again removes the copy path with it.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/context_l10n.dart';
import '../app_snack.dart';
import '../mouse_presence.dart';

/// A copy button beside [value] (the value as shown).
class CopyValueButton extends StatelessWidget {
  const CopyValueButton({super.key, required this.value});

  /// What the button puts on the clipboard.
  final String value;

  /// The button's side: a mouse's row height, not a finger's.
  static const double size = 36;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return IconButton(
      tooltip: l10n.kitCopy,
      iconSize: 18,
      constraints: const BoxConstraints.tightFor(width: size, height: size),
      padding: EdgeInsets.zero,
      icon: Semantics(
        label: l10n.kitCopyValue(value),
        excludeSemantics: true,
        child: const Icon(Icons.copy_outlined),
      ),
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: value));
        if (!context.mounted) return;
        AppSnack.success(context, l10n.kitCopied);
      },
    );
  }
}

/// [child] (the value drawn) with a [CopyValueButton] after it, shown only
/// while a mouse is connected: a phone in the hand keeps its layout.
class CopyValue extends StatelessWidget {
  const CopyValue({super.key, required this.value, required this.child});

  /// What is copied: the value exactly as [child] shows it.
  final String value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MousePresence(
      builder: (context, mouse, _) {
        if (!mouse) return child;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: child),
            CopyValueButton(
              key: const ValueKey('copy-value-button'),
              value: value,
            ),
          ],
        );
      },
    );
  }
}
