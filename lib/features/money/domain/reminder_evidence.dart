// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1922 (0334) — what happened to a payment reminder, as the server
// recorded it: the intent (which level, prepared by hand or by the daily
// sweep, for what amount) and its append-only attempts. A status is a
// statement about delivery, never about payment.

import '../../../core/data/json_reader.dart';

/// One delivery attempt of a reminder, as appended on the server.
class ReminderAttempt {
  const ReminderAttempt({
    required this.channel,
    required this.outcome,
    required this.detail,
    required this.at,
  });

  factory ReminderAttempt.fromJson(Map<String, dynamic> json) {
    final r = JsonReader(json, context: 'reminder_attempt');
    return ReminderAttempt(
      channel: r.stringOr('channel'),
      outcome: r.stringOr('outcome'),
      detail: r.stringOr('detail'),
      at: r.dateTime('at').toLocal(),
    );
  }

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

  factory ReminderEvidence.fromJson(Map<String, dynamic> json) {
    final r = JsonReader(json, context: 'invoice_reminder_evidence');
    return ReminderEvidence(
      intentId: r.string('intent_id'),
      level: r.integer('level'),
      origin: r.stringOr('origin', 'legacy'),
      status: r.stringOr('status', 'legacy_unknown'),
      preparedAt: r.dateTime('prepared_at').toLocal(),
      collectibleCents: r.intOrNull('collectible_cents'),
      currency: r.stringOrNull('currency'),
      attempts:
          r.objects('attempts', (row) => ReminderAttempt.fromJson(row.json)),
    );
  }

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
