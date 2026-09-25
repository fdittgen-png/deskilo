// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';

/// Connects the existing router's exit callback to the mounted flow.
class WizardNavigationController {
  Future<bool> Function()? _onExit;
  bool completed = false;
  Future<bool> requestExit() async => completed || await (_onExit?.call() ?? Future.value(true));
}

/// Delegates step navigation to the flow; only abandoning a draft asks first.
class WizardNavigation extends StatefulWidget {
  const WizardNavigation({super.key, required this.busy,
    required this.hasDraft, required this.discardMessage,
    required this.builder, this.onStepBack, this.controller});
  final WizardNavigationController? controller;
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
  bool _leaving = false;
  @override
  void initState() { super.initState(); _attach(); }
  void _attach() { widget.controller?..completed = false.._onExit = _allowExit; }
  @override
  void didUpdateWidget(WizardNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._onExit = null; _attach();
    }
  }
  @override
  void dispose() { widget.controller?._onExit = null; super.dispose(); }


  Future<void> _back() async {
    final navigator = Navigator.of(context);
    if (!navigator.canPop() && widget.onStepBack == null) return;
    if (await _allowExit() && mounted) navigator.pop();
  }

  Future<bool> _allowExit() async {
    if (_leaving || widget.controller?.completed == true) return true;
    if (widget.busy || _asking) return false;
    if (widget.onStepBack != null) { widget.onStepBack!(); return false; }
    if (!widget.hasDraft) { _leaving = true; return true; }
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
    _leaving = mounted && leave == true;
    return _leaving;
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
