// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1922 (0334) — what happened to a payment reminder, as the server
// recorded it: the intent (which level, prepared by hand or by the daily
// sweep, for what amount) and its append-only attempts. A status is a
// statement about delivery, never about payment.

/// One delivery attempt of a reminder, as appended on the server.
class ReminderAttempt {
  const ReminderAttempt({
    required this.channel,
    required this.outcome,
    required this.detail,
    required this.at,
  });

  factory ReminderAttempt.fromJson(Map<String, dynamic> json) =>
      ReminderAttempt(
        channel: json['channel'] as String? ?? '',
        outcome: json['outcome'] as String? ?? '',
        detail: json['detail'] as String? ?? '',
        at: DateTime.parse(json['at'] as String).toLocal(),
      );

  final String channel;
  final String outcome;
  final String detail;
  final DateTime at;
}

/// One reminder and what is known about its delivery.
class ReminderEvidence {
  const ReminderEvidence({
    required this.intentId,
    required this.level,
    required this.origin,
    required this.status,
    required this.preparedAt,
    this.collectibleCents,
    this.currency,
    this.attempts = const [],
  });

  factory ReminderEvidence.fromJson(Map<String, dynamic> json) =>
      ReminderEvidence(
        intentId: json['intent_id'] as String,
        level: (json['level'] as num).toInt(),
        origin: json['origin'] as String? ?? 'legacy',
        status: json['status'] as String? ?? 'legacy_unknown',
        preparedAt: DateTime.parse(json['prepared_at'] as String).toLocal(),
        collectibleCents: (json['collectible_cents'] as num?)?.toInt(),
        currency: json['currency'] as String?,
        attempts: [
          for (final attempt in (json['attempts'] as List? ?? const []))
            ReminderAttempt.fromJson(Map<String, dynamic>.from(attempt as Map)),
        ],
      );

  final String intentId;
  final int level;

  /// `manual`, `automatic` or `legacy`.
  final String origin;

  /// `prepared`, `queued`, `provider_accepted`, `declared_delivered`,
  /// `failed`, `unknown` or `legacy_unknown`.
  final String status;
  final DateTime preparedAt;
  final int? collectibleCents;
  final String? currency;
  final List<ReminderAttempt> attempts;
}
