// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2552 XPRIV-01 — one private value (an amount, a preview), masked until
// the person reveals it. While masked, the value is not built at all: its
// text is in no tooltip, no semantics node and no selection, so it cannot
// be read aloud or copied. A screen reader hears a generic "hidden" label
// and a reveal action. Revealing shows this value alone; the same action
// hides it again. When the person chose to show private values
// (core/privacy/private_values.dart), the value is shown plainly.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/context_l10n.dart';
import '../privacy/private_values.dart';

class PrivateValue extends ConsumerStatefulWidget {
  const PrivateValue({
    super.key,
    required this.child,
    this.maskedText = privateValueMask,
    this.hiddenLabel,
    this.showLabel,
    this.hideLabel,
    this.revealKey,
    this.onlyWhereOffered = false,
  });

  /// The value, built only while it is shown.
  final Widget child;

  /// What stands in its place while masked: never derived from the value
  /// beyond what is not private (a currency code, say).
  final String maskedText;

  /// What a screen reader hears while masked; generic by default.
  final String? hiddenLabel;

  /// The reveal and hide actions' names; generic by default.
  final String? showLabel;
  final String? hideLabel;

  /// The key of the reveal button, for tests and the task recorder.
  final Key? revealKey;

  /// True for a value that was always shown before the choice existed (a
  /// message preview, a contact detail): it is masked only where the
  /// choice is offered, and reads as before elsewhere. False keeps a
  /// value masked even where the choice is not offered (an amount).
  final bool onlyWhereOffered;

  @override
  ConsumerState<PrivateValue> createState() => _PrivateValueState();
}

class _PrivateValueState extends ConsumerState<PrivateValue> {
  bool _shown = false;

  void _toggle() => setState(() => _shown = !_shown);

  @override
  Widget build(BuildContext context) {
    // Masking turned back on hides what was revealed under the old choice.
    ref.listen(privateValuesMaskedProvider, (_, masked) {
      if (masked && _shown) setState(() => _shown = false);
    });
    if (widget.onlyWhereOffered &&
        !ref.watch(privateValuesPolicyProvider).enabled) {
      return widget.child;
    }
    if (!ref.watch(privateValuesMaskedProvider)) return widget.child;
    final l10n = context.l10n;
    final style = TextButton.styleFrom(minimumSize: const Size(48, 48));
    if (_shown) {
      final hide = widget.hideLabel ?? l10n.privateValueHide;
      return Tooltip(
        message: hide,
        excludeFromSemantics: true,
        child: Semantics(
          onTapHint: hide,
          child: TextButton(
            key: widget.revealKey,
            style: style,
            onPressed: _toggle,
            child: widget.child,
          ),
        ),
      );
    }
    final show = widget.showLabel ?? l10n.privateValueShow;
    return Tooltip(
      message: show,
      excludeFromSemantics: true,
      child: Semantics(
        container: true,
        button: true,
        label: widget.hiddenLabel ?? l10n.privateValueHidden,
        onTapHint: show,
        onTap: _toggle,
        excludeSemantics: true,
        child: TextButton(
          key: widget.revealKey,
          style: style,
          onPressed: _toggle,
          child: Text(widget.maskedText),
        ),
      ),
    );
  }
}
