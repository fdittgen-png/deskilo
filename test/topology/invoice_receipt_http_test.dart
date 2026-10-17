// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2585 C2 -- the request receipts of 0462..0464 over signed HTTP, through
// the app's own adapters (SupabaseInvoiceCommands / SupabaseInvoiceActionCommands
// / SupabaseInvoiceQueries), against the replayed stack of the database job.
//
// Expected values are written down from the seed in scripts/topology_stacks.sh
// (35.00 fee + 4.50 supply = 3950 in 2026-07; 35.00 + 3.00 = 3800 in 2026-06;
// the fee alone = 3500 in 2026-05), not read from the SQL under test. The
// invoices are read back through the register, and every refusal is followed
// by a readback proving nothing changed. Runs only with DESKILO_TOPOLOGY_FILE.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/money/data/supabase_invoice_action_commands.dart';
import 'package:deskilo/features/money/data/supabase_invoice_commands.dart';
import 'package:deskilo/features/money/data/supabase_invoice_queries.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/command_receipt.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

final _file = Platform.environment['DESKILO_TOPOLOGY_FILE'];

/// Fixed request ids of this file (a random id per attempt in the app).
const _issue = '00000000-0000-4000-8000-00000025a001';
const _other = '00000000-0000-4000-8000-00000025a002';
const _june = '00000000-0000-4000-8000-00000025a003';
const _may = '00000000-0000-4000-8000-00000025a004';
const _settle = '00000000-0000-4000-8000-00000025a005';
const _void = '00000000-0000-4000-8000-00000025a006';

void main() {
  if (_file == null) {
    test(
      'the receipts over HTTP',
      () {},
      skip: 'needs the stack of the database job; set DESKILO_TOPOLOGY_FILE',
    );
    return;
  }
  late String ws;
  late String member;
  late SupabaseInvoiceCommands commands;
  late SupabaseInvoiceActionCommands actions;
  late SupabaseInvoiceQueries queries;
  late SupabaseInvoiceQueries stranger;

  Future<SupabaseClient> signedIn(
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
    expect(session.user?.id, who['id'], reason: 'the seeded account');
    return client;
  }

  Future<List<Invoice>> register() => queries.fetchInvoices(ws);

  Invoice month(List<Invoice> all, String period) => all.singleWhere(
    (i) => i.period == period && i.kind != InvoiceKind.settlement,
  );

  setUpAll(() async {
    // flutter_test replaces the HTTP client with one that answers 400.
    HttpOverrides.global = null;
    final d =
        jsonDecode(File(_file!).readAsStringSync()) as Map<String, dynamic>;
    final wa = d['wa'] as Map<String, dynamic>;
    final preview = wa['preview'] as Map<String, dynamic>;
    ws = preview['workspaceId'] as String;
    member = preview['memberId'] as String;
    final password = d['password'] as String;
    final owner = await signedIn(
      wa,
      preview['owner'] as Map<String, dynamic>,
      password,
    );
    commands = SupabaseInvoiceCommands(owner);
    actions = SupabaseInvoiceActionCommands(owner);
    queries = SupabaseInvoiceQueries(owner);
    stranger = SupabaseInvoiceQueries(
      await signedIn(wa, wa['stranger'] as Map<String, dynamic>, password),
    );
  });

  InvoiceIssueCommand cmd(String period, String id) => InvoiceIssueCommand(
    workspaceId: ws,
    memberId: member,
    period: period,
    requestId: id,
  );

  test(
    'issue under a request id: one invoice, the replay answers the original',
    () async {
      final id = await commands.issueInvoiceWithReceipt(cmd('2026-07', _issue));
      final again = await commands.issueInvoiceWithReceipt(
        cmd('2026-07', _issue),
      );
      expect(again, id, reason: 'the replay answers the ORIGINAL id');
      final all = await register();
      final july = all.where((i) => i.period == '2026-07').toList();
      expect(july, hasLength(1), reason: 'the replay issued nothing');
      expect(july.single.id, id);
      expect(july.single.totalCents, 3950);
      final receipt = await queries.invoiceCommandOutcome(
        workspaceId: ws,
        requestId: _issue,
      );
      expect(receipt.state, CommandReceiptState.applied);
      expect(receipt.invoiceId, id);
    },
  );

  test(
    'another request id for the same month is refused and never relabelled',
    () async {
      await expectLater(
        commands.issueInvoiceWithReceipt(cmd('2026-07', _other)),
        throwsA(isA<PostgrestException>()),
      );
      final receipt = await queries.invoiceCommandOutcome(
        workspaceId: ws,
        requestId: _other,
      );
      expect(receipt.state, CommandReceiptState.notObserved);
      expect(
        (await register()).where((i) => i.period == '2026-07'),
        hasLength(1),
      );
    },
  );

  test(
    'the same id with another period is a conflict and records nothing',
    () async {
      await expectLater(
        commands.issueInvoiceWithReceipt(cmd('2026-06', _issue)),
        throwsA(isA<PostgrestException>()),
      );
      expect((await register()).where((i) => i.period == '2026-06'), isEmpty);
    },
  );

  test('a stranger of another workspace cannot read the outcome', () async {
    await expectLater(
      stranger.invoiceCommandOutcome(workspaceId: ws, requestId: _issue),
      throwsA(isA<PostgrestException>()),
    );
  });

  test(
    'batch issue and settlement: replays, any id order, one document',
    () async {
      final june = await actions.createInvoiceOnce(cmd('2026-06', _june));
      final juneAgain = await actions.createInvoiceOnce(cmd('2026-06', _june));
      final may = await actions.createInvoiceOnce(cmd('2026-05', _may));
      expect(juneAgain, june);
      final before = await register();
      expect(month(before, '2026-06').totalCents, 3800);
      expect(month(before, '2026-05').totalCents, 3500);

      final settlement = await actions.settleInvoicesOnce(
        workspaceId: ws,
        memberId: member,
        invoiceIds: [june, may],
        requestId: _settle,
        note: 'quarter',
      );
      final again = await actions.settleInvoicesOnce(
        workspaceId: ws,
        memberId: member,
        invoiceIds: [may, june],
        requestId: _settle,
        note: 'quarter',
      );
      expect(
        again,
        settlement,
        reason: 'the replay answers the same settlement',
      );
      final after = await register();
      expect(
        after.where((i) => i.kind == InvoiceKind.settlement),
        hasLength(1),
      );
      expect(after.singleWhere((i) => i.id == settlement).totalCents, 7300);
      final receipt = await queries.invoiceCommandOutcome(
        workspaceId: ws,
        requestId: _settle,
      );
      expect(receipt.invoiceId, settlement);

      await expectLater(
        actions.settleInvoicesOnce(
          workspaceId: ws,
          memberId: member,
          invoiceIds: [june, may],
          requestId: _settle,
          note: 'another note',
        ),
        throwsA(isA<PostgrestException>()),
      );
    },
  );

  test(
    'void under a request id: applied once, the replay does not fail',
    () async {
      final july = month(await register(), '2026-07');
      expect(july.isVoided, isFalse);
      await actions.voidInvoice(
        july.id,
        requestId: _void,
        reason: 'wrong month',
      );
      await actions.voidInvoice(
        july.id,
        requestId: _void,
        reason: 'wrong month',
      );
      expect(month(await register(), '2026-07').isVoided, isTrue);
      final receipt = await queries.invoiceCommandOutcome(
        workspaceId: ws,
        requestId: _void,
      );
      expect(receipt.state, CommandReceiptState.applied);
      expect(receipt.invoiceId, july.id);
      await expectLater(
        actions.voidInvoice(july.id, requestId: _other, reason: 'again'),
        throwsA(isA<PostgrestException>()),
      );
    },
  );
}
