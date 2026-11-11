// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3679 -- the kit's action button owns "busy while it runs", so no screen
// can forget it: a second tap while the action runs does nothing, the button
// is enabled again when the action completes (also when it throws), and the
// busy state is announced to assistive technology. A screen with its own
// busy state passes [busy]; the default protects everyone else.
import 'package:flutter/material.dart';

import '../../l10n/context_l10n.dart';
import 'kit_metrics.dart';

class KitActionButton extends StatefulWidget {
  const KitActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tonal = false,
    this.busy = false,
    this.showProgress = true,
  });

  final String label;

  /// The action. Null disables the button. The button is busy until the
  /// returned future completes, success or error.
  final Future<void> Function()? onPressed;

  /// A tonal button (a quieter action) instead of the filled main one.
  final bool tonal;

  /// A busy state the screen already keeps; it adds to the button's own.
  final bool busy;

  /// Whether the busy state draws the progress mark. An action that opens a
  /// dialog and waits for the person keeps the button busy without an endless
  /// animation: pass false there; the button is disabled all the same.
  final bool showProgress;

  @override
  State<KitActionButton> createState() => _KitActionButtonState();
}

class _KitActionButtonState extends State<KitActionButton> {
  bool _running = false;

  bool get _busy => _running || widget.busy;

  Future<void> _press() async {
    if (_busy) return;
    final action = widget.onPressed;
    if (action == null) return;
    setState(() => _running = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !_busy;
    final child = _busy && widget.showProgress
        ? Row(
            mainAxisSize: MainAxisSize.min,
            spacing: KitMetrics.buttonGap,
            children: [
              const SizedBox.square(
                dimension: KitMetrics.progressMark,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              Flexible(child: Text(widget.label)),
            ],
          )
        : Text(widget.label);
    final onPressed = enabled ? _press : null;
    return Semantics(
      liveRegion: true,
      label: _busy ? context.l10n.kitActionBusy : null,
      child: widget.tonal
          ? FilledButton.tonal(onPressed: onPressed, child: child)
          : FilledButton(onPressed: onPressed, child: child),
    );
  }
}
