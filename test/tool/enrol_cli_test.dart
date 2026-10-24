// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2562 C2a — the operator's enrol command. The facts recorded at the home
// are read from the workspace project, a dry run writes nothing, --apply
// calls the home's operator function once, a candidate that hosts no
// workspace, a home that is no personal home and the home itself are
// refused before any write, the database's own refusal is exit 1, and no
// key reaches the output.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/instance/management_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/instance/enrol.dart';
import '../helpers/fake_supabase_management.dart';

class _Out implements IOSink {
  final text = StringBuffer();
  @override
  void writeln([Object? obj = '']) => text.writeln(obj);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const homeId = '00000000-0000-4000-8000-0000002562b0';
const workspaceId = '00000000-0000-4000-8000-0000002562b1';

String _descriptor(List<String> roles) => jsonEncode({
  'roles': roles,
  'role_capabilities': [
    if (roles.contains('personal_home')) 'personal@1',
    if (roles.contains('workspace_host')) 'workspace@1',
  ],
});

FakeSupabaseManagement fake({
  List<String> workspaceRoles = const ['workspace_host'],
  List<String> homeRoles = const ['personal_home'],
  String workspaceInstallation = workspaceId,
  String? refuse,
}) {
  final api = FakeSupabaseManagement()
    ..onQuery = (ref, sql) {
      if (sql.contains('public_network_descriptor()')) {
        final home = ref == 'home';
        return [
          {
            'id': home ? homeId : workspaceInstallation,
            'descriptor': _descriptor(home ? homeRoles : workspaceRoles),
          },
        ];
      }
      if (sql.contains('operator_enrolled_installations()')) {
        return [
          {
            'id': workspaceId,
            'origin': 'https://wsp.supabase.co',
            'accepting': true,
            'enabled': true,
          },
          {
            'id': homeId.replaceAll('b0', 'b9'),
            'origin': 'https://old.supabase.co',
            'accepting': false,
            'enabled': false,
          },
        ];
      }
      if (sql.contains('operator_')) {
        if (refuse != null) throw ManagementApiException(400, refuse);
        final status = sql.contains('operator_revoke') ? 'revoked' : 'enrolled';
        return [
          {
            'result':
                '{"installation_id": "$workspaceId", "status": "$status", "unchanged": false}',
          },
        ];
      }
      return const [];
    };
  return api;
}

List<String> writes(FakeSupabaseManagement api) => [
  for (final s in api.queriedSql)
    if (s.contains('operator_enrol_installation(') ||
        s.contains('operator_revoke_installation('))
      s,
];

void main() {
  test('a dry run reads both projects, names the plan and writes nothing', () async {
    final api = fake();
    final out = _Out();
    final code = await runEnrol(
      api,
      ref: 'home',
      action: 'add',
      workspaceRef: 'wsp',
      out: out,
    );
    expect(code, 0);
    expect(writes(api), isEmpty);
    expect(
      out.text.toString(),
      contains(
        'dry run: would enrol installation $workspaceId (https://wsp.supabase.co',
      ),
    );
  });

  test('--apply enrols once, with the facts read from the workspace project', () async {
    final api = fake();
    final out = _Out();
    final code = await runEnrol(
      api,
      ref: 'home',
      action: 'add',
      workspaceRef: 'wsp',
      accepting: false,
      apply: true,
      out: out,
    );
    expect(code, 0);
    final call = writes(api).single;
    expect(
      call,
      contains(
        "operator_enrol_installation('$workspaceId'::uuid, "
        "'https://wsp.supabase.co', 'sb_publishable_wsp_key', "
        "array['workspace_host']::text[], array['workspace@1']::text[], false)",
      ),
    );
    expect(
      out.text.toString(),
      contains('not accepting new workspaces: enrolled'),
    );
    expect(out.text.toString(), isNot(contains('sb_publishable')));
  });

  test(
    'a candidate that hosts no workspace is refused before any write',
    () async {
      final api = fake(workspaceRoles: const ['personal_home']);
      final out = _Out();
      final code = await runEnrol(
        api,
        ref: 'home',
        action: 'add',
        workspaceRef: 'wsp',
        apply: true,
        out: out,
      );
      expect(code, 1);
      expect(writes(api), isEmpty);
      expect(
        out.text.toString(),
        contains('refused: wsp does not host workspaces'),
      );
    },
  );

  test('a home that is no personal home is refused before any write', () async {
    final api = fake(homeRoles: const ['workspace_host']);
    final out = _Out();
    final code = await runEnrol(
      api,
      ref: 'home',
      action: 'add',
      workspaceRef: 'wsp',
      apply: true,
      out: out,
    );
    expect(code, 1);
    expect(writes(api), isEmpty);
    expect(out.text.toString(), contains('home is not a personal home'));
  });

  test('the home never enrols itself', () async {
    final api = fake(workspaceInstallation: homeId);
    final out = _Out();
    final code = await runEnrol(
      api,
      ref: 'home',
      action: 'add',
      workspaceRef: 'wsp',
      apply: true,
      out: out,
    );
    expect(code, 1);
    expect(writes(api), isEmpty);
    expect(
      out.text.toString(),
      contains('an installation does not enrol itself'),
    );
  });

  test("the database's refusal is exit 1 and named", () async {
    final api = fake(
      refuse: 'the origin https://wsp.supabase.co is already enrolled',
    );
    final out = _Out();
    final code = await runEnrol(
      api,
      ref: 'home',
      action: 'add',
      workspaceRef: 'wsp',
      apply: true,
      out: out,
    );
    expect(code, 1);
    expect(
      out.text.toString(),
      contains('refused by the database: the origin'),
    );
  });

  test('revoke needs an installation id; a dry run writes nothing; --apply revokes', () async {
    final api = fake();
    final out = _Out();
    expect(
      await runEnrol(
        api,
        ref: 'home',
        action: 'revoke',
        installation: 'nope',
        out: out,
      ),
      2,
    );
    expect(
      await runEnrol(
        api,
        ref: 'home',
        action: 'revoke',
        installation: workspaceId,
        out: out,
      ),
      0,
    );
    expect(writes(api), isEmpty);
    expect(
      await runEnrol(
        api,
        ref: 'home',
        action: 'revoke',
        installation: workspaceId,
        apply: true,
        out: out,
      ),
      0,
    );
    expect(
      writes(api).single,
      contains("operator_revoke_installation('$workspaceId'::uuid)"),
    );
    expect(
      out.text.toString(),
      contains(
        'revoke the enrolment of installation $workspaceId at home: revoked',
      ),
    );
  });

  test(
    'list names every enrolment, revoked ones too; an unknown action is exit 2',
    () async {
      final api = fake();
      final out = _Out();
      expect(await runEnrol(api, ref: 'home', action: 'list', out: out), 0);
      expect(out.text.toString(), contains('home: 2 enrolled installation(s)'));
      expect(
        out.text.toString(),
        contains('https://wsp.supabase.co  accepting new workspaces'),
      );
      expect(out.text.toString(), contains('https://old.supabase.co  revoked'));
      expect(await runEnrol(api, ref: 'home', action: 'drop', out: out), 2);
      expect(await runEnrol(api, ref: 'home', action: 'add', out: out), 2);
    },
  );
}
