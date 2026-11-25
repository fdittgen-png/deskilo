// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4405 -- the one issue attempt of the invoice screen and of the conversion of an accepted quote: a document is checked, issued once
// under one request, an answer that did not come is looked for under THAT request, and nothing the server refused stands.
import 'package:deskilo/core/failure/app_failure.dart';
import 'package:deskilo/features/money/application/issue_attempt.dart';
import 'package:deskilo/features/money/domain/previewed_document.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

PreviewedDocument _ready() => const PreviewedDocument(
  missing: [],
  lines: [InvoiceLine(label: 'x', amountCents: 100)],
  totalCents: 100,
  currency: 'EUR',
);

CommandOutcome<Checked<String>> _checked([PreviewedDocument? d]) => CommandDone((basis: 'draft-1', document: d ?? _ready()));

void main() {
  late int repaints;
  late IssueAttempt<String, String> attempt;
  setUp(() {
    repaints = 0;
    attempt = IssueAttempt<String, String>(onChanged: () => repaints++, keysOf: (r) => ['due_on']);
  });

  test('a check keeps the document and what it needs; the screen is told', () async {
    await attempt.check(() async => _checked());
    expect(attempt.basis, 'draft-1');
    expect(attempt.document?.ready, isTrue);
    expect(attempt.busy, isFalse);
    expect(repaints, greaterThanOrEqualTo(2), reason: 'busy, then the answer');
  });

  test('nothing is issued before something was checked', () async {
    var sent = 0;
    final out = await attempt.issue(send: (id) async => CommandDone('inv-${sent++}'), look: (id, u) async => u);
    expect(out, isNull);
    expect(sent, 0);
  });

  test('one request identity per checked document: a second issue is the same attempt, an edit or a new check draws a new one', () async {
    await attempt.check(() async => _checked());
    final ids = <String>[];
    await attempt.issue(send: (id) async { ids.add(id); return const CommandUnreached<String>(Defect('lost')); }, look: (id, u) async => u);
    await attempt.issue(send: (id) async { ids.add(id); return const CommandUnreached<String>(Defect('lost')); }, look: (id, u) async => u);
    expect(ids[1], ids[0]);
    attempt.edited();
    expect(attempt.basis, isNull, reason: 'an edit makes the checked document stale');
    await attempt.check(() async => _checked());
    await attempt.issue(send: (id) async { ids.add(id); return const CommandDone('inv'); }, look: (id, u) async => u);
    expect(ids[2], isNot(ids[0]));
  });

  test('an answer that did not come is looked for under the request that was sent, and found', () async {
    await attempt.check(() async => _checked());
    String? sentUnder;
    String? lookedUnder;
    await attempt.issue(send: (id) async { sentUnder = id; return const CommandUnreached<String>(Defect('lost')); }, look: (id, u) async { lookedUnder = id; return const CommandDone('inv-9'); });
    expect(attempt.isUnknown, isTrue);
    final found = await attempt.lookAgain();
    expect(lookedUnder, sentUnder);
    expect(found, isA<CommandDone<String>>());
    expect(attempt.isUnknown, isFalse);
    expect(attempt.busy, isFalse);
  });

  test('a look that finds nothing leaves the answer unknown; it offers nothing else', () async {
    await attempt.check(() async => _checked());
    await attempt.issue(send: (id) async => const CommandUnreached<String>(Defect('lost')), look: (id, u) async => u);
    final again = await attempt.lookAgain();
    expect(again, isA<CommandUnreached<String>>());
    expect(attempt.isUnknown, isTrue);
  });

  test('a refusal is a definite no: the checked document no longer stands and the facts it names are kept', () async {
    await attempt.check(() async => _checked());
    await attempt.issue(send: (id) async => const CommandRefused<String>(Refusal(message: 'no', cause: 'DKI01')), look: (id, u) async => u);
    expect(attempt.isUnknown, isFalse);
    expect(attempt.basis, isNull);
    expect(attempt.document, isNull);
    expect(attempt.refused, isTrue);
    expect(attempt.missing, ['due_on']);
  });

  test('a check that is refused keeps the refusal; one that got no answer says so', () async {
    await attempt.check(() async => const CommandRefused<Checked<String>>(Refusal(message: 'no', cause: 'DKI01')));
    expect(attempt.refusal, isNotNull);
    expect(attempt.basis, isNull);
    await attempt.check(() async => const CommandUnreached<Checked<String>>(Defect('offline')));
    expect(attempt.checkUnreached, isTrue);
    expect(attempt.refusal, isNull);
  });

  test('what the server says is missing is kept with the document', () async {
    await attempt.check(() async => _checked(const PreviewedDocument(missing: ['due_on'])));
    expect(attempt.missing, ['due_on']);
    expect(attempt.document?.ready, isFalse);
  });
}
