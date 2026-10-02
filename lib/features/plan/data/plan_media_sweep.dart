// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2012 B — the bounded cleanup after a plan-media write. The server names
// at most 100 objects of this workspace that no plan image or level points
// at and that are older than a day (0332 `plan_media_orphans`, owner
// only); they are removed through Storage's own policies. Best effort and
// resumable: a failure is traced and the next write sweeps again, and a
// write never fails because its cleanup did.
import '../../../core/trace/trace_logger.dart';

/// Removes what [list] names through [remove]; returns how many.
Future<int> sweepPlanMediaOrphans({
  required Future<List<String>> Function() list,
  required Future<void> Function(List<String> paths) remove,
}) async {
  try {
    final paths = await list();
    if (paths.isEmpty) return 0;
    await remove(paths);
    return paths.length;
  } catch (e, st) {
    TraceLogger.instance.warn(
      'plan',
      'plan media cleanup deferred',
      error: e,
      stackTrace: st,
    );
    return 0;
  }
}
