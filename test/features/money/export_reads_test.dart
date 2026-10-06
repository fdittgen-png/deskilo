// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant (#1885): the reads an accountant handoff is built from are read
// to the end whatever the server's row cap is, each in a TOTAL order (the
// tie-breaker is part of the query), so a page boundary can neither drop nor
// repeat a record; and the files that carry the export are written whole or
// not at all and zip to the same bytes every time.
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:deskilo/core/files/file_saver_io.dart';
import 'package:deskilo/features/money/data/supabase_money_repository.dart';
import 'package:deskilo/features/money/domain/archive_bundle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient _client(
  List<Map<String, Object?>> rows,
  List<Uri> seen, {
  int cap = 2,
}) => SupabaseClient(
  'https://money.example',
  'sb_publishable_money',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
  httpClient: MockClient((request) async {
    seen.add(request.url);
    final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
    final limit = int.parse(request.url.queryParameters['limit'] ?? '1000');
    final end = [
      offset + limit,
      offset + cap,
      rows.length,
    ].reduce((a, b) => a < b ? a : b);
    final page = offset >= rows.length
        ? <Map<String, Object?>>[]
        : rows.sublist(offset, end);
    return http.Response(
      jsonEncode(page),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }),
);

Map<String, Object?> _match(String invoice) => {
  'invoice_id': invoice,
  'paid_cents': 1000,
  'resolution': 'matched',
  'note': '',
  'status': 'confirmed',
  'payment_ledger_id': null,
  'matched_at': '2026-09-01T10:00:00Z',
  'by_name': 'Ana',
  'writeoff_at': null,
  'event_id': null,
};

void main() {
  test(
    'cap 2: all three payment matches arrive, once, ordered by invoice',
    () async {
      final seen = <Uri>[];
      final repo = SupabaseMoneyRepository(
        _client([_match('i1'), _match('i2'), _match('i3')], seen),
      );
      final matches = await repo.fetchInvoiceMatches('ws-1');
      expect(matches.keys, ['i1', 'i2', 'i3']);
      expect(
        seen.every(
          (u) => '${u.queryParameters['order']}'.startsWith('invoice_id.asc'),
        ),
        isTrue,
      );
    },
  );

  for (final read
      in <String, Future<Object?> Function(SupabaseMoneyRepository)>{
        'invoices': (r) => r.fetchInvoices('ws-1'),
        'ledger': (r) => r.fetchWorkspaceLedger('ws-1'),
        'payment intents': (r) => r.fetchPaymentIntents('ws-1'),
        'invoice transmissions': (r) => r.fetchInvoiceTransmissions('ws-1'),
      }.entries) {
    test('${read.key} are ordered by a unique tie-breaker', () async {
      final seen = <Uri>[];
      await read.value(SupabaseMoneyRepository(_client(const [], seen)));
      expect(seen.first.queryParameters['order'], contains(',id.asc'));
    });
  }

  group('files', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('atomic_save'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('a save writes the whole file and leaves no temporary one', () async {
      final path = await writeFileAtomically(File('${dir.path}/export.zip'), [
        1,
        2,
        3,
      ]);
      expect(File(path).readAsBytesSync(), [1, 2, 3]);
      expect(dir.listSync().length, 1);
    });

    test('a failed write leaves the previous valid export untouched', () async {
      final target = File('${dir.path}/export.zip')..writeAsBytesSync([9, 9]);
      // The temporary name is taken by a directory: the write cannot start.
      Directory('${target.path}.part').createSync();
      await expectLater(
        writeFileAtomically(target, [1, 2, 3]),
        throwsA(isA<IOException>()),
      );
      expect(target.readAsBytesSync(), [9, 9]);
    });
  });

  test('the same files zip to the same bytes, with the fixed entry time', () {
    final files = {'b.csv': utf8.encode('b'), 'a.csv': utf8.encode('a')};
    final first = zipBundle(files);
    expect(zipBundle(files), first);
    final entries = ZipDecoder().decodeBytes(first).files;
    expect(entries.map((f) => f.name), ['a.csv', 'b.csv']);
  });
}
