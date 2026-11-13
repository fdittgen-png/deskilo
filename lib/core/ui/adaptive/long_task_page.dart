// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3608 (desk K3) — the long task: more than a side panel holds (an order
// with its lines, a document with its parts). It is a page of its own, so it
// has an address — a deep link, the browser's Back, a reload — and it is a
// route, never a popup. Open it with [showLongTask].
//
// The page is the form in its column ([FormColumn]) and, from the expanded
// window class, a summary pane beside it that follows what is typed; below
// that class the summary comes after the fields, inside the form, and the
// form's confirm button stays in view at the bottom. A route that shows it
// declares the work measure: the page lays out its own columns.
//
// It keeps what a popup task keeps (task_session.dart): the same session,
// so leaving typed work asks — Escape, the close button and Back all go
// through the one discard question — and it ends, unasked, with the
// signed-in person or the workspace it was opened in. Resizing only moves
// the summary; the form keeps its state, its focus and its command in
// flight. Focus goes into the page when it opens and, as for any route,
// returns to what opened it when it closes.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_spacing.dart';
import '../kit/page_title.dart';
import '../unsaved_changes_guard.dart';
import 'page_measure.dart';
import 'task_session.dart';
import 'window_class.dart';

/// Opens the long task at [address] (a route that shows a [LongTaskPage])
/// and resolves with what the page pops.
Future<T?> showLongTask<T>(BuildContext context, {required String address}) =>
    GoRouter.of(context).push<T>(address);

/// Where the summary of a [LongTaskPage] is: beside the form, or after its
/// fields. Read by the form kit, which draws the summary inline in the
/// second case and the page's title in neither (the page's bar has it).
class LongTaskLayout extends InheritedWidget {
  const LongTaskLayout({
    required this.summaryBeside,
    required super.child,
    super.key,
  });

  final bool summaryBeside;

  /// The layout of the long task [context] is in; null outside one.
  static LongTaskLayout? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LongTaskLayout>();

  @override
  bool updateShouldNotify(LongTaskLayout oldWidget) =>
      summaryBeside != oldWidget.summaryBeside;
}

/// A long task as a page: [form] in its column, [summary] beside it.
class LongTaskPage extends StatefulWidget {
  const LongTaskPage({
    required this.title,
    required this.form,
    required this.fallbackAddress,
    this.summary,
    super.key,
  });

  /// The page's name, in its bar.
  final String title;

  /// The form: it brings its own confirm button (an [AppFormSheet]).
  final Widget form;

  /// What the page shows beside the form, from the expanded class; below it
  /// the form draws the summary itself (it reads [LongTaskLayout]).
  final Widget? summary;

  /// Where closing goes when nothing is behind the page (a deep link).
  final String fallbackAddress;

  @override
  State<LongTaskPage> createState() => _LongTaskPageState();
}

class _LongTaskPageState extends State<LongTaskPage> {
  final TaskSession _session = TaskSession(TaskSize.long);

  /// Keeps the form's state when the summary moves from beside it to
  /// after it, and back.
  final GlobalKey _formKey = GlobalKey(debugLabel: 'long-task-form');

  /// The page's body (not its bar): where focus goes when it opens.
  final FocusScopeNode _body = FocusScopeNode(debugLabel: 'long-task-body');

  @override
  void initState() {
    super.initState();
    // Focus goes into the page: the first field of the form takes it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      final fields = _body.traversalDescendants.where(
        (n) => n.context?.findAncestorWidgetOfExactType<EditableText>() != null,
      );
      (fields.firstOrNull ?? _body.traversalDescendants.firstOrNull)
          ?.requestFocus();
    });
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  /// Closes the page: Back when there is something behind it, else the
  /// fallback; asks first when typed work would be lost.
  Future<void> _close() async {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      await navigator.maybePop();
      return;
    }
    final router = GoRouter.of(context);
    if (_session.changed && !await confirmDiscardChanges(context)) return;
    if (mounted) router.go(widget.fallbackAddress);
  }

  /// The context the page was opened in is gone: so is the page.
  void _contextChanged() {
    if (!mounted) return;
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(widget.fallbackAddress);
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = KeyedSubtree(key: _formKey, child: widget.form);
    final summary = widget.summary;
    return TaskSessionHost(
      session: _session,
      onContextChanged: _contextChanged,
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              key: const ValueKey('long-task-close'),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: const Icon(Icons.close),
              onPressed: _close,
            ),
            title: PageTitle(widget.title),
          ),
          body: FocusScope(
            node: _body,
            child: SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, box) {
                  final beside =
                      summary != null &&
                      WindowClass.ofWidth(box.maxWidth)
                          .atLeast(WindowClass.expanded);
                  return LongTaskLayout(
                    summaryBeside: beside,
                    child: beside
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 5, child: FormColumn(child: form)),
                              const VerticalDivider(width: 1),
                              Expanded(
                                flex: 3,
                                child: SingleChildScrollView(
                                  key: const ValueKey('long-task-summary'),
                                  padding: const EdgeInsets.all(AppSpacing.xl),
                                  child: summary,
                                ),
                              ),
                            ],
                          )
                        : FormColumn(child: form),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
