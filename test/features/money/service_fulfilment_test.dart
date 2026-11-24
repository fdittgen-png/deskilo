// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4178 (F4) -- an ordered service followed as an engagement: the pure rules of
// its steps, and the Demo's repository, which keeps the server's rules (0852) --
// one engagement per canonical source line, an invoice that billed a quote
// resolving to the quote's, append-only steps at an expected revision, one
// request one step -- while it reads the quote and the invoices and changes none
// of them. Read through the same JSON reader the real repository uses.
import 'dart:async';

import 'package:deskilo/core/demo/data/fake_customer_quotes.dart';
import 'package:deskilo/core/demo/data/fake_service_fulfilments.dart';
import 'package:deskilo/core/failure/app_failure.dart';
import 'package:deskilo/features/money/application/service_fulfilment_commands.dart';
import 'package:deskilo/features/money/domain/customer_quote.dart';
import 'package:deskilo/features/money/domain/service_fulfilment.dart';
import 'package:deskilo/features/money/domain/standalone_invoice.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

const _ws = 'ws-1';
const _customer = 'customer-1';
const _other = 'customer-2';
final _now = DateTime.utc(2026, 11, 2, 10);

const _consulting = StandaloneLine(
  description: 'Consulting',
  quantity: '1.5',
  unitCode: 'hour',
  unitLabel: 'h',
  unEceCode: 'HUR',
  unitPrice: '90',
);
const _training = StandaloneLine(
  description: 'Training',
  quantity: '1',
  unitCode: 'unit',
  unitLabel: 'day',
  unEceCode: 'DAY',
  unitPrice: '400',
);

/// An issued invoice whose one line carries [lineId] as its commercial identity.
Invoice _invoice(
  String id,
  String member,
  String lineId, {
  int total = 40000,
  String? replaces,
}) {
  final commercial = commercialLineFromSnapshot({
    'version': 1,
    'line_id': lineId,
    'quantity': '1',
    'unit': {'code': 'unit', 'label': 'day', 'un_ece_code': 'DAY'},
    'unit_price': {
      'amount': '400',
      'currency': 'EUR',
      'basis': 'net',
      'base_quantity': '1',
    },
    'supply': 'general',
    'amounts': {
      'currency': 'EUR',
      'net_minor': '40000',
      'tax_minor': '8000',
      'gross_minor': '48000',
      'rule': 'half_up_per_line',
    },
  });
  return Invoice(
    id: id,
    workspaceId: _ws,
    memberId: member,
    number: 'INV-$id',
    issuedAt: _now,
    title: 'Training',
    lines: [
      InvoiceLine(
        label: 'Training',
        amountCents: total,
        netCents: total,
        commercial: commercial,
      ),
    ],
    totalCents: total,
    currency: 'EUR',
    memberName: 'Customer',
    memberAddress: '',
    workspaceName: 'Business',
    workspaceAddress: '',
    issuerName: 'Owner',
    signature: 'f' * 64,
    replacesInvoiceId: replaces,
  );
}

class _World {
  _World() {
    quotes = FakeCustomerQuoteRepository(clock: () => _now);
    repo = FakeServiceFulfilmentRepository(
      workspaceId: _ws,
      quotes: quotes,
      invoices: () => invoices,
      matches: () => matches,
      hasCustomer: (id) => id == _customer || id == _other,
      actor: () => 'owner',
      clock: () => _now,
    );
    quotes
      ..seedSent(
        _ws,
        subjectId: _customer,
        lines: const [_consulting, _training],
        issuedOn: _now.subtract(const Duration(days: 3)),
        validUntil: _now.add(const Duration(days: 20)),
      )
      ..seedAccepted(_ws, 0, decidedOn: _now.subtract(const Duration(days: 1)));
  }

  late final FakeCustomerQuoteRepository quotes;
  late final FakeServiceFulfilmentRepository repo;
  final invoices = <Invoice>[];
  final matches = <String, InvoiceMatch>{};
  var _request = 0;

  String request() => 'request-${_request++}';

  Future<CustomerQuote> quote() async => (await quotes.quotes(_ws)).single;

  Future<String> lineId(int index) async =>
      (await quote()).revisions.last.lines[index].lineId!;

  Future<ServiceFulfilment> openQuoteLine(
    int index, {
    String? requestId,
  }) async => (await repo.openFromLine(
    _ws,
    requestId: requestId ?? request(),
    kind: 'quote',
    id: (await quote()).id,
    lineId: await lineId(index),
  )).fulfilment;
}

void main() {
  group('the steps', () {
    test('ordered goes on or is cancelled, started finishes or is cancelled, nothing leaves the end', () {
      expect(nextSteps(FulfilmentState.ordered), [
        FulfilmentState.started,
        FulfilmentState.cancelled,
      ]);
      expect(nextSteps(FulfilmentState.started), [
        FulfilmentState.done,
        FulfilmentState.cancelled,
      ]);
      expect(nextSteps(FulfilmentState.done), isEmpty);
      expect(nextSteps(FulfilmentState.cancelled), isEmpty);
      expect(stepNeedsReason(FulfilmentState.cancelled), isTrue);
      expect(stepNeedsReason(FulfilmentState.done), isFalse);
    });

    test('an unknown state of the server is no state, and a row with one is unreadable, never a guess', () {
      expect(FulfilmentState.of('paused'), isNull);
      expect(
        () => ServiceFulfilment.fromJson(const {
          'fulfilment_id': 'f',
          'subject_id': 's',
          'state': 'paused',
          'revision': 1,
          'source': {'kind': 'direct', 'id': 'f', 'line_id': 'l'},
          'scope': {'description': 'x', 'quantity': '1', 'unit': ''},
          'history': <Object?>[],
          'invoices': <Object?>[],
        }),
        throwsA(isA<UnknownFulfilmentState>()),
      );
    });
  });

  group('an engagement from the accepted quote', () {
    test('is followed ordered, started, done before any invoice, and touches nothing else', () async {
      final w = _World();
      final opened = await w.openQuoteLine(1);

      expect(opened.state, FulfilmentState.ordered);
      expect(opened.revision, 1);
      expect(opened.scope.description, 'Training');
      expect(opened.subjectId, _customer);
      expect(opened.source.kind, 'quote');
      expect(opened.source.revision, 1);
      expect(opened.invoices, isEmpty, reason: 'nothing was invoiced');

      final started = await w.repo.transition(
        _ws,
        opened.id,
        expectedRevision: 1,
        to: FulfilmentState.started,
        requestId: w.request(),
      );
      final done = await w.repo.transition(
        _ws,
        opened.id,
        expectedRevision: 2,
        to: FulfilmentState.done,
        requestId: w.request(),
      );

      expect(started.state, FulfilmentState.started);
      expect(done.state, FulfilmentState.done);
      expect(done.history.map((s) => '${s.from?.wire}>${s.to.wire}'), [
        'null>ordered',
        'ordered>started',
        'started>done',
      ]);
      expect(done.next, isEmpty);
      expect(w.invoices, isEmpty);
      expect(
        (await w.quote()).status,
        QuoteStatus.accepted,
        reason: 'the quote is as it was',
      );
    });

    test(
      'keeps its history when the invoice is issued, partly paid and corrected',
      () async {
        final w = _World();
        final opened = await w.openQuoteLine(1);
        await w.repo.transition(
          _ws,
          opened.id,
          expectedRevision: 1,
          to: FulfilmentState.started,
          requestId: w.request(),
        );
        await w.repo.transition(
          _ws,
          opened.id,
          expectedRevision: 2,
          to: FulfilmentState.done,
          requestId: w.request(),
        );
        final before = (await w.repo.fulfilment(_ws, opened.id)).history.length;

        final converted = await w.quotes.convert(
          _ws,
          (await w.quote()).id,
          draftRevision: 1,
          requestId: w.request(),
        );
        w.invoices.add(
          _invoice(converted.invoiceId, _customer, await w.lineId(1)),
        );
        w.matches[converted.invoiceId] = InvoiceMatch(
          invoiceId: converted.invoiceId,
          paidCents: 30000,
          resolution: 'under_accepted',
          matchedAt: _now,
          byName: 'Owner',
        );
        w.invoices.add(
          _invoice(
            'credit-1',
            _customer,
            await w.lineId(1),
            total: -48000,
            replaces: converted.invoiceId,
          ),
        );

        final after = await w.repo.fulfilment(_ws, opened.id);
        expect(
          after.history,
          hasLength(before),
          reason: 'no step was added by the invoice, the payment or the credit',
        );
        expect(after.state, FulfilmentState.done);
        expect(after.quote?.status, 'converted');
        expect(
          after.invoices.single.paidCents,
          30000,
          reason: 'what was paid is read beside it',
        );
        expect(after.invoices.single.corrections.single.number, 'INV-credit-1');
        expect(
          (await w.repo.fulfilments(_ws)).length,
          1,
          reason: 'no financial action duplicated the engagement',
        );
      },
    );

    test('is the same engagement from the invoice that billed the quote line, however it is reached', () async {
      final w = _World();
      final opened = await w.openQuoteLine(1);
      final converted = await w.quotes.convert(
        _ws,
        (await w.quote()).id,
        draftRevision: 1,
        requestId: w.request(),
      );
      w.invoices.add(
        _invoice(converted.invoiceId, _customer, await w.lineId(1)),
      );

      final fromInvoice = await w.repo.openFromLine(
        _ws,
        requestId: w.request(),
        kind: 'invoice',
        id: converted.invoiceId,
        lineId: await w.lineId(1),
      );
      final found = await w.repo.ofLine(
        _ws,
        kind: 'invoice',
        id: converted.invoiceId,
        lineId: await w.lineId(1),
      );
      final fromQuote = await w.openQuoteLine(1);

      expect(fromInvoice.created, isFalse);
      expect(fromInvoice.fulfilment.id, opened.id);
      expect(found?.id, opened.id);
      expect(fromQuote.id, opened.id);
      expect((await w.repo.fulfilments(_ws)).length, 1);
      expect(
        await w.repo.ofLine(
          _ws,
          kind: 'quote',
          id: (await w.quote()).id,
          lineId: await w.lineId(0),
        ),
        isNull,
        reason: 'a line nobody opened has none',
      );
    });

    test('two lines are two engagements, and the same request answers the same, a changed payload is refused', () async {
      final w = _World();
      final a = await w.openQuoteLine(0, requestId: 'r-a');
      final b = await w.openQuoteLine(1);
      final replay = await w.repo.openFromLine(
        _ws,
        requestId: 'r-a',
        kind: 'quote',
        id: (await w.quote()).id,
        lineId: await w.lineId(0),
      );

      expect(a.id, isNot(b.id));
      expect(replay.replayed, isTrue);
      expect(replay.fulfilment.id, a.id);
      await expectLater(
        w.repo.openFromLine(
          _ws,
          requestId: 'r-a',
          kind: 'quote',
          id: (await w.quote()).id,
          lineId: await w.lineId(1),
        ),
        throwsA(
          isA<FulfilmentRefusal>().having(
            (r) => r.kind,
            'kind',
            FulfilmentRefusalKind.requestReused,
          ),
        ),
      );
    });

    test('a quote that was only sent is not commercial evidence', () async {
      final w = _World();
      w.quotes.seedSent(
        _ws,
        subjectId: _other,
        lines: const [_consulting],
        issuedOn: _now,
        validUntil: _now.add(const Duration(days: 5)),
      );
      final sent = (await w.quotes.quotes(_ws))
          .firstWhere((q) => q.status == QuoteStatus.sent);

      await expectLater(
        w.repo.openFromLine(
          _ws,
          requestId: w.request(),
          kind: 'quote',
          id: sent.id,
          lineId: sent.revisions.last.lines.first.lineId!,
        ),
        throwsA(
          isA<FulfilmentRefusal>().having(
            (r) => r.kind,
            'kind',
            FulfilmentRefusalKind.state,
          ),
        ),
      );
    });
  });

  group('a direct engagement', () {
    const input = DirectEngagementInput(
      subjectId: _customer,
      description: 'Coaching',
      quantity: '3',
      unit: 'session',
    );

    test('is committed before any invoice and two identical-looking ones stay distinct', () async {
      final w = _World();
      final a = await w.repo.openDirect(_ws, requestId: 'd-1', input: input);
      final b = await w.repo.openDirect(_ws, requestId: 'd-2', input: input);

      expect(a.created, isTrue);
      expect(a.fulfilment.source.kind, 'direct');
      expect(
        a.fulfilment.source.id,
        a.fulfilment.id,
        reason: 'a direct engagement is its own commitment',
      );
      expect(a.fulfilment.scope.quantity, '3');
      expect(b.fulfilment.id, isNot(a.fulfilment.id));
      expect(w.invoices, isEmpty);
    });

    test(
      'refuses an unknown customer, no description and a zero quantity',
      () async {
        final w = _World();
        Future<FulfilmentRefusal> refused(DirectEngagementInput i) async {
          try {
            await w.repo.openDirect(_ws, requestId: w.request(), input: i);
          } on FulfilmentRefusal catch (r) {
            return r;
          }
          fail('it should have been refused');
        }

        expect(
          (await refused(
            const DirectEngagementInput(
              subjectId: 'nobody',
              description: 'x',
              quantity: '1',
            ),
          )).kind,
          FulfilmentRefusalKind.unknown,
        );
        expect(
          (await refused(
            const DirectEngagementInput(
              subjectId: _customer,
              description: ' ',
              quantity: '1',
            ),
          )).detail,
          'description',
        );
        expect(
          (await refused(
            const DirectEngagementInput(
              subjectId: _customer,
              description: 'x',
              quantity: '0',
            ),
          )).detail,
          'quantity',
        );
      },
    );

    test('a later invoice line is linked to it explicitly, once, and opening from the invoice returns it', () async {
      final w = _World();
      final direct = (await w.repo.openDirect(
        _ws,
        requestId: 'd-1',
        input: input,
      )).fulfilment;
      final other = (await w.repo.openDirect(
        _ws,
        requestId: 'd-2',
        input: input,
      )).fulfilment;
      w.invoices.add(_invoice('inv-1', _customer, 'line-x'));

      final linked = await w.repo.linkInvoice(
        _ws,
        direct.id,
        invoiceId: 'inv-1',
        lineId: 'line-x',
      );
      final again = await w.repo.linkInvoice(
        _ws,
        direct.id,
        invoiceId: 'inv-1',
        lineId: 'line-x',
      );
      final reopened = await w.repo.openFromLine(
        _ws,
        requestId: w.request(),
        kind: 'invoice',
        id: 'inv-1',
        lineId: 'line-x',
      );

      expect(linked.invoices.single.number, 'INV-inv-1');
      expect(again.id, direct.id);
      expect(reopened.fulfilment.id, direct.id);
      await expectLater(
        w.repo.linkInvoice(_ws, other.id, invoiceId: 'inv-1', lineId: 'line-x'),
        throwsA(
          isA<FulfilmentRefusal>().having((r) => r.detail, 'detail', 'taken'),
        ),
      );
    });

    test('an invoice line that already has its own engagement is not linked to another', () async {
      final w = _World();
      final direct = (await w.repo.openDirect(
        _ws,
        requestId: 'd-1',
        input: input,
      )).fulfilment;
      w.invoices.add(_invoice('inv-1', _customer, 'line-x'));
      await w.repo.openFromLine(
        _ws,
        requestId: w.request(),
        kind: 'invoice',
        id: 'inv-1',
        lineId: 'line-x',
      );

      await expectLater(
        w.repo.linkInvoice(
          _ws,
          direct.id,
          invoiceId: 'inv-1',
          lineId: 'line-x',
        ),
        throwsA(
          isA<FulfilmentRefusal>().having((r) => r.detail, 'detail', 'taken'),
        ),
      );
    });
  });

  group('taking a step', () {
    const input = DirectEngagementInput(
      subjectId: _customer,
      description: 'Coaching',
      quantity: '3',
    );

    Future<(_World, ServiceFulfilment)> world() async {
      final w = _World();
      return (
        w,
        (await w.repo.openDirect(
          _ws,
          requestId: 'd-1',
          input: input,
        )).fulfilment,
      );
    }

    Future<FulfilmentRefusal> refused(Future<Object?> step) async {
      try {
        await step;
      } on FulfilmentRefusal catch (r) {
        return r;
      }
      fail('it should have been refused');
    }

    test('at a stale revision is refused with the current one; a retry of the same request is the same step', () async {
      final (w, e) = await world();
      await w.repo.transition(
        _ws,
        e.id,
        expectedRevision: 1,
        to: FulfilmentState.started,
        requestId: 'r-1',
      );

      final stale = await refused(
        w.repo.transition(
          _ws,
          e.id,
          expectedRevision: 1,
          to: FulfilmentState.started,
          requestId: 'r-2',
        ),
      );
      final retried = await w.repo.transition(
        _ws,
        e.id,
        expectedRevision: 1,
        to: FulfilmentState.started,
        requestId: 'r-1',
      );
      final changed = await refused(
        w.repo.transition(
          _ws,
          e.id,
          expectedRevision: 1,
          to: FulfilmentState.cancelled,
          reason: 'no',
          requestId: 'r-1',
        ),
      );

      expect(stale.kind, FulfilmentRefusalKind.stale);
      expect(stale.currentRevision, 2);
      expect(
        retried.history,
        hasLength(2),
        reason: 'a retry after a lost success adds no step',
      );
      expect(changed.kind, FulfilmentRefusalKind.requestReused);
    });

    test('cancels ordered or started work with a reason, never done work, and allows no jump or step back', () async {
      final (w, e) = await world();

      expect(
        (await refused(
          w.repo.transition(
            _ws,
            e.id,
            expectedRevision: 1,
            to: FulfilmentState.done,
            requestId: w.request(),
          ),
        )).kind,
        FulfilmentRefusalKind.state,
        reason: 'ordered cannot jump to done',
      );
      expect(
        (await refused(
          w.repo.transition(
            _ws,
            e.id,
            expectedRevision: 1,
            to: FulfilmentState.cancelled,
            requestId: w.request(),
          ),
        )).detail,
        'reason',
      );
      expect(
        (await refused(
          w.repo.transition(
            _ws,
            e.id,
            expectedRevision: 1,
            to: FulfilmentState.ordered,
            requestId: w.request(),
          ),
        )).kind,
        FulfilmentRefusalKind.incomplete,
      );

      final cancelled = await w.repo.transition(
        _ws,
        e.id,
        expectedRevision: 1,
        to: FulfilmentState.cancelled,
        reason: '  never started  ',
        requestId: w.request(),
      );
      expect(cancelled.state, FulfilmentState.cancelled);
      expect(cancelled.history.last.reason, 'never started');
      expect(
        (await refused(
          w.repo.transition(
            _ws,
            e.id,
            expectedRevision: 2,
            to: FulfilmentState.started,
            requestId: w.request(),
          ),
        )).kind,
        FulfilmentRefusalKind.state,
        reason: 'cancelled stays cancelled',
      );

      final started = (await w.repo.openDirect(
        _ws,
        requestId: 'd-9',
        input: input,
      )).fulfilment;
      await w.repo.transition(
        _ws,
        started.id,
        expectedRevision: 1,
        to: FulfilmentState.started,
        requestId: w.request(),
      );
      await w.repo.transition(
        _ws,
        started.id,
        expectedRevision: 2,
        to: FulfilmentState.done,
        requestId: w.request(),
      );
      expect(
        (await refused(
          w.repo.transition(
            _ws,
            started.id,
            expectedRevision: 3,
            to: FulfilmentState.cancelled,
            reason: 'late',
            requestId: w.request(),
          ),
        )).kind,
        FulfilmentRefusalKind.state,
        reason: 'done work is never cancelled',
      );
    });
  });

  group('the commands', () {
    test('answer a refusal as an outcome, a step as done, and a failure that is not a refusal as unreached', () async {
      final w = _World();
      final commands = ServiceFulfilmentCommands(w.repo);
      final opened = await commands.openDirect(
        _ws,
        requestId: 'd-1',
        input: const DirectEngagementInput(
          subjectId: _customer,
          description: 'Coaching',
          quantity: '3',
        ),
      );
      final e = (opened as CommandDone<FulfilmentOpened>).value.fulfilment;

      final jump = await commands.step(
        _ws,
        e,
        to: FulfilmentState.done,
        requestId: 'r-1',
      );
      final started = await commands.step(
        _ws,
        e,
        to: FulfilmentState.started,
        requestId: 'r-2',
      );

      expect(
        jump,
        isA<CommandRefused<ServiceFulfilment>>()
            .having((o) => o.refusal.cause, 'cause', isA<FulfilmentRefusal>()),
      );
      expect(started, isA<CommandDone<ServiceFulfilment>>());
      expect(
        await ServiceFulfilmentCommands(_Failing())
            .step(_ws, e, to: FulfilmentState.started, requestId: 'r-3'),
        isA<CommandUnreached<ServiceFulfilment>>(),
      );
    });
  });
}

class _Failing implements ServiceFulfilmentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      // #4413 -- a lost answer is a transport failure: not reached.
      throw TimeoutException('the connection is lost');
}
