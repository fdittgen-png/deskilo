// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The bank statement import end to end over the in-memory store that keeps
// the server's rules (#2380): the camt.054 fixture's QR and RF payments
// are confirmed against their two invoices in one press and the third
// movement stays in the work list; the same file again imports nothing;
// two movements alike in every field but their bank ids stay two; an
// overlapping spreadsheet without bank ids waits for a review instead of
// collapsing; a refused file sends nothing; a decision the store refuses
// leaves the movement as it was.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/demo/data/bank_statement_repository.dart';
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/features/money/application/bank_import_commands.dart';
import 'package:deskilo/features/money/domain/bank/bank_import_settings.dart';
import 'package:deskilo/features/money/domain/bank/bank_match.dart';
import 'package:deskilo/features/money/domain/bank/bank_records.dart';
import 'package:deskilo/features/money/domain/bank/bank_statement.dart';
import 'package:deskilo/features/money/domain/bank/csv_statement.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:flutter_test/flutter_test.dart';

const _settings = BankImportSettings();

Invoice _invoice(String number, int total, {String member = 'm1'}) => Invoice(
  id: 'id-$number',
  workspaceId: 'ws-1',
  memberId: member,
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
);

List<int> _fixture(String name) =>
    File('test/features/money/fixtures/bank/$name').readAsBytesSync();

void main() {
  late FakeMoneyRepository money;
  late FakeBankStatementRepository bank;
  late BankImportCommands commands;

  setUp(() {
    money = FakeMoneyRepository();
    // The fixture's QR reference 210000000003139471430009017 and RF
    // reference RF18539007547034 are these numbers' own references.
    money.invoices.addAll([
      _invoice('21000000000313947143000901', 12000),
      _invoice('539007547034', 8050, member: 'm2'),
    ]);
    bank = FakeBankStatementRepository(money: money, today: DateTime.utc(2026, 10, 26));
    commands = BankImportCommands(bank);
  });

  Future<BankImportOutcome> import(List<int> bytes, BankFileFormat format, {BankCsvMapping? csv}) =>
      commands.importFile(
        'ws-1',
        bytes: bytes,
        fileName: 'f',
        format: format,
        settings: _settings,
        csv: csv,
      );

  test('camt.054: the QR and the RF payment settle their two invoices in one '
      'press, the third stays in the work list, the same file again adds '
      'nothing', () async {
    final first = await import(_fixture('camt054_notification.xml'), BankFileFormat.camt054);
    expect(first.refused, isNull);
    expect(first.result!.created, 3);
    final id = first.result!.statementId;
    var lines = await bank.fetchLines(id);
    final open = openInvoices(money.invoices, money.invoiceMatchesStore);
    expect(
      await commands.confirmReferenceMatches(
        BankWorkList(lines, open, windowDays: 60),
      ),
      2,
    );
    lines = await bank.fetchLines(id);
    expect(
      lines.where((l) => l.status == BankLineStatus.matched).map((l) => l.invoiceNumber),
      unorderedEquals(['21000000000313947143000901', '539007547034']),
    );
    final rest = lines.where((l) => l.status.isOpen).single;
    expect(rest.amountCents, 3000);
    expect(money.invoiceMatchesStore.keys, unorderedEquals(['id-21000000000313947143000901', 'id-539007547034']));
    expect(
      money.ledger.where((e) => e.amountCents == 12000 || e.amountCents == 8050),
      hasLength(2),
      reason: 'one payment credit per movement, no more',
    );

    final again = await import(_fixture('camt054_notification.xml'), BankFileFormat.camt054);
    expect(again.result!.repeated, isTrue);
    expect(again.result!.statementId, id);
    expect(await bank.fetchStatements('ws-1'), hasLength(1));
    expect(
      await commands.confirmReferenceMatches(
        BankWorkList(
          await bank.fetchLines(id),
          openInvoices(money.invoices, money.invoiceMatchesStore),
          windowDays: 60,
        ),
      ),
      0,
      reason: 'a settled movement is not confirmed twice',
    );
  });

  test('two movements alike but for their bank ids are two; a later file '
      'repeating one by its bank id adds only the other', () async {
    String file(List<String> ids) => [
      'date;amount;ref;id',
      for (final id in ids) '2026-10-20;120.00;RF18539007547034;$id',
    ].join('\n');
    const mapping = BankCsvMapping(
      account: 'CH9300762011623852957',
      delimiter: ';',
      fixedCurrency: 'CHF',
      bookingDate: 0,
      amount: 1,
      reference: 2,
      transactionId: 3,
    );
    final one = await import(utf8.encode(file(['A', 'B'])), BankFileFormat.csv, csv: mapping);
    expect(one.result!.created, 2);
    final two = await import(utf8.encode(file(['B', 'C'])), BankFileFormat.csv, csv: mapping);
    expect((two.result!.created, two.result!.known, two.result!.review), (1, 1, 0));
  });

  test('an overlapping spreadsheet without bank ids waits for a review, and '
      'the review decides', () async {
    const mapping = BankCsvMapping(
      account: 'CH9300762011623852957',
      delimiter: ';',
      fixedCurrency: 'CHF',
      bookingDate: 0,
      amount: 1,
      remittance: 2,
    );
    final march = utf8.encode('date;amount;text\n2026-10-20;45.00;Coffee\n');
    final april = utf8.encode('date;amount;text\n2026-10-20;45.00;Coffee\n2026-10-21;12.00;Tea\n');
    expect((await import(march, BankFileFormat.csv, csv: mapping)).result!.created, 1);
    final second = (await import(april, BankFileFormat.csv, csv: mapping)).result!;
    expect((second.created, second.review), (1, 1));
    final review = (await bank.fetchLines(second.statementId))
        .singleWhere((l) => l.status == BankLineStatus.review);
    await expectLater(
      commands.confirm(review, invoiceId: 'id-539007547034', dueCents: 8050),
      throwsStateError,
      reason: 'a movement waiting for its review settles nothing',
    );
    expect(
      await commands.review(review, duplicate: true),
      BankLineStatus.duplicate,
    );
  });

  test('two movements carrying one invoice\'s QR reference: the batch '
      'confirms the first and leaves the second to its own decision', () async {
    const mapping = BankCsvMapping(
      account: 'CH9300762011623852957',
      delimiter: ';',
      fixedCurrency: 'CHF',
      bookingDate: 0,
      amount: 1,
      reference: 2,
      transactionId: 3,
    );
    final file = utf8.encode(
      'date;amount;ref;id\n'
      '2026-10-20;120.00;210000000003139471430009017;Q1\n'
      '2026-10-21;120.00;210000000003139471430009017;Q2\n',
    );
    final id = (await import(file, BankFileFormat.csv, csv: mapping)).result!.statementId;
    final list = BankWorkList(
      await bank.fetchLines(id),
      openInvoices(money.invoices, money.invoiceMatchesStore),
      windowDays: 60,
    );
    expect(list.items.where((i) => i.referenceMatch != null), hasLength(2));
    expect(await commands.confirmReferenceMatches(list), 1);
    final lines = await bank.fetchLines(id);
    expect(lines.map((l) => l.status), [BankLineStatus.matched, BankLineStatus.open]);
  });

  test('a spreadsheet row worth nothing is refused, by its line', () async {
    const mapping = BankCsvMapping(
      account: 'A-1',
      delimiter: ';',
      fixedCurrency: 'CHF',
      bookingDate: 0,
      credit: 1,
      debit: 2,
    );
    final out = await import(
      utf8.encode('date;in;out\n2026-10-20;12.00;\n2026-10-21;;\n'),
      BankFileFormat.csv,
      csv: mapping,
    );
    expect(out.refused?.problem, BankFileProblem.badAmount);
    expect(out.refused?.line, 3);
    expect(await bank.fetchStatements('ws-1'), isEmpty);
  });

  test('a mapping names its problems: an account too long, a column chosen '
      'twice, and no currency needed when a column carries it', () {
    expect(
      bankCsvMappingProblems(
        account: 'x' * (BankColumnWidths.account + 1),
        currency: 'CHF',
        dateColumn: 0,
        amountColumn: 1,
      ),
      {BankCsvMappingProblem.account},
    );
    expect(
      bankCsvMappingProblems(
        account: 'A-1',
        currency: 'CHF',
        dateColumn: 0,
        amountColumn: 1,
        otherColumns: [1],
      ),
      {BankCsvMappingProblem.duplicateColumn},
    );
    expect(
      bankCsvMappingProblems(
        account: 'A-1',
        currency: '',
        dateColumn: 0,
        amountColumn: 1,
        currencyColumn: 2,
      ),
      isEmpty,
    );
  });

  test('an account or a bank id longer than its column refuses the file; '
      'an IBAN cell that is not one is left out', () async {
    BankCsvMapping mapping(String account) => BankCsvMapping(
      account: account,
      delimiter: ';',
      fixedCurrency: 'CHF',
      bookingDate: 0,
      amount: 1,
      counterpartyIban: 2,
      transactionId: 3,
    );
    final ok = utf8.encode('d;a;iban;id\n2026-10-20;5.00;n/a;T-1\n');
    final long = utf8.encode('d;a;iban;id\n2026-10-20;5.00;;${'T' * 141}\n');
    expect(
      (await import(ok, BankFileFormat.csv, csv: mapping('x' * 65))).refused?.problem,
      BankFileProblem.tooLong,
    );
    expect(
      (await import(long, BankFileFormat.csv, csv: mapping('A-1'))).refused?.problem,
      BankFileProblem.tooLong,
    );
    final kept = await import(ok, BankFileFormat.csv, csv: mapping('A-1'));
    expect(
      (await bank.fetchLines(kept.result!.statementId)).single.counterpartyIban,
      '',
    );
  });

  test('a refused file names its reason and sends nothing', () async {
    final out = await commands.importFile(
      'ws-1',
      bytes: _fixture('camt054_notification.xml'),
      fileName: 'f',
      format: BankFileFormat.camt054,
      settings: const BankImportSettings(maxLines: 2),
    );
    expect(out.refused?.problem, BankFileProblem.tooManyLines);
    expect(await bank.fetchStatements('ws-1'), isEmpty);
  });

  test('an under-payment resolves as accepted with its note', () async {
    final id = (await import(_fixture('camt054_notification.xml'), BankFileFormat.camt054)).result!.statementId;
    final lines = await bank.fetchLines(id);
    final thirty = lines.singleWhere((l) => l.amountCents == 3000);
    expect(
      await commands.confirm(
        thirty,
        invoiceId: 'id-539007547034',
        dueCents: 8050,
        note: 'paid in part',
      ),
      BankLineStatus.matched,
    );
    expect(money.invoiceMatchesStore['id-539007547034']!.resolution, 'under_accepted');
  });
}
