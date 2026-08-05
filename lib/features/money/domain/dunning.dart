// SPDX-License-Identifier: 0BSD

/// Mahnwesen (#472): the parameterizable dunning policy of a workspace,
/// stored in `workspaces.dunning_rules` (migration 0093) — and the pure
/// suggestion rule derived from it. Nothing ever fires automatically: a
/// human always sends; the app only SAYS when a reminder is due.
class DunningRules {
  const DunningRules({
    this.levels = 3,
    this.firstAfterDays = 14,
    this.betweenDays = 14,
  });

  factory DunningRules.fromJson(Map<String, dynamic> json) {
    int read(String key, int fallback, {int min = 1, int max = 365}) {
      final v = (json[key] as num?)?.toInt() ?? fallback;
      return v.clamp(min, max);
    }

    return DunningRules(
      levels: read(keyLevels, 3, max: 9),
      firstAfterDays: read(keyFirstAfterDays, 14),
      betweenDays: read(keyBetweenDays, 14),
    );
  }

  /// Maximum number of reminder levels (level 1 = the friendly
  /// Zahlungserinnerung; higher levels read firmer).
  final int levels;

  /// Days after ISSUE before level 1 is suggested.
  final int firstAfterDays;

  /// Days after the previous reminder before the next level is
  /// suggested.
  final int betweenDays;

  static const String keyLevels = 'levels';
  static const String keyFirstAfterDays = 'first_after_days';
  static const String keyBetweenDays = 'between_days';

  static const DunningRules defaults = DunningRules();

  Map<String, int> toJson() => {
        keyLevels: levels,
        keyFirstAfterDays: firstAfterDays,
        keyBetweenDays: betweenDays,
      };

  DunningRules copyWith({
    int? levels,
    int? firstAfterDays,
    int? betweenDays,
  }) =>
      DunningRules(
        levels: levels ?? this.levels,
        firstAfterDays: firstAfterDays ?? this.firstAfterDays,
        betweenDays: betweenDays ?? this.betweenDays,
      );

  @override
  bool operator ==(Object other) =>
      other is DunningRules &&
      other.levels == levels &&
      other.firstAfterDays == firstAfterDays &&
      other.betweenDays == betweenDays;

  @override
  int get hashCode => Object.hash(levels, firstAfterDays, betweenDays);
}

/// The reminder level DUE for an open invoice under [rules], or null
/// when none is: all levels sent, or the waiting period still runs. The
/// clock for level 1 starts at [issuedAt]; every further level waits
/// [DunningRules.betweenDays] after the PREVIOUS reminder.
int? dueReminderLevel({
  required DateTime issuedAt,
  required int reminderCount,
  required DateTime? lastReminderAt,
  required DunningRules rules,
  required DateTime now,
}) {
  if (reminderCount >= rules.levels) return null;
  final since = reminderCount == 0 ? issuedAt : lastReminderAt ?? issuedAt;
  final waitDays =
      reminderCount == 0 ? rules.firstAfterDays : rules.betweenDays;
  if (now.difference(since).inDays < waitDays) return null;
  return reminderCount + 1;
}
