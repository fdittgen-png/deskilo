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

import '../../../../core/help/help_arbiter.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../guide/guide_runner.dart';
import '../../guide/guide_session.dart';
import '../../guide/task_guide.dart';
import '../ui_capture.dart';
import 'guide_attention.dart';
import 'guide_bubble.dart';
import 'guide_step_text.dart';

class GuideHostLayer extends ConsumerStatefulWidget {
  const GuideHostLayer({super.key});

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

  @override
  void dispose() {
    _poll?.cancel();
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
    return anchor == null ? null : UiCapture.findControl(anchor);
  }

  void _locate() {
    if (!mounted) return;
    final rect = _rectOf(_element());
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
    final origin = box.localToGlobal(Offset.zero, ancestor: layer);
    return origin & box.size;
  }

  void _showMe() {
    final e = _element();
    if (e == null) return;
    Scrollable.ensureVisible(
      e,
      alignment: 0.3,
      duration: motionDuration(context, MotionTokens.standard),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(guideSessionProvider);
    final run = session.run;
    if (run == null) {
      _follow(null);
      _minimized = false;
      _bubble = null;
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
        const bottomClearance = 96.0;
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
              constraints: const BoxConstraints(maxWidth: 520),
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
                    onShowMe: target == null ? null : _showMe,
                    onMinimize: () => setState(() => _minimized = true),
                  ),
                ),
              ),
            ),
          ),
        );
        return Stack(
          children: [
            if (target != null && live && !blocked)
              Positioned.fill(
                child: IgnorePointer(
                  // A new control restarts the pulse and the flash.
                  child: GuideAttention(
                    key: ValueKey(_anchor),
                    target: target,
                    bounds: box.biggest,
                  ),
                ),
              ),
            if (minimized)
              GuideBubble(
                position:
                    _bubble ??
                    Offset(
                      box.maxWidth - guideBubbleSize - AppSpacing.md,
                      box.maxHeight - bottomClearance - guideBubbleSize,
                    ),
                bounds: box.biggest,
                current: (mainIndex + 1).clamp(1, steps.length),
                total: steps.length,
                onMove: (p) => setState(() => _bubble = p),
                onRestore: () => setState(() => _minimized = false),
              )
            else
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

class _Pane extends ConsumerWidget {
  const _Pane({
    required this.session,
    required this.run,
    required this.blocked,
    required this.targetMissing,
    required this.showSteps,
    required this.onToggleSteps,
    required this.onShowMe,
    required this.onMinimize,
  });

  final GuideSessionState session;
  final GuideRun run;
  final bool blocked;
  final bool targetMissing;
  final bool showSteps;
  final VoidCallback onToggleSteps;
  final VoidCallback? onShowMe;
  final VoidCallback onMinimize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final notifier = ref.read(guideSessionProvider.notifier);
    final guide = run.guide;
    final steps = guide.steps;
    final step = run.current;
    final mainIndex = step == null
        ? steps.length
        : steps.indexWhere(
            (s) => s.id == step.id || s.recovery.any((r) => r.id == step.id),
          );
    final ended =
        run.state == GuideRunState.completed ||
        run.state == GuideRunState.stopped;
    final waiting =
        step != null && run.statusOf(step.id) == GuideStepStatus.waiting;
    final inRecovery = step != null && step.id.contains('r');

    final notices = <Widget>[
      if (ended)
        _Notice(
          'guide-host-${run.state.name}',
          run.state == GuideRunState.completed
              ? (l10n?.guideHostCompleted ?? 'Guide completed.')
              : (l10n?.guideHostStopped ??
                    'Guide stopped. Nothing was undone.'),
        )
      else if (run.state == GuideRunState.paused)
        _Notice(
          'guide-host-paused-${session.pauseReason?.name ?? 'other'}',
          session.pauseReason == GuidePauseReason.featureOff
              ? (l10n?.guideHostPausedFeature ??
                    'Paused: the task recorder is turned off in this workspace.')
              : (l10n?.guideHostPausedScope ??
                    'Paused: the account or workspace changed. The guide '
                        'continues only where it started.'),
        )
      else if (blocked)
        _Notice(
          'guide-host-blocked',
          l10n?.guideHostBlocked ??
              'Resolve the message on screen first; the guide waits.',
        ),
      if (!ended && run.state == GuideRunState.running && !blocked) ...[
        if (inRecovery)
          _Notice(
            'guide-host-recovery',
            l10n?.guideHostRecovery ??
                'That was refused. Follow these steps, then try again.',
          ),
        if (run.uncertain)
          _Notice(
            'guide-host-uncertain',
            l10n?.guideHostUncertain ??
                'The answer did not arrive. Check whether it happened '
                    'before trying again.',
          ),
        if (waiting)
          _Notice(
            'guide-host-waiting',
            l10n?.guideHostWaiting ?? 'Waiting for the result…',
          ),
        if (targetMissing && !waiting)
          _Notice(
            'guide-host-not-on-screen',
            l10n?.guideHostNotOnScreen ??
                'This control is not on this screen. Go to the screen of '
                    'the previous step, or check the guide.',
          ),
      ],
    ];

    return Material(
      key: const ValueKey('guide-host'),
      elevation: 6,
      borderRadius: AppRadius.xlAll,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.assistant_navigation),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      guide.title ?? (l10n?.guideHostTitle ?? 'Guided task'),
                      style: text.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (!ended)
                  Text(
                    l10n?.guideHostStepOf(
                          (mainIndex + 1).clamp(1, steps.length),
                          steps.length,
                        ) ??
                        'Step ${mainIndex + 1} of ${steps.length}',
                    key: const ValueKey('guide-host-progress'),
                    style: text.labelMedium,
                  ),
                if (!ended)
                  IconButton(
                    key: const ValueKey('guide-host-minimize'),
                    tooltip: l10n?.guideHostMinimize ?? 'Minimise the guide',
                    icon: const Icon(Icons.minimize_rounded),
                    onPressed: onMinimize,
                  ),
                IconButton(
                  key: const ValueKey('guide-host-steps'),
                  tooltip: l10n?.guideHostSteps ?? 'All steps',
                  icon: Icon(showSteps ? Icons.expand_more : Icons.list),
                  onPressed: onToggleSteps,
                ),
                if (ended)
                  IconButton(
                    key: const ValueKey('guide-host-close'),
                    tooltip: l10n?.guideHostClose ?? 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: notifier.close,
                  )
                else
                  IconButton(
                    key: const ValueKey('guide-host-stop'),
                    tooltip: l10n?.guideHostStop ?? 'Stop the guide',
                    icon: const Icon(Icons.stop_circle_outlined),
                    onPressed: notifier.stop,
                  ),
              ],
            ),
            if (step != null && !ended) ...[
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                liveRegion: true,
                child: Text(
                  guideStepText(l10n, step),
                  key: ValueKey('guide-host-step-${step.id}'),
                  style: text.bodyLarge,
                ),
              ),
            ],
            for (final n in notices) ...[
              const SizedBox(height: AppSpacing.xs),
              n,
            ],
            if (showSteps) _StepList(run: run),
            if (!ended) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                alignment: WrapAlignment.end,
                children: [
                  if (run.state == GuideRunState.paused)
                    FilledButton(
                      key: const ValueKey('guide-host-resume'),
                      onPressed: notifier.resume,
                      child: Text(l10n?.guideHostResume ?? 'Resume'),
                    )
                  else ...[
                    TextButton(
                      key: const ValueKey('guide-host-back'),
                      onPressed: notifier.back,
                      child: Text(l10n?.guideHostBack ?? 'Back'),
                    ),
                    if (step != null && !waiting)
                      TextButton(
                        key: const ValueKey('guide-host-skip'),
                        onPressed: notifier.skip,
                        child: Text(l10n?.guideHostSkip ?? 'Skip'),
                      ),
                    if (onShowMe != null && !blocked)
                      OutlinedButton(
                        key: const ValueKey('guide-host-show-me'),
                        onPressed: onShowMe,
                        child: Text(l10n?.guideHostShowMe ?? 'Show me'),
                      ),
                    if (step != null && step.kind != GuideStepKind.perform)
                      FilledButton(
                        key: const ValueKey('guide-host-done'),
                        onPressed: notifier.acknowledge,
                        child: Text(l10n?.guideHostDone ?? 'Done'),
                      ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.id, this.text);

  final String id;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: ValueKey(id),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: AppRadius.mdAll,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Text(text, style: TextStyle(color: scheme.onSecondaryContainer)),
      ),
    );
  }
}

/// Every step and its status, readable by a screen reader.
class _StepList extends StatelessWidget {
  const _StepList({required this.run});

  final GuideRun run;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String status(GuideStepStatus s) => switch (s) {
      GuideStepStatus.pending => l10n?.guideHostStatusPending ?? 'To do',
      GuideStepStatus.waiting => l10n?.guideHostStatusWaiting ?? 'Waiting',
      GuideStepStatus.done => l10n?.guideHostStatusDone ?? 'Done',
      GuideStepStatus.acknowledged =>
        l10n?.guideHostStatusAcknowledged ?? 'Acknowledged',
      GuideStepStatus.skipped => l10n?.guideHostStatusSkipped ?? 'Skipped',
    };
    final current = run.current?.id;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 240),
      child: ListView(
        key: const ValueKey('guide-host-step-list'),
        shrinkWrap: true,
        children: [
          for (final s in run.guide.steps)
            ListTile(
              key: ValueKey('guide-host-list-${s.id}'),
              dense: true,
              selected: s.id == current,
              title: Text(
                guideStepText(l10n, s),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(status(run.statusOf(s.id))),
            ),
        ],
      ),
    );
  }
}
