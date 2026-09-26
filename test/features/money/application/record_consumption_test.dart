// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1449 — the shelf and the month decide whether a consumption is
// written at all, and the command refuses what the rule does not allow.
// Both rules used to live in the sheet's disabled states, where nothing
// could state them and a mistyped period wrote nothing without saying
// so.
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/features/money/application/record_consumption.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:flutter_test/flutter_test.dart';

ServiceItem _service({int? stock, bool active = true}) => ServiceItem(
  id: 'svc-1',
  workspaceId: 'ws-1',
  name: 'Coffee',
  priceCents: 200,
  active: active,
  stock: stock,
);

Future<ConsumptionOutcome> _record(
  FakeMoneyRepository repo, {
  required ServiceItem service,
  int quantity = 1,
  String period = '2026-09',
}) => Consumptions(repo).record(
  workspaceId: 'ws-1',
  subjectMemberId: 'm-1',
  service: service,
  quantity: quantity,
  period: period,
);

void main() {
  group('the shelf', () {
    test('an untracked service never runs out', () async {
      final repo = FakeMoneyRepository()..services.add(_service());
      expect(
        await _record(repo, service: _service(), quantity: 999),
        ConsumptionOutcome.filed,
      );
      expect(repo.recordedServiceCharges.single.quantity, 999);
    });

    test(
      'more units than the shelf holds is refused, and NOTHING is written',
      () async {
        final repo = FakeMoneyRepository()..services.add(_service(stock: 2));
        expect(
          await _record(repo, service: _service(stock: 2), quantity: 3),
          ConsumptionOutcome.insufficientStock,
        );
        expect(
          repo.recordedServiceCharges,
          isEmpty,
          reason: 'the member would be billed for units nobody handed them',
        );
      },
    );

    test('exactly what the shelf holds is allowed', () async {
      final repo = FakeMoneyRepository()..services.add(_service(stock: 2));
      expect(
        await _record(repo, service: _service(stock: 2), quantity: 2),
        ConsumptionOutcome.filed,
      );
    });

    test('an empty shelf serves nobody', () {
      expect(servesQuantity(_service(stock: 0), 1), isFalse);
    });

    test('a service off the catalogue cannot be consumed', () async {
      final repo = FakeMoneyRepository();
      expect(
        await _record(repo, service: _service(active: false)),
        ConsumptionOutcome.serviceInactive,
      );
      expect(repo.recordedServiceCharges, isEmpty);
    });
  });

  group('the month', () {
    test(
      'a period that is not a month is refused, not silently dropped',
      () async {
        final repo = FakeMoneyRepository()..services.add(_service());
        expect(
          await _record(repo, service: _service(), period: 'September'),
          ConsumptionOutcome.periodNotAMonth,
        );
        expect(repo.recordedServiceCharges, isEmpty);
      },
    );

    test('a month outside 01-12 names no bill and is refused', () async {
      for (final period in ['2026-00', '2026-13', '2026-99']) {
        final repo = FakeMoneyRepository()..services.add(_service());
        expect(
          await _record(repo, service: _service(), period: period),
          ConsumptionOutcome.periodNotAMonth,
          reason: period,
        );
        expect(repo.recordedServiceCharges, isEmpty, reason: period);
      }
      for (final period in ['2026-01', '2026-12', ' 2026-12 ']) {
        expect(isBillingMonth(period), isTrue, reason: period);
      }
    });

    test('a server refusal after the rules passed is not filed', () async {
      final repo = _RefusingMoneyRepository()..services.add(_service());
      await expectLater(_record(repo, service: _service()), throwsStateError);
      expect(repo.recordedServiceCharges, isEmpty);
    });

    test('the month is what lands on the charge, trimmed', () async {
      final repo = FakeMoneyRepository()..services.add(_service());
      expect(
        await _record(repo, service: _service(), period: ' 2026-09 '),
        ConsumptionOutcome.filed,
      );
      expect(repo.recordedServiceCharges.single.period, '2026-09');
    });
  });

  group('the quantity', () {
    test('zero is nothing to record', () async {
      final repo = FakeMoneyRepository()..services.add(_service());
      expect(
        await _record(repo, service: _service(), quantity: 0),
        ConsumptionOutcome.quantityOutOfRange,
      );
      expect(repo.recordedServiceCharges, isEmpty);
    });

    test('above the RPC ceiling is refused here, not over the wire', () async {
      final repo = FakeMoneyRepository()..services.add(_service());
      expect(
        await _record(repo, service: _service(), quantity: 1000),
        ConsumptionOutcome.quantityOutOfRange,
      );
      expect(repo.recordedServiceCharges, isEmpty);
    });
  });
}

/// The server says no after the local rules passed.
class _RefusingMoneyRepository extends FakeMoneyRepository {
  @override
  Future<void> recordServiceCharge({
    required String workspaceId,
    required String subjectMemberId,
    required String serviceId,
    required int quantity,
    String? period,
  }) async => throw StateError('refused by the server');
}
