// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1867 — the live guide on the real app (the D365FO-style task guide).
//
// It sits with the recording indicator above the navigator, so it is on
// every route, and shows only while a guide is open:
//   * a pane at the bottom with the step, its status and what the person
//     may do — Done (instructions and manual steps only: acknowledged,
//     never "verified"), Skip (skipped, never done), Back, Show me, the
//     accessible list of all steps, Stop; Resume while paused;
//   * a ring around the control the step points at, found by the same
//     key the recorder names it with (ui_capture.dart) on the route on
//     top. The ring never takes a tap: the app stays fully usable, there
//     is no focus trap and nothing is entered for the person. When the
//     control is not on screen the pane says so instead of guessing.
// The one help arbiter decides who speaks: a blocker on screen shrinks
// the pane to "resolve this first"; tips stay silent while a guide is
// open. Nothing here starts a command, and Stop or Back undo nothing.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/help/help_arbiter.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/app_localizations_en.dart';
import '../../guide/guide_runner.dart';
import '../../domain/action_registry.dart';
import '../../domain/recording_reference.dart';
import '../../guide/guide_session.dart';
import '../../guide/task_guide.dart';
import '../ui_capture.dart';
import 'guide_attention.dart';
import 'guide_bubble.dart';
import 'guide_bubble_menu.dart';
import 'guide_step_text.dart';

part 'guide_pane.dart';

class GuideHostLayer extends ConsumerStatefulWidget {
  const GuideHostLayer({super.key, this.router});

  /// The app's router: what the "Go to page" button opens a step's page
  /// through. Null where there is none (the button is then not offered).
  final GoRouter? router;

  @override
  ConsumerState<GuideHostLayer> createState() => _GuideHostLayerState();
}

class _GuideHostLayerState extends ConsumerState<GuideHostLayer> {
  Timer? _poll;
  Rect? _target;
  bool _targetSearched = false;
  String? _anchor;
  bool _showSteps = false;
  // The wizard folded into a small circle the person can move.
  bool _minimized = false;
  Offset? _bubble;
  // The circle, tapped: its menu of the pane's actions.
  bool _bubbleMenu = false;
  int _attentionRevision = 0;
  String? _revealStep;
  Timer? _revealTimer;

  @override
  void dispose() {
    _poll?.cancel();
    _revealTimer?.cancel();
    super.dispose();
  }

  /// Follows the control while it moves, scrolls or appears: re-located
  /// a few times a second while the step points at one.
  void _follow(String? anchor) {
    if (anchor == _anchor) return;
    _anchor = anchor;
    _poll?.cancel();
    _target = null;
    _targetSearched = false;
    if (anchor == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
    _poll = Timer.periodic(const Duration(milliseconds: 500), (_) => _locate());
  }

  Element? _element() {
    final anchor = _anchor;
    final router = widget.router;
    final page = ref.read(guideSessionProvider).run?.current?.destination;
    if (router != null && page != null) {
      final destination = Uri.parse(page);
      final here = router.state;
      final sameForm = destination.path == '/me'
          ? here.uri.path == '/me' &&
                (here.uri.queryParameters['tab'] ?? 'home') ==
                    (destination.queryParameters['tab'] ?? 'home')
          : guidePageForTarget(here.fullPath) == page;
      if (!sameForm) return null;
    }
    return anchor == null ? null : UiCapture.findControl(anchor);
  }

  void _locate() {
    if (!mounted) return;
    final element = _element();
    final rect = _rectOf(element);
    // Navigation and lazy form construction can finish on different frames.
    // Retry revealing the requested control briefly, then leave the link usable.
    if (_revealStep == ref.read(guideSessionProvider).run?.current?.id &&
        (_revealTimer?.isActive ?? false)) {
      if (element != null) {
        _revealTimer?.cancel();
        _revealTimer = null;
        _showMe();
      }
    } else {
      _revealTimer?.cancel();
      _revealTimer = null;
    }
    if (rect != _target || !_targetSearched) {
      setState(() {
        _target = rect;
        _targetSearched = true;
      });
    }
  }

  Rect? _rectOf(Element? e) {
    final box = e?.renderObject;
    final layer = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    if (layer is! RenderBox || !layer.attached) return null;
    final origin =
        box.localToGlobal(Offset.zero) - layer.localToGlobal(Offset.zero);
    return origin & box.size;
  }

  void _showMe() {
    final e = _element();
    if (e == null) return;
    setState(() => _attentionRevision++);
    Scrollable.ensureVisible(
      e,
      alignment: 0.3,
      duration: motionDuration(context, MotionTokens.standard),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
  }

  /// Open only a page. Form actions remain the person's actions. An already
  /// mounted dialog is preserved, and highlighting can be requested repeatedly.
  void _openStep(GuideStep step) {
    final session = ref.read(guideSessionProvider.notifier);
    final run = ref.read(guideSessionProvider).run;
    if (run == null ||
        run.state != GuideRunState.running ||
        step.id != run.current?.id &&
            run.current != null &&
            run.statusOf(run.current!.id) == GuideStepStatus.waiting) {
      return;
    }
    if (step.id != run.current?.id) session.visit(step.id);
    _follow(guideStepAnchor(step));
    setState(() {
      _showSteps = false;
      _attentionRevision++;
      _revealStep = step.id;
      _revealTimer?.cancel();
      _revealTimer = Timer(const Duration(seconds: 5), () {
        _revealStep = null;
        _revealTimer = null;
      });
    });
    final router = widget.router;
    final route = guideStepRoute(run.guide.steps, step);
    final controlOnOpenForm =
        router != null &&
        _element() != null &&
        router.state.uri.path != '/me' &&
        guidePageForTarget(router.state.fullPath) == route;
    // Going to the same page preserves any dialog already open on it.
    if (router != null &&
        route != null &&
        !controlOnOpenForm &&
        router.state.uri.toString() != route) {
      router.go(route);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // A destination already open is still an observed navigation step.
      // Merely following a link never completes a field or a command.
      if (router != null &&
          route != null &&
          router.state.uri.toString() == route &&
          ref.read(guideSessionProvider).run?.current?.id == step.id) {
        if (step.action == RecorderActions.uiOpenScreen &&
            router.state.fullPath == step.target) {
          session.action(RecorderActions.uiOpenScreen, target: step.target);
        } else if (step.action == RecorderActions.openReserve &&
            router.state.uri.path == '/reserve') {
          session.action(RecorderActions.openReserve);
        }
      }
      _revealStep = ref.read(guideSessionProvider).run?.current?.id;
      _locate();
    });
  }

  /// What the circle's menu offers: the pane's own actions, under the
  /// same conditions as its buttons.
  List<GuideBubbleAction> _bubbleActions(
    GuideRun run,
    GuideStep? step,
    int mainIndex,
    bool blocked,
  ) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final notifier = ref.read(guideSessionProvider.notifier);
    final steps = run.guide.steps;
    final running = run.state == GuideRunState.running;
    final waiting =
        step != null && run.statusOf(step.id) == GuideStepStatus.waiting;
    final route = step == null ? null : guideStepRoute(steps, step);
    return [
      GuideBubbleAction(
        id: 'open',
        icon: Icons.open_in_full,
        label: l10n.guideHostRestore(
          (mainIndex + 1).clamp(1, steps.length),
          steps.length,
        ),
        perform: () => setState(() => _minimized = false),
      ),
      if (run.state == GuideRunState.paused)
        GuideBubbleAction(
          id: 'resume',
          icon: Icons.play_arrow,
          label: l10n.guideHostResume,
          perform: notifier.resume,
        ),
      if (running && step != null && !blocked)
        GuideBubbleAction(
          id: 'show-me',
          icon: Icons.near_me_outlined,
          label: l10n.guideHostShowMe,
          perform: () => _openStep(step),
        ),
      if (running && step != null && !blocked && route != null &&
          widget.router != null)
        GuideBubbleAction(
          id: 'go-to-page',
          icon: Icons.open_in_new,
          label: guideDestinationLabel(l10n, route),
          perform: () => _openStep(step),
        ),
      if (running && step != null && step.kind != GuideStepKind.perform)
        GuideBubbleAction(
          id: 'done',
          icon: Icons.check,
          label: l10n.guideHostDone,
          perform: notifier.acknowledge,
        ),
      if (running && step != null && !waiting)
        GuideBubbleAction(
          id: 'skip',
          icon: Icons.skip_next,
          label: l10n.guideHostSkip,
          perform: notifier.skip,
        ),
      if (running && mainIndex > 0 && !waiting)
        GuideBubbleAction(
          id: 'back',
          icon: Icons.undo,
          label: l10n.guideHostBack,
          perform: notifier.back,
        ),
      GuideBubbleAction(
        id: 'stop',
        icon: Icons.stop_circle_outlined,
        label: l10n.guideHostStop,
        perform: notifier.stop,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(guideSessionProvider);
    final run = session.run;
    if (run == null) {
      _follow(null);
      _minimized = false;
      _bubble = null;
      _bubbleMenu = false;
      _showSteps = false;
      _revealTimer?.cancel();
      _revealTimer = null;
      return const SizedBox.shrink();
    }
    final step = run.current;
    final live = run.state == GuideRunState.running;
    _follow(live && step != null ? guideStepAnchor(step) : null);
    final blocked = ref.watch(helpSlotProvider) == HelpSlot.blocker;
    final target = _target;
    final ended =
        run.state == GuideRunState.completed ||
        run.state == GuideRunState.stopped;
    // An ended guide always shows its pane: the result and Close live there.
    final minimized = _minimized && !ended;
    final steps = run.guide.steps;
    final mainIndex = step == null
        ? steps.length
        : steps.indexWhere(
            (s) => s.id == step.id || s.recovery.any((r) => r.id == step.id),
          );
    return LayoutBuilder(
      builder: (context, box) {
        // Above the app's bottom navigation (its centre button included),
        // and at the top whenever the control it points at would be under
        // the pane: the guide never hides the app it guides.
        final bottomClearance = 96.0 + MediaQuery.viewInsetsOf(context).bottom;
        const paneEstimate = 280.0;
        final dockTop =
            target != null &&
            target.bottom > box.maxHeight - bottomClearance - paneEstimate;
        final pane = SafeArea(
          top: dockTop,
          bottom: !dockTop,
          child: Align(
            alignment: dockTop ? Alignment.topCenter : Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 520,
                maxHeight:
                    (box.maxHeight -
                            bottomClearance -
                            MediaQuery.paddingOf(context).vertical)
                        .clamp(80, double.infinity),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  // The layer sits above the navigator: its own Overlay lets
                  // the pane's tooltips show.
                  child: Overlay.wrap(
                    child: _Pane(
                      session: session,
                      run: run,
                      blocked: blocked,
                      targetMissing:
                          _anchor != null && _targetSearched && target == null,
                      showSteps: _showSteps,
                      onToggleSteps: () =>
                          setState(() => _showSteps = !_showSteps),
                      onShowMe: step == null ? null : () => _openStep(step),
                      onOpenStep: _openStep,
                      canOpenPage: widget.router != null,
                      onMinimize: () => setState(() => _minimized = true),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final bubbleAt = GuideBubble.clampTo(
          _bubble ??
              Offset(
                box.maxWidth - guideBubbleSize - AppSpacing.md,
                box.maxHeight - bottomClearance - guideBubbleSize,
              ),
          box.biggest,
        );
        return Stack(
          children: [
            if (target != null && live && !blocked)
              Positioned.fill(
                child: IgnorePointer(
                  // A new control restarts the pulse and the flash.
                  child: GuideAttention(
                    key: ValueKey('$_anchor-$_attentionRevision'),
                    target: target,
                    bounds: box.biggest,
                  ),
                ),
              ),
            if (minimized) ...[
              GuideBubble(
                key: const ValueKey('guide-host-bubble-layer'),
                position: bubbleAt,
                bounds: box.biggest,
                current: (mainIndex + 1).clamp(1, steps.length),
                total: steps.length,
                onMove: (p) => setState(() {
                  _bubble = p;
                  _bubbleMenu = false;
                }),
                onTap: () => setState(() => _bubbleMenu = !_bubbleMenu),
              ),
              if (_bubbleMenu)
                Overlay.wrap(
                  child: GuideBubbleMenu(
                    bubble: bubbleAt,
                    bounds: box.biggest,
                    actions: _bubbleActions(run, step, mainIndex, blocked),
                    onDismiss: () => setState(() => _bubbleMenu = false),
                  ),
                ),
            ] else
              Positioned(
                left: 0,
                right: 0,
                top: dockTop ? 0 : null,
                bottom: dockTop ? null : bottomClearance,
                child: pane,
              ),
          ],
        );
      },
    );
  }
}
