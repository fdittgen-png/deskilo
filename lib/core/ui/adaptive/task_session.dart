// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3608 (desk K3) — the session of a task and the host that watches it. A
// task is a popup route (a sheet, a dialog or a side panel, task_surface.dart)
// or a page of its own (long_task_page.dart); either way its body sits in a
// [TaskSessionHost], which is what makes leaving typed work ask.
//
// While the session holds a change ([TaskSession.markChanged]: the text of a
// field inside the task differs from what it showed when first focused,
// however it arrived — a key, the soft keyboard, dictation, autofill, a paste
// — or one of the form kit's choices was changed), every way out asks first
// — Escape, the scrim, a drag, the back button and the body's own Cancel or
// Close — with the one discard question. Only a completed submit
// ([TaskSession.completed]) takes the mark away.
//
// A task ends with its context: when the signed-in person or the workspace
// changes (sign-out, an expired session, a switch of business —
// `taskContextTokenProvider`), the host calls its `onContextChanged` and the
// route is closed at once and without a question. The work was the previous
// context's; showing it to the next person or business would be the loss.
import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../session/task_context.dart';
import '../unsaved_changes_guard.dart';

/// How much a task holds, which decides its container.
enum TaskSize {
  /// A few fields: a centred dialog at the desk; Enter submits it.
  short,

  /// A form: a side panel at the desk, the page behind it readable.
  standard,

  /// More than a panel holds: a page of its own with the form in its column
  /// and a summary beside it (a deep link, the browser's back).
  long,
}

/// One open task: its size, and whether something in it was changed.
class TaskSession {
  TaskSession(this.size);

  final TaskSize size;
  final ValueNotifier<bool> _changed = ValueNotifier(false);

  /// Whether something in the task was changed since it opened.
  bool get changed => _changed.value;

  /// Tells whenever [changed] flips.
  ValueListenable<bool> get changes => _changed;

  /// Records a change: every way out now asks before the task is left.
  void markChanged() => _changed.value = true;

  /// The form's submit completed: what was typed is kept, leaving asks no
  /// more.
  void completed() => _changed.value = false;

  /// The session [context] is part of; null outside a task.
  static TaskSession? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_TaskSessionScope>()?.session;
}

class _TaskSessionScope extends InheritedWidget {
  const _TaskSessionScope({required this.session, required super.child});

  final TaskSession session;

  @override
  bool updateShouldNotify(_TaskSessionScope oldWidget) =>
      !identical(session, oldWidget.session);
}

/// Hosts a task's body: gives it its [session], follows the text fields in
/// it, asks before a changed task is left, and reports a change of context.
class TaskSessionHost extends StatefulWidget {
  const TaskSessionHost({
    required this.session,
    required this.onContextChanged,
    required this.child,
    super.key,
  });

  final TaskSession session;

  /// The signed-in person or the workspace changed: close the task.
  final VoidCallback onContextChanged;
  final Widget child;

  @override
  State<TaskSessionHost> createState() => _TaskSessionHostState();
}

class _TaskSessionHostState extends State<TaskSessionHost> {
  ProviderSubscription<String>? _context;

  /// The text field followed now: the focused one inside this task.
  TextEditingController? _followed;

  /// The text each field showed when it was first followed.
  final Expando<String> _firstText = Expando('task-first-text');

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_focusMoved);
  }

  /// The focus moved: follow the text field it is in, when that field is
  /// part of this task.
  void _focusMoved() {
    final focused = FocusManager.instance.primaryFocus?.context;
    final field = focused?.findAncestorWidgetOfExactType<EditableText>();
    final mine =
        field != null &&
        identical(
          focused!.findAncestorStateOfType<_TaskSessionHostState>(),
          this,
        );
    final next = mine && !field.readOnly ? field.controller : null;
    if (identical(next, _followed)) return;
    _followed?.removeListener(_textChanged);
    _followed = next;
    if (next == null) return;
    // The text a field shows when it is first followed is its baseline: a
    // prefilled field that is focused and left alone is not a change. Text
    // that code puts into a field WHILE it is focused (a default arriving
    // late) counts as a change; that errs toward asking.
    _firstText[next] ??= next.text;
    next.addListener(_textChanged);
  }

  /// The followed field's text differs from what it first showed: a change.
  void _textChanged() {
    final field = _followed;
    if (field != null && field.text != _firstText[field]) {
      widget.session.markChanged();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_context != null) return;
    final ProviderContainer providers;
    try {
      providers = ProviderScope.containerOf(context, listen: false);
    } on StateError {
      return; // A task shown without the app's providers (a bare widget).
    }
    final opened = providers.read(taskContextTokenProvider);
    _context = providers.listen(taskContextTokenProvider, (_, next) {
      if (next != opened) scheduleMicrotask(widget.onContextChanged);
    });
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_focusMoved);
    _followed?.removeListener(_textChanged);
    _context?.close();
    super.dispose();
  }

  /// A way out was refused because the task holds a change: ask, and leave
  /// with what was being popped when the person discards.
  Future<void> _leave(bool didPop, Object? result) async {
    if (didPop) return;
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    if (await confirmDiscardChanges(context)) {
      if (navigator.mounted && (route?.isActive ?? true)) {
        navigator.pop(result);
      }
    }
  }

  @override
  Widget build(BuildContext context) => _TaskSessionScope(
    session: widget.session,
    child: ValueListenableBuilder<bool>(
      valueListenable: widget.session.changes,
      builder: (context, changed, child) => PopScope<Object?>(
        canPop: !changed,
        onPopInvokedWithResult: _leave,
        child: child!,
      ),
      child: widget.child,
    ),
  );
}
