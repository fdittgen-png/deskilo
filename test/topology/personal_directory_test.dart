// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2472 C2 -- the new discussion's directory across three projects: the
// production reader (`personalDirectoryControllerProvider` over
// `SupabasePersonalMessageDirectoryRepository`) asks
// `my_personal_message_directory_v1` at P, a stack that holds no workspace
// or member row, over requests signed by P's own Auth.
//
// The seed (scripts/topology_stacks.sh) gives P three accounts and the
// membership facts the facts flow (#2563 C2: 0569, 0574, 0575) stores for
// them: A and B are co-members of the workspace at W-A; A and C of the
// workspace with the SAME local id at W-B. W-A and W-B are enrolled at P
// under their real installation ids, so the two network references differ
// though the workspace uuid is equal. A is in one group that has no
// message. The facts are seeded in the shape membership_fact_apply stores
// (274 does the same; 273 proves the apply and its signed inbox).
//
//   * A sees B under W-A and C under W-B; B is absent at W-B, and B asking
//     for W-B is refused, not answered empty.
//   * A blocks B at P: each disappears from the other's directory; the
//     unblock brings them back.
//   * W-B offline: P still answers while its facts hold; once they lapse
//     (W-B stopped re-asserting them) the directory says partial, W-B's
//     people read unavailable, W-A and the group stay; with every W down
//     the group is still listed. Never an error for the whole directory.
//
// It stops gateways, so it runs in the fault call of the database job,
// one file at a time. The identities are independently seeded plumbing
// users, NOT the one-registration proof (#2562).
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/backend/auth_secret_store.dart';
import 'package:deskilo/core/backend/connected_installation_providers.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:deskilo/core/backend/context_client_providers.dart';
import 'package:deskilo/core/backend/context_clients.dart';
import 'package:deskilo/core/session/session_source.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/directory/domain/personal_message_directory.dart';
import 'package:deskilo/features/directory/providers/messenger_providers.dart';
import 'package:deskilo/features/directory/providers/personal_directory_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

final _file = Platform.environment['DESKILO_TOPOLOGY_FILE'];
const _limit = Timeout(Duration(minutes: 4));

/// Runs one operation of the harness, or fails with its output.
Future<void> _harness(List<String> args) async {
  final r = await Process.run('bash', ['scripts/topology_stacks.sh', ...args]);
  expect(r.exitCode, 0, reason: '${args.join(' ')}\n${r.stdout}\n${r.stderr}');
}

/// One account of P, signed in on a client of its own.
class _Person {
  _Person(this.id, this.client);
  final String id;
  final SupabaseClient client;
  late final ProviderContainer app = ProviderContainer(
    overrides: [
      sessionStateProvider.overrideWith((ref) => Stream.value(id)),
      authStateProvider.overrideWith((ref) => Stream.value(id)),
      contextClientsProvider.overrideWithValue(ContextClients(client)),
      connectedInstallationsProvider.overrideWithValue(
        ConnectedInstallations(client, const PlatformAuthSecretStore()),
      ),
    ],
  );

  PersonalMessageDirectoryRepository get reader =>
      app.read(personalMessageDirectoryRepositoryProvider);

  /// The whole directory as the new discussion loads it, read afresh.
  Future<PersonalDirectory> directory() async {
    final sub = app.listen(personalDirectoryControllerProvider, (_, _) {});
    try {
      app.invalidate(personalDirectoryControllerProvider);
      return await app
          .read(personalDirectoryControllerProvider.future)
          .timeout(const Duration(seconds: 30));
    } finally {
      sub.close();
    }
  }

  Future<List<String>> people(String ref) async => [
    for (final x in (await reader.people(ref)).items) x.id,
  ];
}

void main() {
  if (_file == null) {
    test(
      'the directory across projects',
      () {},
      skip: 'needs the three stacks of the database job; set DESKILO_TOPOLOGY_FILE',
    );
    return;
  }
  late Map<String, dynamic> dir;
  late String pUrl;
  late String wbUrl;
  late SupabaseClient readback;
  late String waRef;
  late String wbRef;
  late String group;
  late _Person a;
  late _Person b;
  late _Person c;

  Future<_Person> person(String name, String anon, String password) async {
    final who = dir[name] as Map<String, dynamic>;
    final client = SupabaseClient(
      pUrl,
      anon,
      httpClient: http.Client(),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final s = await client.auth.signInWithPassword(
      email: who['email'] as String,
      password: password,
    );
    expect(s.user?.id, who['id'], reason: 'P signed in as $name');
    return _Person(who['id'] as String, client);
  }

  Future<void> expectNoWorkspaceRowsAtP() async {
    for (final table in ['workspaces', 'members']) {
      expect(
        await readback.from(table).select('id'),
        isEmpty,
        reason: 'P holds no $table: the directory reads facts, never copies',
      );
    }
  }

  setUpAll(() async {
    // flutter_test replaces the HTTP client with one that answers 400.
    HttpOverrides.global = null;
    final d =
        jsonDecode(File(_file!).readAsStringSync()) as Map<String, dynamic>;
    final pj = d['p'] as Map<String, dynamic>;
    final password = d['password'] as String;
    dir = pj['directory'] as Map<String, dynamic>;
    pUrl = pj['url'] as String;
    wbUrl = (d['wb'] as Map<String, dynamic>)['url'] as String;
    readback = SupabaseClient(pUrl, pj['service'] as String);
    waRef = dir['waRef'] as String;
    wbRef = dir['wbRef'] as String;
    group = dir['groupId'] as String;
    // A fault or a lapse a crashed earlier run left behind is lifted first.
    await _harness(['fault', 'restore', 'all']);
    await _harness(['facts', 'fresh', 'w']);
    final anon = pj['anon'] as String;
    a = await person('a', anon, password);
    b = await person('b', anon, password);
    c = await person('c', anon, password);
  });

  tearDownAll(() async {
    for (final x in [a, b, c]) {
      x.app.dispose();
    }
    await _harness(['fault', 'restore', 'all']);
    await _harness(['facts', 'fresh', 'w']);
  });

  test(
    'A and B, co-members at W-A, list each other there; B is absent at W-B, '
    'where A lists C; the equal workspace id is two references; every '
    'person is an account of P, and P holds no workspace row',
    timeout: _limit,
    () async {
      expect(waRef, isNot(wbRef));
      expect(waRef.split(':').last, wbRef.split(':').last);
      await expectNoWorkspaceRowsAtP();

      final mine = await a.directory();
      expect(mine.status, RelationshipStatus.ready);
      expect(mine.workspaces.map((w) => w.networkId).toSet(), {waRef, wbRef});
      expect(mine.people[waRef]!.items.map((x) => x.id), [b.id]);
      expect(mine.people[wbRef]!.items.map((x) => x.id), [c.id]);
      expect(
        mine.people[waRef]!.items.single.workspaceRef,
        waRef,
        reason: 'the person is offered in the workspace that relates us',
      );
      expect(mine.groups.map((g) => g.id), [group]);
      expect(mine.groups.single.canWrite, isTrue);

      // From B's side: A under W-A; W-B is no workspace of B's, refused.
      expect(await b.people(waRef), [a.id]);
      await expectLater(
        b.reader.people(wbRef),
        throwsA(
          isA<DirectoryRefused>().having(
            (e) => e.failure,
            'failure',
            DirectoryFailure.forbidden,
          ),
        ),
      );
      final ofB = await b.directory();
      expect(ofB.workspaces.map((w) => w.networkId), [waRef]);
      expect(ofB.groups, isEmpty, reason: 'B is in no group');

      // The ids are P's own accounts, and P still copied nothing.
      for (final id in [a.id, b.id, c.id]) {
        final users = await readback.auth.admin.getUserById(id);
        expect(users.user?.id, id);
      }
      await expectNoWorkspaceRowsAtP();
    },
  );

  test(
    'a block at P hides B from A and A from B; the unblock brings them back',
    timeout: _limit,
    () async {
      expect(await a.people(waRef), [b.id], reason: 'positive control');
      final actions = a.app.read(messengerActionsProvider());
      await actions.blockAccount(b.id);
      var blocked = true;
      addTearDown(() async {
        if (blocked) await actions.unblockAccount(b.id);
      });

      expect(await a.people(waRef), isEmpty, reason: 'A no longer lists B');
      expect(await b.people(waRef), isEmpty, reason: 'nor B lists A');
      expect(await a.people(wbRef), [
        c.id,
      ], reason: 'the block is about B, not the workspace');

      await actions.unblockAccount(b.id);
      blocked = false;
      expect(await a.people(waRef), [b.id]);
      expect(await b.people(waRef), [a.id]);
    },
  );

  test(
    'W-B offline: P answers while its facts hold; once they lapse the '
    'directory is partial, W-B\'s people are unavailable, W-A and the group '
    'stay; with every W down the group is still listed',
    timeout: _limit,
    () async {
      addTearDown(() async {
        await _harness(['fault', 'restore', 'all']);
        await _harness(['facts', 'fresh', 'w']);
      });
      await _harness(['fault', 'block', 'wb']);
      // The block is physical: W-B's gateway refuses a direct request.
      Object? refused;
      try {
        await http.get(Uri.parse('$wbUrl/rest/v1/'));
      } on Object catch (e) {
        refused = e;
      }
      expect(refused, isNotNull, reason: 'W-B is blocked');

      // P never asks W-B for the directory: its facts still hold.
      final held = await a.directory();
      expect(held.status, RelationshipStatus.ready);
      expect(held.people[wbRef]!.items.map((x) => x.id), [c.id]);

      // W-B stopped re-asserting; the deadline of its facts passed.
      await _harness(['facts', 'lapse', 'wb']);
      final partial = await a.directory();
      expect(partial.status, RelationshipStatus.partial);
      expect(partial.workspaces.map((w) => w.networkId), [waRef]);
      expect(partial.people[waRef]!.items.map((x) => x.id), [b.id]);
      expect(partial.groups.map((g) => g.id), [group]);
      final atWb = await a.reader.people(wbRef);
      expect(atWb.status, RelationshipStatus.unavailable);
      expect(atWb.items, isEmpty, reason: 'unavailable, not somebody else');

      // Every W down: the groups never depended on one.
      await _harness(['fault', 'block', 'w']);
      final groupsOnly = await a.directory();
      expect(groupsOnly.groups.map((g) => g.id), [group]);
      expect(groupsOnly.status, isNot(RelationshipStatus.ready));
      await expectNoWorkspaceRowsAtP();
    },
  );
}
