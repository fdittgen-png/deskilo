// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — the persistent, unobtrusive sign that a task is being recorded,
// with pause/resume and stop in reach on every screen.
//
// It sits in the MaterialApp builder, above the navigator, so it is on
// every route. It stays out of the start-up path (#2033/#2043): until the
// recorder screen was opened in this run it renders its child and reads
// nothing else; it never awaits; and it renders nothing extra while no
// recording is live.
//
// It also tells the recorder where the person went: an instrumented
// screen says nothing here (its seams speak), a protected screen leaves
// one "excluded" marker, any other screen a visible "cannot describe"
// step (route_classification.dart).
//
// #1867 — it also carries the live guide (guide_host.dart): while a guide
// is open the same layer mounts, so the capture it owns tells the guide
// what happens on every screen, recording or not.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/recorder_controller.dart';
import '../../domain/task_recording.dart' show RecordingEndReason;
import '../../guide/guide_session.dart';
import '../../providers/recorder_providers.dart';
import '../../domain/action_registry.dart' show uiRoutes;
import '../../domain/recording_reference.dart';
import '../guide_host/guide_host.dart';
import '../route_classification.dart';
import '../ui_capture.dart';

class RecordingIndicator extends ConsumerWidget {
  const RecordingIndicator({
    super.key,
    required this.router,
    required this.child,
  });

  final GoRouter router;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guiding = ref.watch(
      guideSessionProvider.select((s) => s.run != null),
    );
    if (!ref.watch(recorderOpenedProvider) && !guiding) return child;
    return _LiveIndicator(router: router, child: child);
  }
}

class _LiveIndicator extends ConsumerStatefulWidget {
  const _LiveIndicator({required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<_LiveIndicator> createState() => _LiveIndicatorState();
}

class _LiveIndicatorState extends ConsumerState<_LiveIndicator> {
  String? _lastPath;
  bool _referenceErrorDismissed = false;

  /// #2142 — the screen on top is protected or the recorder's own: the
  /// generic layer notes nothing there.
  bool _quiet = false;

  late final UiCapture _capture = UiCapture(
    controller: () => ref.read(recorderControllerProvider),
    protectedNow: () => _quiet,
  );

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_onRoute);
    _capture.attach();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onRoute();
    });
  }

  @override
  void didUpdateWidget(_LiveIndicator old) {
    super.didUpdateWidget(old);
    if (!identical(old.router, widget.router)) {
      old.router.routerDelegate.removeListener(_onRoute);
      widget.router.routerDelegate.addListener(_onRoute);
    }
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_onRoute);
    _capture.detach();
    super.dispose();
  }

  void _onRoute() {
    try {
      // #1884 B — the TOP route, pushed ones included: the delegate's
      // configuration uri stays on the route a push was made from, so a
      // pushed protected screen went unmarked.
      if (widget.router.routerDelegate.currentConfiguration.isEmpty) return;
      final state = widget.router.state;
      final path = state.uri.path;
      final meTab = path == '/me' ? state.uri.queryParameters['tab'] : null;
      final location = path == '/me' ? '$path?tab=${meTab ?? 'home'}' : path;
      final controller = ref.read(recorderControllerProvider);
      final treatment = treatRoute(path);
      _quiet = treatment is Protected || treatment is RecorderScreen;
      // Opening the recorder to annotate a task must preserve the task's form.
      if (treatment is! RecorderScreen) {
        controller.setPage(
          path == '/me' && guideMeDestinations.contains(location)
              ? location
              : state.fullPath,
        );
      } else if (controller.currentPage == null) {
        final base = widget.router.routerDelegate.currentConfiguration;
        if (treatRoute(base.uri.path) is! RecorderScreen) {
          final tab = base.uri.queryParameters['tab'] ?? 'home';
          controller.setPage(
            base.uri.path == '/me' &&
                    guideMeDestinations.contains('/me?tab=$tab')
                ? '/me?tab=$tab'
                : base.fullPath,
          );
        }
      }
      if (location == _lastPath) return;
      _lastPath = location;
      if (controller.state != RecorderState.recording) {
        // #1867 — a guide still hears which screen opened.
        final pattern = state.fullPath;
        if (GuideEvents.sink != null &&
            !_quiet &&
            pattern != null &&
            uiRoutes.contains(pattern)) {
          scheduleMicrotask(() => _capture.screenOpened(pattern, meTab: meTab));
        }
        return;
      }
      // #2142 — every other screen is noted by its route PATTERN (never
      // the path, which may carry an id), unless it notes itself. After
      // the event that navigated, so the tap that led here comes first.
      final pattern = state.fullPath;
      scheduleMicrotask(() {
        switch (treatment) {
          case Instrumented(:final selfOpening) when !selfOpening:
          case Unrecorded() when pattern != null && uiRoutes.contains(pattern):
            _capture.screenOpened(pattern!, meTab: meTab);
          case Instrumented() || RecorderScreen():
            break;
          case Protected(:final category):
            controller.excluded(category);
          case Unrecorded():
            controller.unrecorded();
        }
      });
    } catch (e, st) {
      TraceLogger.instance.warn(
        'recorder',
        'route not classified',
        stackTrace: st,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(recorderStatusProvider).value;
    final live =
        status != null &&
        (status.state == RecorderState.recording ||
            status.state == RecorderState.paused);
    if (live) _referenceErrorDismissed = false;
    _capture.localizations = AppLocalizations.of(context);
    // One shape whether live or not, so starting or stopping a recording
    // never rebuilds the app beneath it from scratch.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _capture.onPointerDown,
      onPointerUp: _capture.onPointerUp,
      onPointerCancel: _capture.onPointerCancel,
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(child: GuideHostLayer(router: widget.router)),
          if (!live &&
              status?.endReason == RecordingEndReason.referenceMissing &&
              !_referenceErrorDismissed)
            Positioned(
              left: AppSpacing.sm,
              right: AppSpacing.sm,
              top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
              child: Material(
                key: const ValueKey('recording-reference-error'),
                elevation: 6,
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)
                                  ?.taskRecorderEndReferenceMissing ??
                              'Stopped: the current form could not be identified. Open a supported page and start again.',
                        ),
                      ),
                      _PillButton(
                        key: const ValueKey('recording-reference-error-close'),
                        label:
                            AppLocalizations.of(context)?.guideHostClose ??
                            'Close',
                        onTap: () =>
                            setState(() => _referenceErrorDismissed = true),
                        icon: Icons.close,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (live)
            PositionedDirectional(
              top: MediaQuery.paddingOf(context).top + AppSpacing.xs,
              end: AppSpacing.sm,
              child: _Pill(
                status: status,
                onOpen: () => widget.router.push(taskRecorderRoute),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends ConsumerWidget {
  const _Pill({required this.status, required this.onOpen});

  final RecorderStatus status;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final paused = status.state == RecorderState.paused;
    final controller = ref.read(recorderControllerProvider);
    final label = paused
        ? (l10n?.taskRecorderPaused ?? 'Paused')
        : (l10n?.taskRecorderIndicator(status.stepCount) ??
              'Recording a task: ${status.stepCount} steps');
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      child: Material(
        key: const ValueKey('recording-indicator'),
        color: scheme.errorContainer,
        shape: const StadiumBorder(),
        elevation: 2,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              key: const ValueKey('recording-indicator-task-recorder-recording'),
              customBorder: const StadiumBorder(),
              onTap: onOpen,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: AppSpacing.mdH,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        paused ? Icons.pause_circle : Icons.fiber_manual_record,
                        color: scheme.error,
                        size: 16,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      ExcludeSemantics(
                        child: Text(
                          paused
                              ? label
                              : (l10n?.taskRecorderRecording ?? 'Recording'),
                          style: TextStyle(color: scheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Above the navigator there is no Overlay for a Tooltip, so
            // the two controls carry their names as semantics instead.
            _PillButton(
              key: const ValueKey('recording-indicator-pause'),
              label: paused
                  ? (l10n?.taskRecorderResume ?? 'Resume')
                  : (l10n?.taskRecorderPause ?? 'Pause'),
              icon: paused ? Icons.play_arrow : Icons.pause,
              onTap: paused ? controller.resume : controller.pause,
            ),
            _PillButton(
              key: const ValueKey('recording-indicator-stop'),
              label: l10n?.taskRecorderStop ?? 'Stop',
              icon: Icons.stop,
              onTap: () async {
                await controller.stop();
                ref.invalidate(myRecordingsProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: InkWell(
      key: const ValueKey('recording-indicator-ink-well'),
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox.square(
        dimension: 48,
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
    ),
  );
}
