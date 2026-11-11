// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-f -- the reminders shared by hand: grouped by level, most late
// first; a share records its level only if it left; a dismissed sheet records
// nothing and the line stays in the queue.
import 'dart:typed_data';

import 'package:deskilo/core/share/file_sharer.dart';
import 'package:deskilo/features/money/application/receivables.dart';
import 'package:deskilo/features/money/application/receivables_answers.dart';
import 'package:deskilo/features/money/application/reminder_queue.dart';
import 'package:deskilo/features/money/domain/invoice_commands.dart';
import 'package:flutter_test/flutter_test.dart';

final _today = DateTime(2026, 11, 10);

Receivable _r(
  String id, {
  int? level = 1,
  int dueInDays = -5,
  int open = 10000,
  bool onHold = false,
  bool pending = false,
  bool rejected = false,
}) => Receivable(
  invoiceId: id,
  customerId: 'c-$id',
  customerName: 'Customer $id',
  number: 'INV-$id',
  currency: 'EUR',
  totalMinor: open,
  openMinor: open,
  issuedOn: DateTime(2026, 9),
  stage: ReceivableStage.open,
  dueOn: _today.add(Duration(days: dueInDays)),
  reminderDueLevel: level,
  onHold: onHold,
  paymentDeclared: pending,
  eInvoiceRejected: rejected,
);

class _Commands implements InvoiceCommands {
  final List<String> reminded = [];
  Exception? failWith;

  @override
  Future<void> remindInvoice(String invoiceId) async {
    final failure = failWith;
    if (failure != null) throw failure;
    reminded.add(invoiceId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final ReminderLetter _letter = (
  bytes: Uint8List.fromList([1]),
  fileName: 'reminder.pdf',
  message: 'Please pay',
);

FileSharer _sharing(FileShareOutcome outcome, {List<String>? log}) =>
    ({required bytes, required fileName, required mimeType, text}) async {
      log?.add(fileName);
      return outcome;
    };

void main() {
  group('the queue', () {
    test('only by hand, only what is due and free to send', () {
      final invoices = [
        _r('a'),
        _r('held', onHold: true),
        _r('paying', pending: true),
        _r('none', level: null),
      ];
      expect(
        reminderQueueOf(invoices, _today, ReminderMode.automatic).isEmpty,
        isTrue,
        reason: 'automatic reminders have no queue',
      );
      final queue = reminderQueueOf(invoices, _today, ReminderMode.byHand);
      expect(queue.lines.map((l) => l.invoiceId), ['a']);
    });

    test('grouped by level, lowest first; most late first inside a level', () {
      final queue = reminderQueueOf(
        [
          _r('l2', level: 2, dueInDays: -40),
          _r('late', dueInDays: -20),
          _r('soon', dueInDays: -2),
          _r('big', dueInDays: -2, open: 90000),
        ],
        _today,
        ReminderMode.byHand,
      );
      expect(queue.levels, [1, 2]);
      expect(queue.ofLevel(1).map((l) => l.invoiceId), ['late', 'big', 'soon']);
      expect(queue.ofLevel(2).map((l) => l.invoiceId), ['l2']);
      expect(queue.next?.invoiceId, 'late');
    });
  });

  group('sharing one line', () {
    late _Commands commands;
    late ReminderQueue queue;

    setUp(() {
      commands = _Commands();
      queue = reminderQueueOf(
        [_r('a'), _r('b', dueInDays: -1)],
        _today,
        ReminderMode.byHand,
      );
    });

    final shares = <String>[];

    Future<ReminderQueue> share(FileShareOutcome outcome) async {
      final line = queue.next!;
      return queue.withResult(
        line.invoiceId,
        await shareQueuedReminder(
          line: line,
          repository: commands,
          share: _sharing(outcome, log: shares),
          letter: _letter,
        ),
      );
    }

    test('a share that left records the level once and moves on', () async {
      final after = await share(FileShareOutcome.sent);
      expect(commands.reminded, ['a']);
      expect(after.shared.map((l) => l.invoiceId), ['a']);
      expect(after.next?.invoiceId, 'b');
      expect(after.isDone, isFalse);
    });

    test('a dismissed sheet records nothing and the line stays', () async {
      final after = await share(FileShareOutcome.dismissed);
      expect(commands.reminded, isEmpty);
      expect(after.handled['a'], ReminderHandled.notRecorded);
      expect(after.shared, isEmpty);
      expect(after.next?.invoiceId, 'b', reason: 'the untried line goes first');
      expect(after.remaining, hasLength(2), reason: 'a is still to share');
    });

    test('a letter that could not be built is "failed": nothing left', () async {
      shares.clear();
      final r = await shareQueuedReminder(
        line: queue.next!,
        repository: commands,
        share: ({required bytes, required fileName, required mimeType, text}) =>
            throw StateError('no share sheet'),
        letter: _letter,
      );
      expect(r, ReminderHandled.failed);
      expect(commands.reminded, isEmpty);
    });

    test('shared, then the record failed: "shared, not recorded"; Record '
        'records it without sharing it again', () async {
      shares.clear();
      commands.failWith = Exception('offline');
      var after = await share(FileShareOutcome.sent);
      expect(after.handled['a'], ReminderHandled.sharedNotRecorded);
      expect(after.shared, isEmpty);
      expect(after.unrecorded.map((l) => l.invoiceId), ['a']);
      expect(
        after.remaining.map((l) => l.invoiceId),
        ['b'],
        reason: 'it left: it is never offered to share again',
      );
      expect(after.next?.invoiceId, 'b');
      expect(shares, hasLength(1));

      commands.failWith = null;
      final line = after.lines.first;
      after = after.withResult(
        line.invoiceId,
        await recordQueuedReminder(line: line, repository: commands),
      );
      expect(commands.reminded, ['a']);
      expect(shares, hasLength(1), reason: 'recorded, not shared twice');
      expect(after.shared.map((l) => l.invoiceId), ['a']);
    });

    test('the queue is done when every line is shared', () async {
      var q = await share(FileShareOutcome.sent);
      final line = q.next!;
      q = q.withResult(
        line.invoiceId,
        await shareQueuedReminder(
          line: line,
          repository: commands,
          share: _sharing(FileShareOutcome.sent),
          letter: _letter,
        ),
      );
      expect(q.isDone, isTrue);
      expect(q.next, isNull);
      expect(commands.reminded, ['a', 'b']);
    });
  });

  group('the queue lists exactly what the To-do entry counts', () {
    test('a rejected e-invoice is fixed first, never shared; count = queue '
        'length', () {
      final invoices = [_r('a'), _r('rejected', rejected: true), _r('b')];
      final queue = reminderQueueOf(invoices, _today, ReminderMode.byHand);
      expect(queue.lines.map((l) => l.invoiceId), isNot(contains('rejected')));
      final count = todoOf(invoices, mode: ReminderMode.byHand)
          .firstWhere((t) => t.kind == TodoKind.shareReminders)
          .tally
          .count;
      expect(queue.lines, hasLength(count));
    });

    test('drawn again, a customer now known to hold money leaves the lines '
        'for "check first"; what already left stays', () {
      final invoices = [_r('a'), _r('b'), _r('c')];
      final before = reminderQueueOf(
        invoices,
        _today,
        ReminderMode.byHand,
      ).withResult('c', ReminderHandled.shared);
      final after = before.refreshedBy(
        reminderQueueOf(
          invoices,
          _today,
          ReminderMode.byHand,
          holdsUnassigned: {'c-a', 'c-c'},
        ),
      );
      expect(after.lines.map((l) => l.invoiceId), unorderedEquals(['b', 'c']));
      expect(after.checkFirst.map((c) => c.customerId), ['c-a', 'c-c']);
      expect(after.shared.map((l) => l.invoiceId), ['c']);
      expect(after.next?.invoiceId, 'b');
    });
  });

  group('customers holding unassigned money', () {
    test('are left out of the groups and listed first, once each', () {
      final queue = reminderQueueOf(
        [_r('a'), _r('b', dueInDays: -9), _r('c')],
        _today,
        ReminderMode.byHand,
        holdsUnassigned: {'c-a', 'c-b'},
      );
      expect(queue.lines.map((l) => l.invoiceId), ['c']);
      expect(queue.checkFirst.map((c) => c.customerId), ['c-a', 'c-b']);
      expect(queue.next?.invoiceId, 'c');
    });

    test('a customer with nothing due is not in the check-first list', () {
      final queue = reminderQueueOf(
        [_r('a', level: null)],
        _today,
        ReminderMode.byHand,
        holdsUnassigned: {'c-a'},
      );
      expect(queue.checkFirst, isEmpty);
    });

    test('a share result keeps the check-first list', () {
      final queue = reminderQueueOf(
        [_r('a'), _r('b')],
        _today,
        ReminderMode.byHand,
        holdsUnassigned: {'c-a'},
      );
      expect(
        queue.withResult('b', ReminderHandled.shared).checkFirst,
        hasLength(1),
      );
    });
  });
}
