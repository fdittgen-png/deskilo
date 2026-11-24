// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 A2 -- a billing customer: its pure rules, its command (nothing is sent
// for a draft that cannot be saved; a refusal and a lost answer are different
// outcomes) and its adapter over the real RPC names and wire shapes of 0821.
import 'dart:convert';

import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/core/codes/pg_code.dart';
import 'package:deskilo/core/demo/data/fake_billing_customers.dart';
import 'package:deskilo/features/money/application/billing_customer_commands.dart';
import 'package:deskilo/features/money/data/supabase_billing_customer_repository.dart';
import 'package:deskilo/features/money/domain/billing_customer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _lumi = BillingPartyDraft(
  company: 'Atelier Lumi',
  street: '1 rue du Port',
  postalCode: '34120',
  city: 'Pezenas',
  countryCode: 'fr',
  vatId: 'FR 12345678901',
  email: 'compta@lumi.test',
);

void main() {
  group('the rules a form checks before it sends', () {
    test('a company or a name is needed; either one is enough', () {
      expect(
        validateBillingParty(const BillingPartyDraft()).keys,
        contains('company'),
      );
      expect(
        validateBillingParty(const BillingPartyDraft(company: 'X')),
        isEmpty,
      );
      expect(
        validateBillingParty(const BillingPartyDraft(lastName: 'Weiss')),
        isEmpty,
      );
    });

    test('the country is two letters, the VAT number a plausible shape, the '
        'e-mail an address; blank is not wrong', () {
      expect(validateBillingParty(_lumi), isEmpty);
      final bad = validateBillingParty(
        const BillingPartyDraft(
          company: 'X',
          countryCode: 'FRA',
          vatId: '12',
          email: 'nobody',
        ),
      );
      expect(bad['country'], BillingPartyProblem.countryInvalid);
      expect(bad['vat'], BillingPartyProblem.vatIdInvalid);
      expect(bad['email'], BillingPartyProblem.emailInvalid);
    });

    test('the wire carries every field trimmed, the country upper-cased', () {
      final wire = _lumi.toWire();
      expect(wire['country_code'], 'FR');
      expect(wire['company'], 'Atelier Lumi');
      expect(wire.keys, hasLength(13));
    });

    test('a row decodes tolerantly and names the customer by its company, '
        'else its person', () {
      final p = BillingParty.fromJson({
        'subject_id': 'm1',
        'revision': 3,
        'status': 'customer',
        'capacity': 'consumer',
        'first_name': 'Hanna',
        'last_name': 'Weiss',
        'a_future_field': 1,
      });
      expect(p.revision, 3);
      expect(p.capacity, 'consumer');
      expect(p.displayName, 'Hanna Weiss');
      expect(
        BillingParty.fromJson({'subject_id': 'm2', 'company': 'Lumi'})
            .displayName,
        'Lumi',
      );
      expect(
        BillingParty.fromJson({'subject_id': 'm2', 'capacity': 'x'}).capacity,
        isNull,
      );
    });
  });

  group('the command', () {
    test('an invalid draft is not sent', () async {
      final repo = FakeBillingCustomerRepository();
      final out = await BillingCustomerCommands(repo)
          .create('ws', const BillingPartyDraft());
      expect(out, isA<BillingInvalid>());
      expect(repo.calls, isEmpty);
    });

    test('create then edit at the revision read; a stale one is refused and '
        'writes nothing', () async {
      final repo = FakeBillingCustomerRepository();
      final commands = BillingCustomerCommands(repo);
      final created = await commands.create('ws', _lumi, capacity: 'business');
      expect(created, isA<BillingSaved>());
      final read = (await repo.fetch('ws')).single;
      expect(read.revision, 1);
      expect(read.capacity, 'business');
      expect(read.draft.countryCode, 'FR');

      final saved = await commands.save(
        'ws',
        read,
        const BillingPartyDraft(company: 'Atelier Lumi', city: 'Beziers'),
      );
      expect(saved, isA<BillingSaved>());
      final stale = await commands.save(
        'ws',
        read,
        const BillingPartyDraft(company: 'Other', city: 'Nice'),
      );
      expect((stale as BillingRefused).kind, BillingCustomerRefusalKind.stale);
      final now = (await repo.fetch('ws')).single;
      expect(now.revision, 2);
      expect(now.draft.company, 'Atelier Lumi');
    });

    test('no right is a refusal; a lost answer is not claimed saved', () async {
      final repo = FakeBillingCustomerRepository(mayManage: () => false);
      final commands = BillingCustomerCommands(repo);
      expect(
        ((await commands.create('ws', _lumi)) as BillingRefused).kind,
        BillingCustomerRefusalKind.notAllowed,
      );
      final open = FakeBillingCustomerRepository()
        ..failNext = http.ClientException('connection closed');
      expect(
        await BillingCustomerCommands(open).create('ws', _lumi),
        isA<BillingUnreached>(),
      );
      expect(await open.fetch('ws'), isEmpty);
    });
  });

  group('the adapter over the real RPCs', () {
    late List<(String, Map<String, dynamic>)> seen;

    /// The answer as (status, json); postgrest reads the request back off the
    /// response, so the client attaches it.
    SupabaseBillingCustomerRepository repo(
      (int, Object?) Function(String rpc, Map<String, dynamic> body) answer,
    ) {
      seen = [];
      final client = SupabaseClient(
        'http://127.0.0.1:54321',
        'anon',
        httpClient: MockClient((request) async {
          final rpc = request.url.pathSegments.last;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          seen.add((rpc, body));
          final (status, json) = answer(rpc, body);
          return http.Response(
            jsonEncode(json),
            status,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      return SupabaseBillingCustomerRepository(client);
    }

    (int, Object?) refused(String code) =>
        (400, {'code': code, 'message': 'refused', 'details': null});

    test('list, create and edit call the 0821 functions with their own '
        'argument names; the capacity is sent only when stated', () async {
      final r = repo((rpc, body) {
        return switch (rpc) {
          'billing_customers_v1' => (
            200,
            [
              {
                'subject_id': 's1',
                'revision': 2,
                'company': 'Lumi',
                'status': 'customer',
              },
            ],
          ),
          'billing_customer_create_v1' => (200, 's2'),
          _ => (200, {'subject_id': 's1', 'revision': 3, 'company': 'Lumi2'}),
        };
      });
      expect((await r.fetch('ws-1')).single.revision, 2);
      expect(seen.last.$2, {'p_workspace': 'ws-1'});

      expect(await r.create('ws-1', _lumi), 's2');
      expect(seen.last.$2.keys, unorderedEquals(['p_workspace', 'p_party']));
      expect((seen.last.$2['p_party'] as Map)['country_code'], 'FR');
      await r.create('ws-1', _lumi, capacity: 'business');
      expect(seen.last.$2['p_capacity'], 'business');

      final saved = await r.save(
        'ws-1',
        's1',
        _lumi,
        expectedRevision: 2,
        capacity: 'consumer',
      );
      expect(saved.revision, 3);
      expect(seen.last.$1, 'billing_party_save_v1');
      expect(seen.last.$2['p_subject'], 's1');
      expect(seen.last.$2['p_expected_revision'], 2);
      expect(seen.last.$2['p_capacity'], 'consumer');
    });

    test('the server codes become typed refusals; any other error passes '
        'through untouched', () async {
      Future<BillingCustomerRefusalKind?> kindOf(String code) async {
        final r = repo((_, _) => refused(code));
        try {
          await r.save('ws', 's', _lumi, expectedRevision: 1);
        } on BillingCustomerRefusal catch (e) {
          return e.kind;
        } on PostgrestException {
          return null;
        }
        fail('no refusal');
      }

      expect(await kindOf(DkCode.dkn01), BillingCustomerRefusalKind.notAllowed);
      expect(await kindOf(DkCode.dku02), BillingCustomerRefusalKind.notAllowed);
      expect(await kindOf(DkCode.dku05), BillingCustomerRefusalKind.stale);
      expect(await kindOf(DkCode.dku04), BillingCustomerRefusalKind.unknownCustomer);
      expect(await kindOf(DkCode.dku03), BillingCustomerRefusalKind.nameNeeded);
      expect(
        await kindOf(PgCode.undefinedFunction),
        isNull,
        reason: 'an older host: no function',
      );
    });
  });
}
