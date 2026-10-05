// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2142 — the generic layer's capture: what the person does on ANY
// screen, read passively and only while a recording is live.
//
//   * a tap: the innermost control that handles taps under the pointer,
//     named by its nearest string key from the generated vocabulary (or
//     the key's pattern), labelled by the first of the app's OWN words it
//     shows; never coordinates, never text that is not an app message;
//   * a field left: the text field that lost focus, named the same way,
//     labelled by its decoration; its value is never read;
//   * a guarded command: an attempt before runGuarded's action and its
//     real result after (core/trace/guarded.dart's watcher);
//   * a window (dialog, sheet, menu) pushed or popped on the root
//     navigator.
//
// A screen's own seam wins: a tap whose handler recorded a step itself,
// and a command a seam already attempted, are not noted twice. On a
// protected screen nothing is noted (its one excluded marker stands),
// and the recorder's own controls are never noted. Every call is
// guarded: the capture can fail, the app never does.
//
// #1867 — a running guide hears the same resolved names
// ([GuideEvents.sink]) while no recording is live: the guide follows
// what this layer already understands, and writes nothing anywhere.
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/trace/guarded.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../l10n/app_localizations.dart';
import '../application/booking_observation.dart' show errorObservation;
import '../application/recorder_controller.dart';
import '../domain/action_registry.dart';
import '../guide/guide_session.dart';
import 'ui_labels.g.dart';

/// The live capture, while the recorder's indicator is mounted.
class UiCapture implements GuardedCommandWatcher {
  UiCapture({required this.controller, required this.protectedNow});

  /// The recorder, read when something happens (never kept warm).
  final RecorderController Function() controller;

  /// Whether the screen on top is protected or the recorder's own.
  final bool Function() protectedNow;

  /// The capture the window observer reports to, when one is live.
  static UiCapture? current;

  AppLocalizations? _l10n;
  Map<String, String>? _labelIndex;
  final Map<int, (Offset, Duration)> _downs = {};
  FocusNode? _focused;
  static final List<(String, List<String>)> _patterns = [
    for (final p in uiKeyPatterns) (p, p.split('{}')),
  ];

  bool get _recording => controller().state == RecorderState.recording;

  /// A guide is being followed: it hears what happens (#1867).
  static GuideEventSink? get _guide => GuideEvents.sink;

  bool get _listening => _guide != null || _recording;

  /// The language labels are matched in; the index is rebuilt on change.
  set localizations(AppLocalizations? l10n) {
    if (identical(l10n, _l10n)) return;
    _l10n = l10n;
    _labelIndex = null;
  }

  void attach() {
    current = this;
    guardedCommandWatcher = this;
    FocusManager.instance.addListener(_onFocus);
  }

  void detach() {
    if (identical(current, this)) current = null;
    if (identical(guardedCommandWatcher, this)) guardedCommandWatcher = null;
    FocusManager.instance.removeListener(_onFocus);
  }

  // ── names ───────────────────────────────────────────────────────────

  /// The app message [text] is, by key; null for anything else.
  String? labelKeyOf(String? text) {
    final l10n = _l10n;
    if (text == null || l10n == null) return null;
    final index = _labelIndex ??= () {
      final out = <String, String>{};
      for (final key in uiLabelKeys) {
        final words = uiLabel(l10n, key);
        if (words != null && words.trim().isNotEmpty) {
          out.putIfAbsent(words.trim(), () => key);
        }
      }
      return out;
    }();
    return index[text.trim()];
  }

  /// A key as the recorder may name it: listed, its pattern, or a gap.
  static String nameOfKey(String? key) {
    if (key == null) return uiUnkeyed;
    if (uiKeys.contains(key)) return key;
    String? best;
    for (final (pattern, parts) in _patterns) {
      if (!_fits(parts, key)) continue;
      if (best == null || pattern.length > best.length) best = pattern;
    }
    return best ?? uiUnkeyed;
  }

  /// Whether [key] is [parts] with something non-empty between each
  /// two: the first part a prefix, the last a suffix, the middle ones in
  /// order. Linear: no regular expression, nothing to backtrack.
  static bool _fits(List<String> parts, String key) {
    if (!key.startsWith(parts.first) || !key.endsWith(parts.last)) {
      return false;
    }
    final end = key.length - parts.last.length;
    var at = parts.first.length;
    for (var i = 1; i < parts.length - 1; i++) {
      final found = key.indexOf(parts[i], at + 1);
      if (found < 0 || found + parts[i].length > end) return false;
      at = found + parts[i].length;
    }
    return end > at;
  }

  /// #1867 — the mounted control the recorder would name [target] (its
  /// key or its pattern), on the route on top; null when it is not on
  /// screen. The live guide points at it; it never guesses another one.
  static Element? findControl(String target) {
    Element? found;
    var matches = 0;
    var seen = 0;
    _walk(
      (e) {
        final key = e.widget.key;
        if (key is ValueKey<String> &&
            (key.value == target || nameOfKey(key.value) == target)) {
          final route = ModalRoute.of(e);
          if (route == null || route.isCurrent) {
            found = e;
            matches++;
          }
        }
        return ++seen < 40000;
      },
      skip: (w) => w is TickerMode && !w.enabled,
    );
    return matches == 1 ? found : null;
  }

  static bool _isRecorderControl(String? key) =>
      key != null &&
      (key.startsWith('recording-indicator') ||
          key.startsWith('task-recorder') ||
          key.startsWith('task-recording') ||
          key.startsWith('task-workbench'));

  // ── taps ────────────────────────────────────────────────────────────

  void onPointerDown(PointerDownEvent e) =>
      _downs[e.pointer] = (e.position, e.timeStamp);

  void onPointerCancel(PointerCancelEvent e) => _downs.remove(e.pointer);

  void onPointerUp(PointerUpEvent e) {
    final down = _downs.remove(e.pointer);
    if (down == null) return;
    try {
      if ((e.position - down.$1).distance > kTouchSlop ||
          e.timeStamp - down.$2 > kLongPressTimeout ||
          !_listening ||
          protectedNow()) {
        return;
      }
      final tap = _resolveTap(e.position, e.viewId);
      if (tap == null) return;
      final guide = _guide;
      if (guide != null) {
        scheduleMicrotask(
          () => guide.action(RecorderActions.uiTap, target: tap.target),
        );
      }
      if (!_recording) return;
      final c = controller();
      final before = c.status.stepCount;
      // After the tap's own handlers ran: a seam that noted the tap
      // itself wins, and nothing is noted twice.
      scheduleMicrotask(() {
        if (c.status.stepCount != before) return;
        c.record(
          RecorderActions.uiTap,
          target: tap.target,
          payload: {'label': ?tap.label},
        );
      });
    } catch (err, st) {
      TraceLogger.instance.warn('recorder', 'tap not noted', stackTrace: st);
    }
  }

  ({String target, String? label})? _resolveTap(Offset position, int viewId) {
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, position, viewId);
    final element = _tappedElement(result);
    if (element == null) return null;
    final keyed = _keyedAncestor(element);
    final key = keyed?.key;
    if (_isRecorderControl(key)) return null;
    return (
      target: nameOfKey(key),
      label: _labelWithin(keyed?.element ?? element) ?? _labelAbove(element),
    );
  }

  /// The innermost gesture detector under the pointer that handles taps:
  /// the hit render objects are matched to their elements in one walk,
  /// deepest first.
  static Element? _tappedElement(HitTestResult result) {
    final hit = <RenderObject, int>{};
    var depth = 0;
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderObject) hit.putIfAbsent(target, () => depth++);
    }
    Element? best;
    var bestDepth = 1 << 30;
    void visit(Element e) {
      if (e is RenderObjectElement && e.widget is Listener) {
        final at = hit[e.renderObject];
        if (at != null && at < bestDepth) {
          Element? detector;
          e.visitAncestorElements((parent) {
            final w = parent.widget;
            if (w is RawGestureDetector &&
                w.gestures.containsKey(TapGestureRecognizer)) {
              detector = parent;
            }
            return false;
          });
          if (detector != null) {
            best = detector;
            bestDepth = at;
          }
        }
      }
    }

    _walk(visit);
    return best;
  }

  /// Visits the element tree from [from] (the root by default) in
  /// document order without recursion, so a deep tree costs no stack;
  /// [visit] returning false stops the walk, [skip] prunes a subtree.
  static void _walk(
    Object? Function(Element e) visit, {
    Element? from,
    bool Function(Widget w)? skip,
  }) {
    final start = from ?? WidgetsBinding.instance.rootElement;
    if (start == null) return;
    final stack = <Element>[start];
    while (stack.isNotEmpty) {
      final e = stack.removeLast();
      if (skip != null && skip(e.widget)) continue;
      if (visit(e) == false) return;
      final children = <Element>[];
      e.visitChildElements(children.add);
      stack.addAll(children.reversed);
    }
  }

  /// The control's string key: the nearest above [from] within the
  /// control (the walk stops at another control, a scrollable, a
  /// scaffold or a navigator, whose keys name something else), else the
  /// first inside it (a key on a segment's label).
  static ({String key, Element element})? _keyedAncestor(
    Element from, {
    bool control = true,
  }) {
    ({String key, Element element})? found;
    var steps = 0;
    bool check(Element e) {
      final key = e.widget.key;
      if (key is ValueKey<String>) {
        found = (key: key.value, element: e);
        return false;
      }
      final w = e.widget;
      if (w is Scrollable || w is Scaffold || w is Navigator) return false;
      // Another control above this one: its key is not this control's.
      if (control && steps > 0 && w is RawGestureDetector) return false;
      return ++steps < 40;
    }

    if (check(from)) from.visitAncestorElements(check);
    if (found != null) return found;
    // A key on what the control shows (a segment's label): inside it.
    var seen = 0;
    _walk((e) {
      final key = e.widget.key;
      if (!identical(e, from) && key is ValueKey<String>) {
        found = (key: key.value, element: e);
        return false;
      }
      return ++seen < 200;
    }, from: from);
    return found;
  }

  /// The first app message shown inside [root].
  String? _labelWithin(Element root) {
    String? label;
    var seen = 0;
    _walk((e) {
      label ??= labelKeyOf(_textOf(e.widget));
      return label == null && ++seen < 400;
    }, from: root);
    return label;
  }

  /// A tooltip or semantics label just above [from] (an icon button's).
  String? _labelAbove(Element from) {
    String? label;
    var steps = 0;
    from.visitAncestorElements((e) {
      label = labelKeyOf(_textOf(e.widget));
      return label == null && ++steps < 12;
    });
    return label;
  }

  static String? _textOf(Widget w) => switch (w) {
    Text(:final data?) => data,
    RichText(:final text) => text.toPlainText(),
    Tooltip(:final message?) => message,
    final IconButton button => button.tooltip,
    Semantics(properties: SemanticsProperties(:final label?)) => label,
    _ => null,
  };

  // ── fields ──────────────────────────────────────────────────────────

  void _onFocus() {
    try {
      final left = _focused;
      _focused = FocusManager.instance.primaryFocus;
      final context = left?.context;
      if (identical(left, _focused) || context == null || !context.mounted) {
        return;
      }
      if (!_listening || protectedNow()) return;
      final field = context.findAncestorWidgetOfExactType<EditableText>();
      if (field == null) return;
      final element = context as Element;
      final keyed = _keyedAncestor(element, control: false);
      if (_isRecorderControl(keyed?.key)) return;
      final decoration = context
          .findAncestorWidgetOfExactType<TextField>()
          ?.decoration;
      final label =
          labelKeyOf(decoration?.labelText) ?? labelKeyOf(decoration?.hintText);
      _guide?.action(
        RecorderActions.uiCommitField,
        target: nameOfKey(keyed?.key),
      );
      if (!_recording) return;
      controller().record(
        RecorderActions.uiCommitField,
        target: nameOfKey(keyed?.key),
        payload: {'label': ?label},
      );
    } catch (err, st) {
      TraceLogger.instance.warn('recorder', 'field not noted', stackTrace: st);
    }
  }

  // ── screens and windows ─────────────────────────────────────────────

  /// A screen was opened: its route pattern and, after the frame that
  /// shows it, the app message its bar carries.
  void screenOpened(String pattern) {
    if (!_listening) return;
    _guide?.action(RecorderActions.uiOpenScreen, target: pattern);
    if (!_recording) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        controller().record(
          RecorderActions.uiOpenScreen,
          target: pattern,
          payload: {'label': ?_visibleTitle()},
        );
      } catch (err, st) {
        TraceLogger.instance.warn(
          'recorder',
          'screen not noted',
          stackTrace: st,
        );
      }
    });
  }

  String? _visibleTitle() {
    String? label;
    var seen = 0;
    _walk((e) {
      final w = e.widget;
      if (w is AppBar && w.title != null) {
        final route = ModalRoute.of(e);
        if (route == null || route.isCurrent) {
          final title = w.title;
          label ??= labelKeyOf(title is Text ? title.data : null);
        }
      }
      return label == null && ++seen < 20000;
    }, skip: (w) => w is TickerMode && !w.enabled);
    return label;
  }

  void windowChanged({required bool opened}) {
    try {
      if (!_listening || protectedNow()) return;
      final action = opened
          ? RecorderActions.uiOpenWindow
          : RecorderActions.uiCloseWindow;
      _guide?.action(action);
      if (!_recording) return;
      controller().record(action);
    } catch (err, st) {
      TraceLogger.instance.warn('recorder', 'window not noted', stackTrace: st);
    }
  }

  // ── guarded commands ────────────────────────────────────────────────

  @override
  Object? started(String domain, String message) {
    try {
      final target = uiCommandMessages.contains(message) ? message : null;
      // #1867 — a guide hears the attempt and, later, its real result.
      final guide = protectedNow() ? null : _guide;
      final guideToken = guide?.action(RecorderActions.uiCommand, target: target);
      final c = controller();
      final OperationToken? token =
          c.state != RecorderState.recording ||
              protectedNow() ||
              c.awaitingOutcome
          ? null
          : c.attempt(RecorderActions.uiCommand, target: target);
      if (guide == null) return token;
      return _GuidedCommand(guide, token, guideToken);
    } catch (err, st) {
      TraceLogger.instance.warn(
        'recorder',
        'command not noted',
        stackTrace: st,
      );
      return null;
    }
  }

  @override
  void ended(Object token, {Object? error, bool pending = false}) {
    try {
      final OperationToken? recorded;
      GuideEventSink? guide;
      Object? guideToken;
      switch (token) {
        case _GuidedCommand(guide: final g, token: final t, guideToken: final gt):
          guideToken = gt;
          guide = g;
          recorded = t;
        case OperationToken():
          recorded = token;
        default:
          return;
      }
      final ({String outcome, Map<String, Object?> payload}) o;
      if (pending) {
        o = (outcome: RecorderOutcomes.commandPending, payload: const {});
      } else if (error != null) {
        o = errorObservation(
          error,
          refused: RecorderOutcomes.commandRefused,
          unknown: RecorderOutcomes.commandUnknown,
        );
      } else {
        o = (outcome: RecorderOutcomes.commandDone, payload: const {});
      }
      // Only the guide that saw the attempt, if it still runs.
      if (guide != null && identical(GuideEvents.sink, guide)) {
        guide.outcome(o.outcome, token: guideToken);
      }
      if (recorded != null) {
        controller().outcome(recorded, o.outcome, payload: o.payload);
      }
    } catch (err, st) {
      TraceLogger.instance.warn('recorder', 'result not noted', stackTrace: st);
    }
  }
}

/// A guarded command a guide saw: the guide to tell its result, and the
/// recording's own token when one was live.
class _GuidedCommand {
  const _GuidedCommand(this.guide, this.token, this.guideToken);
  final GuideEventSink guide;
  final OperationToken? token;
  final Object? guideToken;
}

/// #2142 — reports windows pushed and popped on the navigator it watches
/// to the live capture; does nothing while none is live.
class RecorderWindowObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) UiCapture.current?.windowChanged(opened: true);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) UiCapture.current?.windowChanged(opened: false);
  }
}
