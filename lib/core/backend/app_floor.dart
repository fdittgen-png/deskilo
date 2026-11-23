// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../instance/app_compatibility.dart';
import '../lifecycle/app_foreground.dart';
import '../trace/trace_logger.dart';
import 'context_client_providers.dart';
import 'schema_version.dart';

part 'app_floor.g.dart';

/// #3726 — the floor could not be asked: no network, a timeout, a malformed
/// answer. Distinct from an installation without the function, which is an
/// answer: it has no floor.
@visibleForTesting
class AppFloorUnavailable implements Exception {
  const AppFloorUnavailable(this.cause);
  final Object cause;
  @override
  String toString() => 'app floor unavailable: $cause';
}

/// Reads `deskilo_app_floor()` from an installation.
abstract interface class AppFloorSource {
  /// The oldest app compatibility number the installation accepts, or null
  /// for no floor — also when the installation has no such function. Throws
  /// [AppFloorUnavailable] when nothing answered.
  Future<int?> read();
}

/// Asks [client]. A missing function is an answer (no floor); silence and
/// anything but an integer or null are not.
Future<int?> _readAppFloor(SupabaseClient client) async {
  final Object? value;
  try {
    value = await client
        .rpc<Object?>('deskilo_app_floor')
        .timeout(const Duration(seconds: 8));
  } on PostgrestException catch (e, st) {
    if (isMissingFunction(e)) return null;
    // trace-exempt: rethrown as a typed failure, stack kept; the caller traces.
    Error.throwWithStackTrace(AppFloorUnavailable(e), st);
  } catch (e, st) {
    // trace-exempt: rethrown as a typed failure, stack kept; the caller traces.
    Error.throwWithStackTrace(AppFloorUnavailable(e), st);
  }
  if (value == null || value is int) return value as int?;
  throw AppFloorUnavailable('not an integer: $value');
}

class _ClientAppFloorSource implements AppFloorSource {
  const _ClientAppFloorSource(this._client);
  final SupabaseClient _client;

  @override
  Future<int?> read() => _readAppFloor(_client);
}

/// The floor of the installation this device is signed in to (or would
/// sign in to): the personal home's client.
@Riverpod(keepAlive: true)
AppFloorSource appFloorSource(Ref ref) =>
    _ClientAppFloorSource(ref.watch(personalClientProvider));

/// The last verdict an installation's floor gave, kept for the process.
/// A failed refresh never erases it (decision on #3726, point 2).
class AppFloorMemory {
  AppFloorVerdict? known;
}

@Riverpod(keepAlive: true)
AppFloorMemory appFloorMemory(Ref ref) => AppFloorMemory();

/// How the installation this device uses judges this app.
///
/// - A successful answer decides, and is remembered.
/// - A failed read keeps the remembered verdict: an installation known to
///   refuse this app stays refused while it cannot be asked. A floor never
///   read is [AppFloorVerdict.unknown], which never blocks.
/// - It is asked again each time the app returns to the foreground (an
///   event, never a timer), so a lowered floor or an updated installation
///   is seen without a restart.
@Riverpod(keepAlive: true)
Future<AppFloorVerdict> appFloor(Ref ref) async {
  ref.onDispose(onReturnToForeground(ref.invalidateSelf));
  final memory = ref.read(appFloorMemoryProvider);
  try {
    final floor = await ref.read(appFloorSourceProvider).read();
    final verdict = judgeAppFloor(floor);
    if (verdict == AppFloorVerdict.below) {
      TraceLogger.instance.warn(
        'backend',
        'app below the installation floor: floor $floor, '
            'app $appCompatibilityNumber',
      );
    }
    return memory.known = verdict;
  } on Object catch (e, st) {
    TraceLogger.instance.warn(
      'backend',
      'app floor could not be read — keeping ${memory.known ?? 'no verdict'}',
      error: e,
      stackTrace: st,
    );
    return memory.known ?? AppFloorVerdict.unknown;
  }
}
