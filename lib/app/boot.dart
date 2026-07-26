// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/trace/trace_logger.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/plan/domain/level.dart';
import '../features/plan/providers/floor_plan_providers.dart';
import '../features/reservations/providers/reservation_providers.dart';
import '../features/workspace/providers/workspace_providers.dart';

part 'boot.g.dart';

/// Overall cap on the warm-up: a slow or broken backend may only ever
/// DELAY the app by this much — the screens keep their own loading and
/// error states as the fallback.
const Duration bootBudget = Duration(seconds: 6);

/// Warm-up of everything the first screen needs (field request: the
/// user must never watch the form being constructed). The boot splash
/// stays up until this resolves; each step is failure-proof, so boot
/// can be slow but never stuck or fatal.
@Riverpod(keepAlive: true)
Future<void> bootReady(Ref ref) async {
  final started = DateTime.now();
  try {
    await _warm(ref).timeout(bootBudget);
  } catch (e, st) {
    // Purely a warm-up — the app opens regardless and the screens
    // surface their own errors; still traced for diagnosis.
    TraceLogger.instance
        .warn('boot', 'warm-up incomplete', error: e, stackTrace: st);
  }
  TraceLogger.instance.log(
    TraceLevel.info,
    'boot',
    'warm-up finished in ${DateTime.now().difference(started).inMilliseconds} ms',
  );
}

Future<void> _warm(Ref ref) async {
  // Individual steps never throw out of the warm-up: a failed piece just
  // loads late behind its screen's own state.
  Future<void> tolerant(Future<Object?> future) =>
      future.then<void>((_) {}, onError: (Object e, StackTrace st) {
        TraceLogger.instance.warn('boot', 'warm-up step skipped: $e');
      });

  // Auth first — everything below depends on the session.
  await tolerant(ref.read(authStateProvider.future));
  // The active workspace decides what home shows; null (signed out or
  // onboarding) means there is nothing more to warm.
  final workspace =
      await ref.read(currentWorkspaceProvider.future).catchError((_) => null);
  if (workspace == null) return;

  // The Reserve hub's data, in parallel: levels + plan of the first
  // level (the canvas), today's reservations (seat states), membership
  // and granularity (window chips and gates).
  final levels = await ref.read(levelsProvider.future).catchError(
        (_) => const <Level>[],
      );
  await Future.wait([
    if (levels.isNotEmpty)
      tolerant(ref.read(floorPlanProvider(levels.first.id).future)),
    tolerant(
      ref.read(reservationsForDayProvider(dayKeyOf(DateTime.now())).future),
    ),
    tolerant(ref.read(myMemberProvider.future)),
    tolerant(ref.read(bookingGranularityProvider.future)),
  ]);
}
