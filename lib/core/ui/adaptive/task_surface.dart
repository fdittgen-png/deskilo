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

import '../kit/kit_metrics.dart';
import 'task_session.dart';
import 'window_class.dart';

export 'task_session.dart';

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
        // A long task is a page (long_task_page.dart), never this route.
        TaskSize.standard || TaskSize.long => _TaskContainer.sidePanel,
      },
    };

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
  assert(size != TaskSize.long, 'a long task is a page: showLongTask');
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
  }) : session = TaskSession(size);

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

  /// The context the task was opened in is gone: the task goes with it,
  /// unasked (see the head of this file).
  void _contextChanged() {
    final navigator = _route.navigator;
    if (_route.isActive && navigator != null) navigator.removeRoute(_route);
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
    return TaskSessionHost(
      session: _route.session,
      onContextChanged: _contextChanged,
      child: switch (container) {
        _TaskContainer.sheet => _sheet(body),
        _TaskContainer.dialog => _dialog(body),
        _TaskContainer.sidePanel => _sidePanel(body),
      },
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
