// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2370 — the accounting connections as the app reads and sends them: the
// server's answers parsed, the mapping keys checked with the server's
// shapes (pgTAP 9999 refuses the same), the commands sending nothing that
// cannot be right, and the generic journal's documents each with their own
// digest, so delivering the same books twice changes nothing.
import 'package:deskilo/core/demo/data/accounting_connection_repository.dart';
import 'package:deskilo/core/demo/data/book_period_repository.dart';
import 'package:deskilo/features/money/application/accounting_connection_commands.dart';
import 'package:deskilo/features/money/application/book_period_commands.dart';
import 'package:deskilo/features/money/domain/accounting_amount.dart';
import 'package:deskilo/features/money/domain/accounting_connection.dart';
import 'package:deskilo/features/money/domain/accounting_target.dart';
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/domain/generic_journal_csv.dart';
import 'package:deskilo/features/money/domain/posting.dart';
import 'package:flutter_test/flutter_test.dart';

final _today = DateTime(2026, 10, 25);
const _member = '00000000-0000-4000-8000-0000023700c4';

AccountingAmount _eur(int cents) => AccountingAmount('EUR', cents);

PostingLine _line(BookRole role, String account, {int debit = 0, int credit = 0, String? qualifier}) =>
    PostingLine(role: role, accountCode: account, debit: _eur(debit), credit: _eur(credit), qualifier: qualifier);

/// The seeded year in small: an invoice at two rates, its partial payment,
/// a credit note and its refund, a write-off.
List<Posting> _year() => [
  Posting(
    journal: PostingJournal.sales,
    date: DateTime(2026, 2),
    kind: PostingKind.invoice,
    documentId: 'inv-1',
    documentNumber: 'F-1',
    lines: [
      _line(BookRole.customers, '411', debit: 13100),
      _line(BookRole.revenue, '706', credit: 10000, qualifier: 'standard'),
      _line(BookRole.vatOutput, '44571', credit: 2000, qualifier: 'standard'),
      _line(BookRole.revenue, '706', credit: 1043, qualifier: 'reduced'),
      _line(BookRole.vatOutput, '44571', credit: 57, qualifier: 'reduced'),
    ],
  ),
  Posting(
    journal: PostingJournal.bank,
    date: DateTime(2026, 2, 20),
    kind: PostingKind.receipt,
    documentId: 'inv-1',
    documentNumber: 'F-1',
    lines: [_line(BookRole.bank, '512', debit: 5000), _line(BookRole.customers, '411', credit: 5000)],
  ),
  Posting(
    journal: PostingJournal.sales,
    date: DateTime(2026, 3, 5),
    kind: PostingKind.creditNote,
    documentId: 'cn-1',
    documentNumber: 'A-1',
    lines: [_line(BookRole.revenue, '706', debit: 1000), _line(BookRole.customers, '411', credit: 1000)],
  ),
  Posting(
    journal: PostingJournal.bank,
    date: DateTime(2026, 3, 6),
    kind: PostingKind.refund,
    documentId: 'cn-1',
    documentNumber: 'A-1',
    lines: [_line(BookRole.customers, '411', debit: 1000), _line(BookRole.bank, '512', credit: 1000)],
  ),
  Posting(
    journal: PostingJournal.other,
    date: DateTime(2026, 6, 30),
    kind: PostingKind.writeOff,
    documentId: 'inv-1',
    documentNumber: 'F-1',
    lines: [_line(BookRole.writeOff, '654', debit: 8100), _line(BookRole.customers, '411', credit: 8100)],
  ),
];

class _Broken extends FakeAccountingConnectionRepository {
  _Broken() : super(books: FakeBookPeriodRepository(today: _today), today: _today);

  @override
  Future<FileDeliveryOutcome> recordFileDeliveries(
    String workspaceId, {
    required String targetId,
    required String issuerSiteId,
    required String bookExportId,
    required List<FileDocument> documents,
  }) async => throw Exception('offline');
}

void main() {
  test('the mapping keys have the shapes the server accepts', () {
    bool ok(AccountingMapKind k, String key) => accountingMapKeyValid(k, key);
    expect(ok(AccountingMapKind.tax, 'VAT|FR|taxed|20|2014'), isTrue);
    expect(ok(AccountingMapKind.tax, 'GST|CA-QC|taxed|9.975|2013'), isTrue);
    expect(ok(AccountingMapKind.tax, 'VAT|FR|zeroRated|0|'), isTrue);
    expect(ok(AccountingMapKind.tax, 'VAT|FR|5.5'), isFalse);
    expect(ok(AccountingMapKind.tax, 'VAT|FR|unknown|20|2014'), isFalse);
    expect(ok(AccountingMapKind.account, 'revenue:standard'), isTrue);
    expect(ok(AccountingMapKind.account, 'Revenue'), isFalse);
    expect(ok(AccountingMapKind.item, 'revenue'), isTrue);
    expect(ok(AccountingMapKind.party, partyMapKey(AccountingPartyKind.member, _member)), isTrue);
    expect(ok(AccountingMapKind.party, 'member:42'), isFalse);
  });

  test('a mapping without a valid key or a remote name is not sent', () async {
    final repo = FakeAccountingConnectionRepository(books: FakeBookPeriodRepository(today: _today), today: _today);
    final commands = AccountingConnectionCommands(repo);
    final c = (await commands.connectWithToken('ws', issuerSiteId: 's', targetId: 'pennylane_api',
        displayName: ' Pennylane ', token: 'tok-secret-2370', remoteTenantId: ''))!;
    expect(mapDraftProblem(const AccountingMapDraft(kind: AccountingMapKind.tax, key: 'VAT|FR|5.5', remoteCode: 'FR_55')),
        MapDraftProblem.key);
    expect(mapDraftProblem(const AccountingMapDraft(kind: AccountingMapKind.tax, key: 'VAT|FR|taxed|5.5|2014')),
        MapDraftProblem.remote);
    expect(await commands.saveMap(c.id, const AccountingMapDraft(kind: AccountingMapKind.tax, key: 'VAT|FR|5.5', remoteCode: 'x')), isNull);
    final saved = (await commands.saveMap(c.id,
        const AccountingMapDraft(kind: AccountingMapKind.tax, key: ' VAT|FR|taxed|5.5|2014 ', remoteCode: ' FR_55 ')))!;
    expect(saved.maps.single.key, 'VAT|FR|taxed|5.5|2014');
    expect(saved.maps.single.remote, 'FR_55');
  });

  test('a token too short is not sent; a token connects and is never read back', () async {
    final repo = FakeAccountingConnectionRepository(books: FakeBookPeriodRepository(today: _today), today: _today);
    final commands = AccountingConnectionCommands(repo);
    expect(await commands.connectWithToken('ws', issuerSiteId: 's', targetId: 'pennylane_api',
        displayName: 'P', token: 'short', remoteTenantId: ''), isNull);
    expect(await repo.fetchConnections('ws'), isEmpty);
    final c = (await commands.connectWithToken('ws', issuerSiteId: 's', targetId: 'pennylane_api',
        displayName: 'P', token: 'tok-secret-2370', remoteTenantId: '812345678'))!;
    expect(c.status, ConnectionStatus.connected);
    expect(c.secretsSet, ['access_token']);
    expect(c.remoteTenantId, '812345678');
    await expectLater(
      commands.connectWithToken('ws', issuerSiteId: 's', targetId: 'pennylane_api',
          displayName: 'P', token: 'tok-secret-2370', remoteTenantId: ''),
      throwsStateError,
      reason: 'one live connection per issuer and target',
    );
    final revoked = await commands.revoke(c.id);
    expect(revoked.live, isFalse);
    expect(revoked.secretsSet, isEmpty);
  });

  test("the server's answers are read whole", () {
    final c = AccountingConnection.fromJson({
      'id': 'c1', 'issuer_site_id': 's1', 'target_id': 'pennylane_api', 'auth_kind': 'oauth2',
      'remote_tenant_id': '', 'display_name': 'P', 'status': 'expired', 'status_detail': 'invalid_grant',
      'scopes': <String>[], 'connected_at': '2026-01-05T09:00:00Z', 'token_expires_at': null,
      'refresh_expires_at': null, 'revoked_at': null, 'secrets_set': ['refresh_token'],
      'maps': [
        {'id': 'm1', 'kind': 'party', 'key': 'member:$_member', 'remote_id': 'C-9', 'remote_code': '', 'remote_name': 'Ada'},
      ],
    });
    expect(c.authKind, AccountingAuthKind.oauth2);
    expect(c.needsAttention, isTrue);
    expect(c.maps.single.remote, 'C-9');
    final t = AccountingTransfers.fromJson({
      'files': [
        {
          'id': 'e1', 'format_id': 'generic_journal_csv', 'period_from': '2026-01-01', 'period_to': '2026-12-31',
          'sha256': 'e' * 64, 'byte_count': 10, 'row_count': 2, 'document_count': 3, 'closed_period': true,
          'exported_at': '2026-10-25T08:00:00Z', 'exported_by_member_id': 'm-e',
          'deliveries': [
            {'id': 'd1', 'target_id': 'generic_journal_csv', 'connection_id': null, 'book_export_id': 'e1',
             'document_kind': 'invoice', 'document_id': 'inv-1', 'document_number': 'F-1', 'event_date': '2026-02-01',
             'payload_sha256': 'a' * 64, 'status': 'generated', 'attempts': 1},
          ],
        },
      ],
      'deliveries': [
        {'id': 'd2', 'target_id': 'pennylane_api', 'connection_id': 'c1', 'book_export_id': null,
         'document_kind': 'credit_note', 'document_id': 'cn-1', 'event_date': '2026-03-05',
         'payload_sha256': 'c' * 64, 'status': 'conflict', 'error': 'no answer after send', 'attempts': 2},
      ],
    });
    expect(t.files.single.deliveries.single.bookExportId, 'e1');
    expect(t.files.single.exportedByMemberId, 'm-e');
    expect(t.deliveries.single.status, DeliveryStatus.conflict);
    expect(t.deliveries.single.attempts, 2);
  });

  test('each document event of the journal carries the digest of its own rows', () {
    final docs = genericJournalDocuments(_year());
    expect([for (final d in docs) '${d.kind} ${d.number}'], [
      'invoice F-1', 'receipt F-1', 'credit_note A-1', 'refund A-1', 'write_off F-1',
    ]);
    expect({for (final d in docs) d.sha256}, hasLength(5), reason: 'every event its own digest');
    expect(genericJournalDocuments(_year()).map((d) => d.sha256), docs.map((d) => d.sha256),
        reason: 'the same books give the same digests');
    // The rows hashed are the file's own rows.
    final file = buildGenericJournalCsv(_year());
    expect(file.split('\r\n').where((l) => l.isNotEmpty), hasLength(1 + 5 + 2 + 2 + 2 + 2));
  });

  test('two postings of one event share one delivery', () {
    final twice = [..._year().take(2), _year()[1]];
    expect(genericJournalDocuments(twice).map((d) => d.kind), ['invoice', 'receipt']);
  });

  test('the seeded year delivered to the generic journal twice: one row per document, the same digests, no remote id', () async {
    final books = FakeBookPeriodRepository(today: _today);
    final repo = FakeAccountingConnectionRepository(books: books, today: _today);
    final log = BookPeriodCommands(books);
    final commands = AccountingConnectionCommands(repo);
    final content = buildGenericJournalCsv(_year());
    Future<FileDeliveryOutcome?> deliver() async {
      final id = await log.logExport('ws', formatId: 'generic_journal_csv', year: 2026, content: content, documents: 2);
      return commands.logJournalFile('ws', bookExportId: id!, targetId: 'generic_journal_csv',
          issuerSiteId: 'site', postings: _year());
    }

    final first = (await deliver())!;
    expect((first.created, first.unchanged, first.changed), (5, 0, 0));
    final digests = [for (final d in repo.deliveries) d.payloadSha256];
    final again = (await deliver())!;
    expect((again.created, again.unchanged, again.changed), (0, 5, 0));
    expect(repo.deliveries, hasLength(5));
    expect([for (final d in repo.deliveries) d.payloadSha256], digests);
    expect(repo.deliveries.where((d) => d.remoteId.isNotEmpty), isEmpty);
    final transfers = await repo.fetchTransfers('ws', DateTime(2026), DateTime(2026, 12, 31));
    expect(transfers.files.map((f) => f.deliveries.length), [0, 5],
        reason: 'the documents stay with the file that first carried them');
    expect(transfers.files.first.sha256, transfers.files.last.sha256);
  });

  test('a failed delivery log never fails the export', () async {
    final out = await AccountingConnectionCommands(_Broken()).logJournalFile('ws',
        bookExportId: 'e', targetId: 'generic_journal_csv', issuerSiteId: 's', postings: _year());
    expect(out, isNull);
  });
}
