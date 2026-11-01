// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2370 — what a delivery to a connection answers, read as the server
// writes it, and a year asked month by month: the months up to today, the
// first refusal of a whole month ending the run.
import 'package:deskilo/core/data/json_reader.dart';
import 'package:deskilo/core/demo/data/accounting_connection_repository.dart';
import 'package:deskilo/core/demo/data/book_period_repository.dart';
import 'package:deskilo/core/demo/seed/demo_book_period_seed.dart';
import 'package:deskilo/features/money/application/accounting_connection_commands.dart';
import 'package:deskilo/features/money/domain/accounting_delivery_run.dart';
import 'package:flutter_test/flutter_test.dart';

final _today = DateTime(2026, 3, 9);

class _Months extends FakeAccountingConnectionRepository {
  _Months(FakeAccountingConnectionRepository seeded, this.answers)
    : super(
        books: seeded.books,
        today: seeded.today,
        connections: seeded.connections,
        deliveries: seeded.deliveries,
      );

  final List<DeliveryRun> answers;
  final List<DateTime> asked = [];

  @override
  Future<DeliveryRun> deliver(
    String connectionId, {
    required DateTime from,
    required DateTime to,
    ({String kind, String id})? document,
  }) async {
    asked.add(from);
    return answers[asked.length - 1];
  }
}

void main() {
  test('a run reads what each document became', () {
    final run = DeliveryRunDone.fromJson({
      'results': [
        {
          'document_kind': 'invoice',
          'document_number': 'F-1',
          'status': 'acknowledged',
        },
        {
          'document_kind': 'receipt',
          'status': 'blocked',
          'missing': ['account bank'],
        },
        {'document_kind': 'refund', 'status': 'unchanged'},
      ],
      'counts': {'acknowledged': 1, 'blocked': 1, 'unchanged': 1},
    });
    expect(run.count(DeliveryRunStatus.acknowledged), 1);
    expect(run.count(DeliveryRunStatus.unchanged), 1);
    expect(run.needingAttention, 1);
    expect(run.missing, ['account bank']);
  });

  test('#2374 — a draft the target refused to post needs attention, with '
      'the target\'s words', () {
    final run = DeliveryRunDone.fromJson({
      'results': [
        {
          'document_kind': 'invoice',
          'status': 'sent',
          'detail': 'not posted: 403 posting is not permitted',
        },
      ],
    });
    expect(run.count(DeliveryRunStatus.sent), 1);
    expect(run.count(DeliveryRunStatus.acknowledged), 0);
    expect(run.needingAttention, 1);
    expect(run.details, ['not posted: 403 posting is not permitted']);
  });

  test('a delivery another run is still sending is in flight and needs a '
      'second look later, not a failure', () {
    final run = DeliveryRunDone.fromJson({
      'results': [
        {'document_kind': 'invoice', 'status': 'in_flight'},
        {'document_kind': 'receipt', 'status': 'acknowledged'},
      ],
    });
    expect(DeliveryRunStatus.of('in_flight'), DeliveryRunStatus.inFlight);
    expect(run.count(DeliveryRunStatus.inFlight), 1);
    expect(run.count(DeliveryRunStatus.failed), 0);
    expect(run.needingAttention, 1);
  });

  test('an answer without its results is never an empty run', () {
    expect(
      () => DeliveryRunDone.fromJson({'counts': <String, Object?>{}}),
      throwsA(isA<JsonShapeException>()),
    );
    expect(DeliveryRunStatus.of('weird'), DeliveryRunStatus.failed);
  });

  test('the words of a document that needs attention are kept, once', () {
    final run = DeliveryRunDone.fromJson({
      'results': [
        {'status': 'failed', 'detail': 'needs a correction'},
        {'status': 'conflict', 'detail': 'needs a correction'},
        {'status': 'acknowledged', 'detail': 'ignored'},
      ],
    });
    expect(run.details, ['needs a correction']);
  });

  test('a refusal of the whole run says which, and any other body is none', () {
    expect(
      (deliveryRunRefusal({
                'error': 'books_blocked',
                'blockers': [
                  {'block': 'unmappedRole', 'subject': 'bank'},
                ],
              })!
              as DeliveryRunBooksBlocked)
          .subjects,
      ['bank'],
    );
    expect(
      (deliveryRunRefusal({'error': 'target_refused', 'detail': 'numbers'})!
              as DeliveryRunTargetRefused)
          .detail,
      'numbers',
    );
    expect(
      deliveryRunRefusal({'error': 'not_connected'}),
      isA<DeliveryRunNotConnected>(),
    );
    expect(deliveryRunRefusal({'error': 'something else'}), isNull);
    expect(deliveryRunRefusal('not a body'), isNull);
  });

  test('a year is asked month by month up to today', () {
    expect(deliveryMonths(2026, _today).map((m) => (m.from.month, m.to.day)), [
      (1, 31),
      (2, 28),
      (3, 31),
    ]);
    expect(deliveryMonths(2027, _today), isEmpty);
  });

  test(
    'the first month refused as a whole ends the run; the months before stay',
    () async {
      final seeded = seedDemoAccountingConnections(
        FakeBookPeriodRepository(today: _today),
        _today,
      );
      final repo = _Months(seeded, const [
        DeliveryRunDone([
          DeliveryRunDocument(status: DeliveryRunStatus.acknowledged),
        ]),
        DeliveryRunBooksBlocked(['bank']),
        DeliveryRunDone([]),
      ]);
      final run = await AccountingConnectionCommands(repo)
          .deliverYear(seeded.connections.single, 2026, _today);
      final stopped = run as DeliveryRunStopped;
      expect(stopped.reason, isA<DeliveryRunBooksBlocked>());
      expect(stopped.month, DateTime(2026, 2));
      expect(stopped.before.count(DeliveryRunStatus.acknowledged), 1);
      expect(repo.asked, [DateTime(2026), DateTime(2026, 2)]);
    },
  );
}
