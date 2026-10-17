// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2585 C3 -- the answer of the real `preview_invoice`, over a signed HTTP
// request to the job's replayed stack, decoded by the app's own adapter
// (SupabaseInvoiceQueries.previewInvoice -> decodeInvoicePreview).
//
// The expected values are written down from the seed in
// scripts/topology_stacks.sh (35.00 fee + 10.00 zero-rated supply in
// 2026-09; 35.00 fee - 50.00 advance in 2026-08; nothing in 2025-12), not
// taken from the SQL under test or from the decoder. Runs only with
// DESKILO_TOPOLOGY_FILE; the malformed-answer negatives stay in
// invoice_preview_decoding_test.dart and are not a substitute for this path.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/money/data/supabase_invoice_queries.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

final _file = Platform.environment['DESKILO_TOPOLOGY_FILE'];

void main() {
  if (_file == null) {
    test(
      'the preview over HTTP',
      () {},
      skip: 'needs the stack of the database job; set DESKILO_TOPOLOGY_FILE',
    );
    return;
  }
  late String workspaceId;
  late String memberId;
  late SupabaseInvoiceQueries asMember;
  late SupabaseInvoiceQueries asStranger;

  Future<SupabaseInvoiceQueries> signedIn(
    Map<String, dynamic> stack,
    Map<String, dynamic> who,
    String password,
  ) async {
    final client = SupabaseClient(
      stack['url'] as String,
      stack['anon'] as String,
      httpClient: http.Client(),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final session = await client.auth.signInWithPassword(
      email: who['email'] as String,
      password: password,
    );
    expect(
      session.user?.id,
      who['id'],
      reason: 'signed in as the seeded account',
    );
    return SupabaseInvoiceQueries(client);
  }

  setUpAll(() async {
    // flutter_test replaces the HTTP client with one that answers 400.
    HttpOverrides.global = null;
    final d =
        jsonDecode(File(_file!).readAsStringSync()) as Map<String, dynamic>;
    final wa = d['wa'] as Map<String, dynamic>;
    final preview = wa['preview'] as Map<String, dynamic>;
    workspaceId = preview['workspaceId'] as String;
    memberId = preview['memberId'] as String;
    final password = d['password'] as String;
    asMember = await signedIn(
      wa,
      preview['member'] as Map<String, dynamic>,
      password,
    );
    asStranger = await signedIn(
      wa,
      wa['stranger'] as Map<String, dynamic>,
      password,
    );
  });

  test('a month with a fee and a zero-rated supply previews 4500', () async {
    final r = await asMember.previewInvoice(
      workspaceId: workspaceId,
      memberId: memberId,
      period: '2026-09',
    );
    expect(r.totalCents, 4500);
    expect(r.lines.map((l) => l.amountCents), [3500, 1000]);
    expect(r.lines.every((l) => l.quantity == 1), isTrue);
  });

  test('a month with more received than supplied previews -1500', () async {
    final r = await asMember.previewInvoice(
      workspaceId: workspaceId,
      memberId: memberId,
      period: '2026-08',
    );
    expect(r.totalCents, -1500);
    expect(r.lines.map((l) => l.amountCents), contains(-5000));
  });

  test('a month before the member joined is an explicit empty 0', () async {
    final r = await asMember.previewInvoice(
      workspaceId: workspaceId,
      memberId: memberId,
      period: '2025-12',
    );
    expect(r.lines, isEmpty);
    expect(r.totalCents, 0);
  });

  test('a stranger of another workspace is refused, not shown a zero', () async {
    await expectLater(
      asStranger.previewInvoice(
        workspaceId: workspaceId,
        memberId: memberId,
        period: '2026-09',
      ),
      throwsA(isA<PostgrestException>()),
    );
  });
}
