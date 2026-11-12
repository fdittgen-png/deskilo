// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3608 (desk K3) — where a task opens, and the one route that keeps it.
//
// A task (a form, a short choice) opens through [showTask] and is ONE popup
// route for its whole life: a session. The route chooses its container from
// the window class each time the window changes — a sheet on a phone, a
// dialog on a tablet, a centred dialog or a side panel at the desk — and
// moves the same body into it, so what was typed, the focus, a chosen file
// and a command in flight stay where they are. Crossing a width never pops
// and pushes; the task ends when it is closed (or when the page under it
// goes away). Being a popup route, the desk's navigation rests while it is
// open, as for any dialog.
//
// Typed work is never lost without a question. While the session holds a
// change ([TaskSession.markChanged]: the text of a field inside the task
// differs from what it showed when first focused, however it arrived — a
// key, the soft keyboard, dictation, autofill, a paste — or one of the form
// kit's choices was changed), every way out asks first — Escape,
// the scrim, a drag, the back button and the body's own Cancel or Close —
// with the one discard question. Only a completed submit
// ([TaskSession.completed]) takes the mark away.
//
// A task ends with its context: when the signed-in person or the workspace
// changes (sign-out, an expired session, a switch of business —
// `taskContextTokenProvider`), it is closed at once and without a question.
// The work was the previous context's; showing it to the next person or
// business would be the loss.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../session/task_context.dart';
import '../kit/kit_metrics.dart';
import '../unsaved_changes_guard.dart';
import 'window_class.dart';

/// How much a task holds, which decides its container at the desk.
///
/// A third size, a long task shown as a page with a summary beside it, is
/// not one of these: a page is a location of its own (a deep link, the
/// browser's back), which one popup route that is a sheet on a phone
/// cannot become without pushing a second route.
enum TaskSize {
  /// A few fields: a centred dialog at the desk; Enter submits it.
  short,

  /// A form: a side panel at the desk, the page behind it readable.
  standard,
}

/// The container a task is shown in.
enum _TaskContainer { sheet, dialog, sidePanel }

/// The measures of the task containers.
@visibleForTesting
abstract final class TaskSurfaceMetrics {
  /// The widest a task dialog grows, so a form keeps its line length.
  static const double dialogMaxWidth = KitMetrics.taskDialogMaxWidth;

  /// The width of the side panel at the desk.
  static const double sidePanelWidth = 480;

  /// The scrim over the page beside a side panel: light, the page stays
  /// readable.
  static const Color sidePanelScrim = Color(0x1F000000);

  /// The scrim under a sheet or a dialog (the framework's own).
  static const Color modalScrim = Colors.black54;

  /// The side panel's lift over the page.
  static const double sidePanelElevation = 1;

  /// How long a container takes to come in and to go.
  static const Duration enter = Duration(milliseconds: 250);
  static const Duration exit = Duration(milliseconds: 200);
}

/// The container a task of [size] takes in a window of [windowClass].
_TaskContainer _containerFor(TaskSize size, WindowClass windowClass) =>
    switch (windowClass) {
      WindowClass.compact => _TaskContainer.sheet,
      WindowClass.medium => _TaskContainer.dialog,
      _ => switch (size) {
        TaskSize.short => _TaskContainer.dialog,
        TaskSize.standard => _TaskContainer.sidePanel,
      },
    };

/// One open task: its size, and whether something in it was changed.
class TaskSession {
  TaskSession._(this.size);

  final TaskSize size;
  final ValueNotifier<bool> _changed = ValueNotifier(false);

  /// Whether something in the task was changed since it opened.
  bool get changed => _changed.value;

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

/// The tasks open under a session key, so asking again for the same task
/// returns the one that is open instead of a second.
final Map<Object, _TaskRoute<Object?>> _openTasks = {};

/// Opens [builder] as a task of [size] and resolves with what it pops.
///
/// [sessionKey] names the task (for example its account, workspace and
/// record): while a task under that key is open, the call returns its
/// result instead of opening another — when the type asked for matches
/// the open one's; otherwise the call resolves with null.
Future<T?> showTask<T>(
  BuildContext context, {
  required TaskSize size,
  required WidgetBuilder builder,
  Object? sessionKey,
}) {
  final open = sessionKey == null ? null : _openTasks[sessionKey];
  if (open != null && open.isActive) {
    return open.popped.then((value) => value is T ? value : null);
  }
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = _TaskRoute<T>(
    size: size,
    builder: builder,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    container: _containerFor(size, WindowClass.of(context)),
  );
  if (sessionKey != null) {
    _openTasks[sessionKey] = route;
    unawaited(
      route.popped.whenComplete(() {
        if (identical(_openTasks[sessionKey], route)) {
          _openTasks.remove(sessionKey);
        }
      }),
    );
  }
  return navigator.push(route);
}

class _TaskRoute<T> extends PopupRoute<T> {
  _TaskRoute({
    required this.size,
    required this.builder,
    required this.barrierLabel,
    required this.themes,
    required this.container,
  }) : session = TaskSession._(size);

  final TaskSize size;
  final WidgetBuilder builder;
  final CapturedThemes themes;
  final TaskSession session;

  /// The container shown now; the scrim follows it.
  _TaskContainer container;

  @override
  final String barrierLabel;

  @override
  bool get barrierDismissible => true;

  @override
  Color get barrierColor => container == _TaskContainer.sidePanel
      ? TaskSurfaceMetrics.sidePanelScrim
      : TaskSurfaceMetrics.modalScrim;

  @override
  Duration get transitionDuration => TaskSurfaceMetrics.enter;

  @override
  Duration get reverseTransitionDuration => TaskSurfaceMetrics.exit;

  /// The animation a sheet's drag moves.
  AnimationController get sheetController => controller!;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => themes.wrap(_TaskPresenter(route: this));

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

/// Shows the route's one body in the container of the current window, and
/// asks before a changed task is left.
class _TaskPresenter extends StatefulWidget {
  const _TaskPresenter({required this.route});

  final _TaskRoute<Object?> route;

  @override
  State<_TaskPresenter> createState() => _TaskPresenterState();
}

class _TaskPresenterState extends State<_TaskPresenter> {
  /// Moves the body, with its state and focus, from container to container.
  final GlobalKey _bodyKey = GlobalKey(debugLabel: 'task-body');

  _TaskRoute<Object?> get _route => widget.route;

  void _follow(_TaskContainer container) {
    if (_route.container == container) return;
    _route.container = container;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _route.isActive) _route.changedInternalState();
    });
  }

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
          focused!.findAncestorStateOfType<_TaskPresenterState>(),
          this,
        );
    final next = mine && !field.readOnly ? field.controller : null;
    if (identical(next, _followed)) return;
    _followed?.removeListener(_textChanged);
    _followed = next;
    if (next == null) return;
    _firstText[next] ??= next.text;
    next.addListener(_textChanged);
  }

  /// The followed field's text differs from what it first showed: a change.
  void _textChanged() {
    final field = _followed;
    if (field != null && field.text != _firstText[field]) {
      _route.session.markChanged();
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
      if (next != opened) _contextChanged();
    });
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_focusMoved);
    _followed?.removeListener(_textChanged);
    _context?.close();
    super.dispose();
  }

  /// The context the task was opened in is gone: the task goes with it,
  /// unasked (see the head of this file).
  void _contextChanged() => scheduleMicrotask(() {
    final navigator = _route.navigator;
    if (_route.isActive && navigator != null) navigator.removeRoute(_route);
  });

  /// A way out was refused because the task holds a change: ask, and leave
  /// with what was being popped when the person discards.
  Future<void> _leave(bool didPop, Object? result) async {
    if (didPop) return;
    final navigator = Navigator.of(context);
    if (await confirmDiscardChanges(context)) {
      if (navigator.mounted && _route.isActive) navigator.pop(result);
    }
  }

  /// A sheet dragged down: closes, or (kept after the question) comes back.
  Future<void> _sheetClosing() async {
    await Navigator.of(context).maybePop();
    if (mounted && _route.isActive) {
      await _route.sheetController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final container = _containerFor(_route.size, WindowClass.of(context));
    _follow(container);
    final body = KeyedSubtree(
      key: _bodyKey,
      child: Builder(builder: _route.builder),
    );
    return _TaskSessionScope(
      session: _route.session,
      child: ValueListenableBuilder<bool>(
        valueListenable: _route.session._changed,
        builder: (context, changed, child) => PopScope<Object?>(
          canPop: !changed,
          onPopInvokedWithResult: _leave,
          child: child!,
        ),
        child: switch (container) {
          _TaskContainer.sheet => _sheet(body),
          _TaskContainer.dialog => _dialog(body),
          _TaskContainer.sidePanel => _sidePanel(body),
        },
      ),
    );
  }

  Animation<double> get _curve =>
      CurvedAnimation(parent: _route.animation!, curve: Curves.easeOutCubic);

  Widget _sheet(Widget body) => Align(
    alignment: Alignment.bottomCenter,
    child: SlideTransition(
      position: Tween(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(_route.animation!),
      child: BottomSheet(
        key: const ValueKey('task-sheet'),
        animationController: _route.sheetController,
        showDragHandle: true,
        onClosing: _sheetClosing,
        builder: (_) => body,
      ),
    ),
  );

  Widget _dialog(Widget body) => FadeTransition(
    opacity: _curve,
    child: Dialog(
      key: const ValueKey('task-dialog'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: TaskSurfaceMetrics.dialogMaxWidth,
        ),
        child: body,
      ),
    ),
  );

  Widget _sidePanel(Widget body) {
    final from = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: SlideTransition(
        position: Tween(
          begin: Offset(from, 0),
          end: Offset.zero,
        ).animate(_curve),
        child: SizedBox(
          width: TaskSurfaceMetrics.sidePanelWidth,
          height: double.infinity,
          child: Material(
            key: const ValueKey('task-side-panel'),
            elevation: TaskSurfaceMetrics.sidePanelElevation,
            child: SafeArea(
              left: false,
              right: false,
              child: Align(alignment: Alignment.topCenter, child: body),
            ),
          ),
        ),
      ),
    );
  }
}
