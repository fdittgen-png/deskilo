// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2015 — the essential start-up (stored backend, secure storage, the
// Supabase singleton, the auth-callback guard) is started ONCE and given a
// deadline. Past the deadline, or on a failure, the person sees a truthful
// recovery screen instead of a blank frame or an app whose every provider
// would touch an uninitialised client. The attempt is never cancelled and
// never started twice (a second Supabase.initialize is not allowed): a
// late success is observed and hands over to the real app; a late failure
// is traced and the screen says it failed.
import 'dart:async';

import 'package:flutter/material.dart';

import '../core/ui/loading_view.dart';
import '../l10n/app_localizations.dart';

enum BootState { starting, ready, failed, slow }

/// How long the essential start-up may take before the person is told.
const kEssentialBootDeadline = Duration(seconds: 15);

/// The one essential start-up attempt, observed to the end.
class EssentialBoot {
  EssentialBoot(Future<void> attempt) {
    attempt.then(
      (_) => _set(BootState.ready),
      onError: (Object e, StackTrace st) {
        error = e;
        _set(BootState.failed);
      },
    );
  }

  final state = ValueNotifier(BootState.starting);
  Object? error;

  void _set(BootState s) {
    if (state.value == BootState.ready || state.value == BootState.failed) {
      return;
    }
    state.value = s;
  }

  /// The state once the attempt settled or [deadline] passed, whichever
  /// is first. [deadline] is a future so tests need no wall clock.
  Future<BootState> settle(Future<void> deadline) async {
    if (state.value != BootState.starting) return state.value;
    final done = Completer<BootState>();
    void listener() {
      if (state.value != BootState.starting && !done.isCompleted) {
        done.complete(state.value);
      }
    }

    state.addListener(listener);
    unawaited(
      deadline.then((_) {
        if (!done.isCompleted && state.value == BootState.starting) {
          state.value = BootState.slow;
        }
      }),
    );
    final result = await done.future;
    state.removeListener(listener);
    return result;
  }
}

/// What the person sees while the essential start-up is slow or failed:
/// localized, nothing sensitive (no host, no token), and the only honest
/// action — the app cannot start a second attempt in this process.
/// [onReady] runs once if a slow attempt completes after all.
class BootRecoveryApp extends StatefulWidget {
  const BootRecoveryApp({super.key, required this.boot, required this.onReady});

  final EssentialBoot boot;
  final VoidCallback onReady;

  @override
  State<BootRecoveryApp> createState() => _BootRecoveryAppState();
}

class _BootRecoveryAppState extends State<BootRecoveryApp> {
  @override
  void initState() {
    super.initState();
    widget.boot.state.addListener(_changed);
  }

  @override
  void dispose() {
    widget.boot.state.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (widget.boot.state.value == BootState.ready) {
      widget.onReady();
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: _BootRecoveryScreen(
      failed: widget.boot.state.value == BootState.failed,
    ),
  );
}

class _BootRecoveryScreen extends StatelessWidget {
  const _BootRecoveryScreen({required this.failed});

  final bool failed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (failed)
                  const Icon(Icons.cloud_off_outlined, size: 48)
                else
                  const SizedBox(height: 48, child: LoadingView()),
                const SizedBox(height: 16),
                Text(
                  key: ValueKey(failed ? 'boot-failed' : 'boot-slow'),
                  failed
                      ? (l10n?.bootFailedTitle ?? 'DesKilo could not start')
                      : (l10n?.bootSlowTitle ??
                            'Starting is taking longer than usual'),
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  failed
                      ? (l10n?.bootFailedBody ??
                            'The server or this device\'s secure storage did not answer. Nothing was changed. Close the app and open it again; if it keeps happening, check the network.')
                      : (l10n?.bootSlowBody ??
                            'It keeps trying. If nothing happens, close the app and open it again.'),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
