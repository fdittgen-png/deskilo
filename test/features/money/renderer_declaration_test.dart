// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3336 (0694) — what the app declares about itself when it hands a document
// to the server: the renderer (the format builder) and the app version, from
// the one source the About screen reads. Declared, never proof; empty parts
// are left out so an app that cannot tell its version claims none. Both the
// e-invoice send and the book export carry it.
import 'dart:convert';

import 'package:deskilo/features/money/data/supabase_book_period_repository.dart';
import 'package:deskilo/features/money/data/supabase_einvoice_transmissions.dart';
import 'package:deskilo/features/money/domain/renderer_declaration.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A client whose every request is answered by [answer] and recorded.
SupabaseClient _client(
  List<http.Request> seen,
  http.Response Function(http.Request) answer,
) => SupabaseClient(
  'http://localhost',
  'anon-key',
  httpClient: MockClient((request) async {
    seen.add(request);
    final response = answer(request);
    // the PostgREST client reads the request off its response
    return http.Response(
      response.body,
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }),
);

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  group('RendererDeclaration', () {
    test('names the renderer and the app version', () {
      expect(
        const RendererDeclaration(
          renderer: 'facturX',
          appVersion: '1.2.3+45',
        ).toJson(),
        {'renderer': 'facturX', 'app_version': '1.2.3+45'},
      );
    });

    test('leaves out what it does not know', () {
      expect(const RendererDeclaration().toJson(), isEmpty);
      expect(const RendererDeclaration(renderer: 'peppolBis').toJson(), {
        'renderer': 'peppolBis',
      });
    });
  });

  test('an e-invoice send declares its format and the app version', () async {
    final seen = <http.Request>[];
    final repo = SupabaseEInvoiceTransmissions(
      _client(seen, (_) => _json({'status': 'accepted', 'phase': 'accepted'})),
      appVersion: () async => '9.9.9+1',
    );
    await repo.sendEInvoice(
      workspaceId: 'ws-1',
      invoiceId: 'inv-1',
      fileName: 'f.xml',
      mimeType: 'application/xml',
      bytes: const [1, 2, 3],
      format: 'peppolBis',
    );
    final body = jsonDecode(seen.single.body) as Map<String, dynamic>;
    expect(body['declared'], {
      'renderer': 'peppolBis',
      'app_version': '9.9.9+1',
    });
    expect(body['content_base64'], isNotEmpty);
  });

  test(
    'an app that cannot tell its version declares only the renderer',
    () async {
      final seen = <http.Request>[];
      final repo = SupabaseEInvoiceTransmissions(
        _client(seen, (_) => _json({'status': 'accepted'})),
      );
      await repo.sendEInvoice(
        workspaceId: 'ws-1',
        invoiceId: 'inv-1',
        fileName: 'f.pdf',
        mimeType: 'application/pdf',
        bytes: const [1],
        format: 'facturX',
      );
      final body = jsonDecode(seen.single.body) as Map<String, dynamic>;
      expect(body['declared'], {'renderer': 'facturX'});
    },
  );

  test('a book export declares its format and the app version', () async {
    final seen = <http.Request>[];
    final repo = SupabaseBookPeriodRepository(
      _client(seen, (_) => _json({'logged': true, 'id': 'e-1'})),
      appVersion: () async => '9.9.9+1',
    );
    final id = await repo.recordExport(
      'ws-1',
      BookExportRecord(
        formatId: 'fec',
        from: DateTime(2026),
        to: DateTime(2026, 12, 31),
        sha256: 'a' * 64,
        bytes: 10,
        rows: 2,
        documents: 1,
      ),
    );
    expect(id, 'e-1');
    final body = jsonDecode(seen.single.body) as Map<String, dynamic>;
    expect(body['p_declared'], {'renderer': 'fec', 'app_version': '9.9.9+1'});
    expect(body['p_sha256'], 'a' * 64);
  });
}
