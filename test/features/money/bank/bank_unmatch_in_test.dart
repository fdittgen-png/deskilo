// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2380 (0650, 0657) -- a confirmed match of money in is undone once, with
// a reason, over the in-memory store that keeps the server's rules. One of
// several payments of a part-paid invoice is undone alone: the match is what
// the remaining payments make it.
//
// Undone: the invoice reads open again, the movement keeps its payment and
// reads recorded, no ledger row is added or removed, one record keeps why,
// the timeline gets an applied invoice_payment_reversed event and no payment
// event; the same request answers the same; the movement then matches again
// with the SAME payment and no second credit.
//
// Refused, called on the repository itself (the screen hiding a button is
// not the protection), each with the code the server answers and the sentence
// the person reads: a credit note minted and a settlement (DKB04), payments
// that do not add up to their match (DKB05), a payment inside a closed
// period (DKB06),
// a match still awaiting its validation and a movement that settles nothing
// (DKB01), money out (DKB02), a request id used for another line and no
// reason (22023).
import 'package:deskilo/core/demo/data/bank_statement_repository.dart';
import 'package:deskilo/core/demo/data/event_repository.dart';
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/l10n/context_l10n.dart';
import 'package:deskilo/core/trace/refusal_text.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/application/bank_import_commands.dart';
import 'package:deskilo/features/money/domain/bank/bank_match.dart';
import 'package:deskilo/features/money/domain/bank/bank_records.dart';
import 'package:deskilo/features/money/domain/bank/bank_statement.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

Invoice _invoice(String number, int total, {String? settledBy}) => Invoice(
  id: 'id-$number',
  workspaceId: 'ws-1',
  memberId: 'm1',
  number: number,
  issuedAt: DateTime.utc(2026, 10, 2),
  title: number,
  lines: const [],
  totalCents: total,
  currency: 'CHF',
  memberName: 'Demo Member',
  memberAddress: '',
  workspaceName: 'Space',
  workspaceAddress: '',
  issuerName: 'Space',
  signature: '',
  settledByInvoiceId: settledBy,
);

BankLine _in(int n, int cents) => BankLine(
  position: n,
  bookingDate: DateTime.utc(2026, 10, 20),
  valueDate: DateTime.utc(2026, 10, 21),
  amountCents: cents,
  currency: 'CHF',
  transactionId: 'T$n',
);

Future<String?> _code(Future<Object?> Function() call) async {
  try {
    await call();
    return null;
  } on PostgrestException catch (e) {
    return e.code;
  }
}

void main() {
  late FakeEventRepository events;
  late FakeMoneyRepository money;
  late FakeBankStatementRepository bank;
  late BankImportCommands commands;
  late List<StoredBankLine> lines;
  late String statementId;

  Future<StoredBankLine> line(int n) async =>
      (await bank.fetchLines(statementId)).firstWhere((l) => l.position == n);

  setUp(() async {
    events = FakeEventRepository();
    money = FakeMoneyRepository(events: events);
    money.invoices.addAll([
      _invoice('I1', 10000),
      _invoice('I2', 8000),
      _invoice('I3', 20000),
      _invoice('I4', 10000),
      _invoice('I5', 10000, settledBy: 'id-SETTLEMENT'),
    ]);
    bank = FakeBankStatementRepository(money: money, today: DateTime.utc(2026, 10, 26));
    commands = BankImportCommands(bank);
    final result = await bank.importStatement(
      'ws-1',
      statement: BankStatement(
        format: BankFileFormat.camt054,
        account: 'CH9300762011623852957',
        currency: 'CHF',
        lines: [
          _in(1, 10000), // L1 -> I1 exact
          _in(2, 10000), // L2 -> I2 as a credit note
          _in(3, 10000), // L3 -> I3, first payment
          _in(4, 5000), // L4 -> I3, second payment
          _in(5, 10000), // L5 -> I4 exact (closed books)
          _in(6, 10000), // L6 -> I5 (belongs to a settlement)
          _in(7, 10000), // L7 left open
          _in(8, -500), // L8 money out
        ],
      ),
      sourceSha256: 'a' * 64,
      fileName: 'u.xml',
    );
    statementId = result.statementId;
    lines = await bank.fetchLines(statementId);
    Future<void> match(int n, String invoice, String resolution, [String note = '']) =>
        bank.matchLine(lines[n - 1].id, invoiceId: 'id-$invoice', resolution: resolution, note: note);
    await match(1, 'I1', 'exact');
    await match(2, 'I2', 'over_credit_note');
    await match(3, 'I3', 'under_accepted', 'first part');
    await match(4, 'I3', 'under_accepted', 'second part');
    await match(5, 'I4', 'exact');
    await match(6, 'I5', 'exact');
  });

  test('undone: the invoice is open again, the payment stays, and the '
      'timeline gets a record that is not a payment', () async {
    final ledgerBefore = money.ledger.length;
    final paymentBefore = money.invoiceMatchesStore['id-I1']!.paymentLedgerId;
    final matched = await line(1);
    expect(matched.status, BankLineStatus.matched);

    expect(
      await commands.unmatchIn(matched, reason: '  Wrong invoice: it was I2  ', requestId: 'r1'),
      BankLineStatus.recorded,
    );
    final after = await line(1);
    expect(after.status, BankLineStatus.recorded);
    expect(after.invoiceId, isNull, reason: 'the movement names no invoice');
    expect(money.invoiceMatchesStore.containsKey('id-I1'), isFalse);
    expect(
      openInvoices(money.invoices, money.invoiceMatchesStore).map((i) => i.number),
      contains('I1'),
      reason: 'the invoice reads open again',
    );
    expect(money.ledger.length, ledgerBefore, reason: 'no ledger row added or removed');
    expect(bank.unmatches['r1']!.reason, 'Wrong invoice: it was I2');
    expect(bank.unmatches['r1']!.paymentId, paymentBefore);

    final reversed = events.events.where((e) => e.type == EventType.invoicePaymentReversed);
    expect(reversed, hasLength(1));
    expect(reversed.single.status, EventStatus.applied);
    expect(reversed.single.payload['invoice_id'], 'id-I1');
    expect(reversed.single.payload.containsKey('reason'), isFalse,
        reason: 'the staff reason is not on the timeline the payer reads');
    expect(reversed.single.subjectMemberId, isNot('m1'),
        reason: 'the event is not about the invoice member');
    expect(
      events.events.where((e) => e.type == EventType.invoicePayment),
      isEmpty,
      reason: 'the undoing is not read as a payment',
    );
  });

  test('exactly once: the same request answers the same, a request id used '
      'for another line is refused, a blank reason sends nothing', () async {
    final matched = await line(1);
    expect(await commands.unmatchIn(matched, reason: ' ', requestId: 'r0'), isNull);
    expect(bank.unmatches, isEmpty);
    expect(await commands.unmatchIn(matched, reason: 'x', requestId: 'r1'), BankLineStatus.recorded);
    expect(await commands.unmatchIn(matched, reason: 'x', requestId: 'r1'), BankLineStatus.recorded);
    expect(bank.unmatches, hasLength(1));
    final fifth = (await line(5)).id;
    final first = (await line(1)).id;
    expect(await _code(() => bank.unmatchIn(fifth, reason: 'x', requestId: 'r1')), '22023');
    expect(await _code(() => bank.unmatchIn(first, reason: '  ', requestId: 'r9')), '22023');
    final sent = await line(1);
    expect(sent.status, BankLineStatus.recorded);
    expect(
      await commands.unmatchIn(sent, reason: 'again', requestId: 'r2'),
      isNull,
      reason: 'a movement that is not matched sends nothing',
    );
  });

  test('refused without the right that matches, whatever the screen shows',
      () async {
    bank.mayUnmatch = () => false;
    final first = (await line(1)).id;
    expect(await _code(() => bank.unmatchIn(first, reason: 'x', requestId: 'n1')), '42501');
    expect(bank.unmatches, isEmpty);
    expect(money.invoiceMatchesStore.containsKey('id-I1'), isTrue);
  });

  test('matched again: the same payment, no second credit, the invoice '
      'settled again', () async {
    final ledgerBefore = money.ledger.length;
    final paymentBefore = money.invoiceMatchesStore['id-I1']!.paymentLedgerId;
    await commands.unmatchIn(await line(1), reason: 'x', requestId: 'r1');
    expect(
      await bank.matchLine((await line(1)).id, invoiceId: 'id-I1', resolution: 'exact', note: ''),
      BankLineStatus.matched,
    );
    expect(money.invoiceMatchesStore['id-I1']!.paymentLedgerId, paymentBefore);
    expect(money.ledger.length, ledgerBefore, reason: 'no second credit was minted');
  });

  test('refused on the repository itself, with the code and the sentence the '
      'person reads', () async {
    final l10n = englishL10n;
    Future<void> refused(int n, String code, KnownRefusal family, [String? words]) async {
      final id = (await line(n)).id;
      PostgrestException? error;
      try {
        await bank.unmatchIn(id, reason: 'wrong', requestId: 'q$n');
      } on PostgrestException catch (e) {
        error = e;
      }
      expect(error?.code, code, reason: 'line $n');
      expect(knownRefusalOf(error!), family, reason: 'line $n');
      final sentence = knownRefusalText(l10n, error)!;
      if (words != null) expect(sentence, contains(words), reason: 'line $n');
      expect(bank.unmatches.containsKey('q$n'), isFalse, reason: 'nothing is on record');
    }

    await refused(2, 'DKB04', KnownRefusal.bankMatchBeyondLink, 'credit note');
    await refused(6, 'DKB04', KnownRefusal.bankMatchBeyondLink, 'settlement');
    // A match whose amount its payments do not explain is not restated.
    money.invoiceMatchesStore['id-I3'] = money.invoiceMatchesStore['id-I3']!
        .copyWith(paidCents: 15001);
    await refused(3, 'DKB05', KnownRefusal.bankMatchSeveralPayments, 'without guessing');
    await refused(7, 'DKB01', KnownRefusal.bankLineDecided);
    await refused(8, 'DKB02', KnownRefusal.bankLineRefused);

    bank.booksClosedThrough = DateTime.utc(2999);
    await refused(5, 'DKB06', KnownRefusal.bankMatchClosedPeriod, 'closed period');
    expect(money.invoiceMatchesStore.containsKey('id-I4'), isTrue, reason: 'the match is still there');
  });

  test('the later of two payments is undone alone: the match is what the '
      'first makes it; the first goes last', () async {
    final ledgerBefore = money.ledger.length;
    final first = money.invoiceMatchPaymentsStore['id-I3']!.first.paymentLedgerId;
    final second = money.invoiceMatchesStore['id-I3']!.paymentLedgerId;
    expect(money.invoiceMatchesStore['id-I3']!.paidCents, 15000);

    final third = (await line(3)).id;
    expect(await _code(() => bank.unmatchIn(third, reason: 'x', requestId: 's0')),
        'DKB07', reason: 'the first payment is undone last');
    expect(
      knownRefusalText(englishL10n, const PostgrestException(message: '', code: 'DKB07')),
      contains('later payments first'),
    );

    expect(
      await commands.unmatchIn(await line(4), reason: 'not this invoice', requestId: 's1'),
      BankLineStatus.recorded,
    );
    final rest = money.invoiceMatchesStore['id-I3']!;
    expect(rest.paidCents, 10000, reason: 'only the first payment remains');
    expect(rest.resolution, 'under_accepted', reason: 'still a part payment');
    expect(rest.paymentLedgerId, first);
    expect(rest.note, 'first part', reason: 'the remaining payment\'s note');
    expect(
      money.invoiceMatchPaymentsStore['id-I3']!.map((r) => r.paymentLedgerId),
      [first],
    );
    expect((await line(4)).status, BankLineStatus.recorded);
    expect(money.ledger.length, ledgerBefore, reason: 'no ledger row moves');
    final reversed = events.events
        .where((e) => e.type == EventType.invoicePaymentReversed)
        .single;
    expect(reversed.payload['payment_ledger_id'], second);
    expect(reversed.payload['amount_cents'], 5000);

    expect(
      await commands.unmatchIn(await line(3), reason: 'wrong client', requestId: 's2'),
      BankLineStatus.recorded,
    );
    expect(money.invoiceMatchesStore.containsKey('id-I3'), isFalse,
        reason: 'the last payment undone: the invoice reads open');
  });

  test('a match still awaiting its validation is rejected there, not undone '
      'here', () async {
    money
      ..matchPolicyConfigured = true
      ..invoices.add(_invoice('I6', 10000));
    expect(
      await bank.matchLine((await line(7)).id,
          invoiceId: 'id-I6', resolution: 'exact', note: ''),
      BankLineStatus.pending,
    );
    final seventh = (await line(7)).id;
    expect(await _code(() => bank.unmatchIn(seventh, reason: 'x', requestId: 'p1')), 'DKB01');
    expect(money.invoiceMatchesStore.containsKey('id-I6'), isTrue,
        reason: 'the pending match is still there');
    expect(bank.unmatches, isEmpty);
  });
}
