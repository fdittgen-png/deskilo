// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';

/// Delegates step navigation to the flow; only abandoning a draft asks first.
class WizardNavigation extends StatefulWidget {
  const WizardNavigation({super.key, required this.busy,
    required this.hasDraft, required this.discardMessage,
    required this.builder, this.onStepBack});
  final bool busy;
  final bool hasDraft;
  final String discardMessage;
  final VoidCallback? onStepBack;
  final Widget Function(VoidCallback back) builder;

  @override
  State<WizardNavigation> createState() => _WizardNavigationState();
}

class _WizardNavigationState extends State<WizardNavigation> {
  bool _asking = false;

  Future<void> _back() async {
    if (widget.busy || _asking) return;
    if (widget.onStepBack != null) { widget.onStepBack!(); return; }
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return;
    if (!widget.hasDraft) { navigator.pop(); return; }
    _asking = true;
    final l10n = AppLocalizations.of(context);
    final leave = await showDialog<bool>(context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n?.reportDesignerDiscardTitle ?? 'Leave without saving?'),
        content: Text(widget.discardMessage),
        actions: [
          TextButton(key: const ValueKey('wizard-keep-draft'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n?.reportDesignerKeepEditing ?? 'Keep editing')),
          TextButton(key: const ValueKey('wizard-discard-draft'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n?.reportDesignerDiscard ?? 'Discard')),
        ],
      ));
    _asking = false;
    if (mounted && leave == true) navigator.pop();
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: !widget.busy && widget.onStepBack == null && !widget.hasDraft,
    onPopInvokedWithResult: (didPop, _) { if (!didPop) _back(); },
    child: CallbackShortcuts(bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): _back,
    }, child: widget.builder(_back)),
  );
}
