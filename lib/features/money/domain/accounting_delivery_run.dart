// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What a delivery to a connection answers (`accounting-connect`, action
// `deliver`): what each document event became, or why nothing was
// delivered at all. The server owns every rule; this is what it says.
//
// Pure Dart.
import '../../../core/data/json_reader.dart';

/// What one document event became in a run.
enum DeliveryRunStatus {
  /// Received by the target now.
  acknowledged('acknowledged'),

  /// Already received: nothing was sent.
  unchanged('unchanged'),

  /// The target's answer is missing or differs: a person checks it.
  conflict('conflict'),

  /// The target refused it, with its words.
  failed('failed'),

  /// A mapping it needs is missing; nothing was sent.
  blocked('blocked');

  const DeliveryRunStatus(this.wire);
  final String wire;

  static DeliveryRunStatus of(String? wire) =>
      values.firstWhere((v) => v.wire == wire, orElse: () => failed);

  /// Whether a person has to look at it.
  bool get needsAttention =>
      this == conflict || this == failed || this == blocked;
}

/// What one document event of a run became.
class DeliveryRunDocument {
  const DeliveryRunDocument({required this.status, this.missing = const []});

  factory DeliveryRunDocument.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'delivery run document');
    return DeliveryRunDocument(
      status: DeliveryRunStatus.of(r.stringOrNull('status')),
      missing: r.strings('missing'),
    );
  }

  final DeliveryRunStatus status;

  /// The mapping keys it waits for, as `kind key`.
  final List<String> missing;
}

/// The answer to a delivery.
sealed class DeliveryRun {
  const DeliveryRun();
}

/// The run went through; [documents] says what each became.
final class DeliveryRunDone extends DeliveryRun {
  const DeliveryRunDone(this.documents);

  factory DeliveryRunDone.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'delivery run');
    return DeliveryRunDone([
      for (final d in r.list('results')) DeliveryRunDocument.fromJson(d),
    ]);
  }

  final List<DeliveryRunDocument> documents;

  int count(DeliveryRunStatus status) =>
      documents.where((d) => d.status == status).length;

  int get needingAttention =>
      documents.where((d) => d.status.needsAttention).length;

  /// Every mapping key a document waits for, once each, in order.
  List<String> get missing =>
      ({for (final d in documents) ...d.missing}.toList()..sort());

  /// This run followed by [next].
  DeliveryRunDone then(DeliveryRunDone next) =>
      DeliveryRunDone([...documents, ...next.documents]);
}

/// The books of the period cannot be posted: nothing was delivered.
/// [subjects] names each blocker (a role, a document number).
final class DeliveryRunBooksBlocked extends DeliveryRun {
  const DeliveryRunBooksBlocked(this.subjects);
  final List<String> subjects;
}

/// The target refused the company before any document, with its words.
final class DeliveryRunTargetRefused extends DeliveryRun {
  const DeliveryRunTargetRefused(this.detail);
  final String detail;
}

/// The connection is not signed in any more: it is connected again first.
final class DeliveryRunNotConnected extends DeliveryRun {
  const DeliveryRunNotConnected();
}

/// What the server's refusal of a whole run says (its HTTP 409 body), or
/// null for any other body.
DeliveryRun? deliveryRunRefusal(Object? body) {
  if (body is! Map) return null;
  final r = JsonReader.of(body, context: 'delivery refusal');
  return switch (r.stringOrNull('error')) {
    'books_blocked' => DeliveryRunBooksBlocked([
      for (final b in r.list('blockers'))
        JsonReader.of(b, context: 'delivery blocker').stringOr('subject'),
    ]),
    'target_refused' => DeliveryRunTargetRefused(r.stringOr('detail')),
    'not_connected' => const DeliveryRunNotConnected(),
    _ => null,
  };
}

/// The months a delivery of [year] asks for, one run each, up to [today]:
/// a run lies within one calendar month on the server.
List<({DateTime from, DateTime to})> deliveryMonths(int year, DateTime today) =>
    [
      for (var month = 1; month <= 12; month++)
        if (!DateTime(year, month).isAfter(today))
          (from: DateTime(year, month), to: DateTime(year, month + 1, 0)),
    ];
