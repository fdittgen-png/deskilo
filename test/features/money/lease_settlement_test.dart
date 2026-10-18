// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2569 C2a -- the year-end settlement of a lease's service charges: what the
// command refuses before sending, and the balance the demo twin keeps in step
// with the server (pgTAP 225): advances 200.00 a month, billed 2 700.00 over
// twelve months leaves 300.00 owed, billed 1 000.00 over six leaves a credit
// of 200.00, and a period is never settled twice.
import 'package:deskilo/core/demo/data/premises_lease_repository.dart';
import 'package:deskilo/features/money/application/lease_commands.dart';
import 'package:deskilo/features/money/domain/premises_lease.dart';
import 'package:flutter_test/flutter_test.dart';

final _today = DateTime(2026, 10, 18);

LeaseSettlementCommand _settle(
  PremisesLease lease, {
  required DateTime from,
  required DateTime to,
  required int billed,
  required DateTime due,
  String request = 's1',
}) => LeaseSettlementCommand(
  leaseId: lease.id,
  revision: lease.revision,
  periodStart: from,
  periodEnd: to,
  actualCents: billed,
  dueOn: due,
  requestId: request,
);

Future<(LeaseCommands, FakePremisesLeaseRepository, PremisesLease)>
_withAdvances() async {
  final repo = FakePremisesLeaseRepository();
  final commands = LeaseCommands(repo);
  var lease = (await commands.save(
    'w',
    LeaseDraft(
      supplierId: 'sup-1',
      premises: '12 rue des Halles',
      startsOn: DateTime(2025),
      requestId: 'r-lease',
    ),
  ))!;
  lease = (await commands.addTerm(
    'w',
    lease,
    LeaseTermCommand(
      leaseId: lease.id,
      revision: lease.revision,
      kind: LeaseTermKind.serviceChargeAdvance,
      amountCents: 20000,
      effectiveFrom: DateTime(2025),
      requestId: 'r-term',
    ),
  ))!;
  return (commands, repo, lease);
}

void main() {
  test('twelve advances against a larger bill leave a balance owed', () async {
    final (commands, _, lease) = await _withAdvances();
    final done = await commands.settle(
      'w',
      lease,
      _settle(
        lease,
        from: DateTime(2025),
        to: DateTime(2025, 12, 31),
        billed: 270000,
        due: DateTime(2026, 2),
      ),
      _today,
    );
    final s = done!.settlements.single;
    expect(s.advancesCents, 240000);
    expect(s.owedCents, 30000);
    expect(s.creditCents, 0);
    expect(done.terms.where((t) => t.kind == LeaseTermKind.other).single.amountCents, 30000);
  });

  test('a smaller bill is a credit and schedules nothing', () async {
    final (commands, _, lease) = await _withAdvances();
    final done = await commands.settle(
      'w',
      lease,
      _settle(
        lease,
        from: DateTime(2026),
        to: DateTime(2026, 6, 30),
        billed: 100000,
        due: DateTime(2026, 7, 31),
      ),
      _today,
    );
    expect(done!.settlements.single.creditCents, 20000);
    expect(done.terms.where((t) => t.kind == LeaseTermKind.other), isEmpty);
  });

  test('the same request answers the original', () async {
    final (commands, repo, lease) = await _withAdvances();
    final command = _settle(
      lease,
      from: DateTime(2025),
      to: DateTime(2025, 12, 31),
      billed: 270000,
      due: DateTime(2026, 2),
    );
    final first = await commands.settle('w', lease, command, _today);
    final again = await commands.settle('w', lease, command, _today);
    expect(again, same(first));
    expect(repo.leases.single.settlements, hasLength(1));
  });

  test('nothing is sent for a period still running, a negative bill or an early due day', () async {
    final (commands, repo, lease) = await _withAdvances();
    Future<PremisesLease?> tryIt(DateTime to, int billed, DateTime due) => commands.settle(
      'w',
      lease,
      _settle(lease, from: DateTime(2026), to: to, billed: billed, due: due, request: 'x$billed$due'),
      _today,
    );
    expect(await tryIt(DateTime(2026, 12, 31), 1, DateTime(2027)), isNull);
    expect(await tryIt(DateTime(2026, 6, 30), -1, DateTime(2026, 7)), isNull);
    expect(await tryIt(DateTime(2026, 6, 30), 1, DateTime(2026, 6)), isNull);
    expect(repo.leases.single.settlements, isEmpty);
  });

  test('a period that overlaps a settled one is refused by the twin as by the server', () async {
    final (commands, _, lease) = await _withAdvances();
    final done = (await commands.settle(
      'w',
      lease,
      _settle(lease, from: DateTime(2025), to: DateTime(2025, 12, 31), billed: 240000, due: DateTime(2026, 2)),
      _today,
    ))!;
    expect(
      commands.settle(
        'w',
        done,
        _settle(done, from: DateTime(2025, 6), to: DateTime(2025, 7, 31), billed: 1, due: DateTime(2025, 8), request: 's2'),
        _today,
      ),
      throwsStateError,
    );
  });
}
