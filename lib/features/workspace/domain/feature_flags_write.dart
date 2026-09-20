// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1329 — what a feature-flag write can answer besides "done".

/// The flags changed on the server since the preview read them: nothing
/// was written (`set_feature_flags`, 0245, SQLSTATE DK409). The caller
/// refetches, recomputes the preview and asks again — never replays the
/// old delta.
class FeatureFlagsConflict implements Exception {
  const FeatureFlagsConflict(this.keys);

  static const String sqlState = 'DK409';

  /// The read-set keys whose value moved, as the server named them.
  final List<String> keys;

  @override
  String toString() =>
      'FeatureFlagsConflict: the features changed since they were read: '
      '${keys.join(', ')}';
}

/// The write went through, and the refetch that would confirm it did
/// not: the row is what the server holds, the screen may not be. The UI
/// says so instead of claiming either success or failure.
class FeatureFlagsUnconfirmed implements Exception {
  const FeatureFlagsUnconfirmed(this.cause);

  final Object cause;

  @override
  String toString() => 'FeatureFlagsUnconfirmed: $cause';
}
