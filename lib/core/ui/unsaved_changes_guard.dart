// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3072 — a form with a Save asks before it is left with edits that were
// never saved, and asks only then. One guard for every screen of that kind,
// so the question, its two answers and the moment it is asked do not differ
// per screen.
import 'package:flutter/material.dart';

import '../l10n/context_l10n.dart';

/// Wraps a screen: while [isDirty] says so, leaving it (back button, back
/// gesture, route pop) first asks "Leave with unsaved changes?"; clean, it
/// leaves at once. "Keep editing" stays, "Discard changes" leaves.
///
/// A screen whose fields live in controllers does not rebuild when one is
/// typed in: it passes them as [refreshOn], and only this guard (never the
/// [child]) is rebuilt with each change.
class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({
    required this.isDirty,
    required this.child,
    this.refreshOn,
    super.key,
  });

  /// Whether the screen holds edits that were not saved.
  final bool Function() isDirty;
  final Listenable? refreshOn;
  final Widget child;

  Widget _scope(BuildContext context, Widget? child) => PopScope<Object?>(
    canPop: !isDirty(),
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop) return;
      final navigator = Navigator.of(context);
      if (await _confirmDiscardChanges(context) && navigator.mounted) {
        navigator.pop(result);
      }
    },
    child: child!,
  );

  @override
  Widget build(BuildContext context) {
    final listenable = refreshOn;
    if (listenable == null) return _scope(context, child);
    return ListenableBuilder(
      listenable: listenable,
      builder: _scope,
      child: child,
    );
  }
}

/// The question: true when the person chose to leave and drop the
/// changes, false on "Keep editing" or when the question was dismissed.
Future<bool> _confirmDiscardChanges(BuildContext context) async {
  final l10n = context.l10n;
  final leave = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const ValueKey('unsaved-changes-dialog'),
      title: Text(l10n.unsavedChangesTitle),
      content: Text(l10n.unsavedChangesBody),
      actions: [
        TextButton(
          key: const ValueKey('unsaved-changes-keep'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.unsavedChangesKeep),
        ),
        FilledButton(
          key: const ValueKey('unsaved-changes-discard'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.unsavedChangesDiscard),
        ),
      ],
    ),
  );
  return leave ?? false;
}
