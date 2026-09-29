// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1633 — the read-only pilot after a controlled activation passes only on
// an answer for the workspace asked about, from this installation's
// catalogue, carrying nothing but classified fields; any other answer
// fails it (and the CLI then switches MCP off — mcp_activation_cli_test).
import 'package:deskilo/core/instance/mcp_pilot.dart';
import 'package:deskilo/core/instance/mcp_readiness.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mcp_target_fixture.dart';

const ws = '00000000-0000-4000-8000-00000000a001';

Map<String, Object?> tools([List<Map<String, Object?>>? list]) => {
  'jsonrpc': '2.0',
  'id': 1,
  'result': {
    'tools':
        list ??
        [
          {
            'name': 'deskilo_get_capabilities',
            'annotations': {'readOnlyHint': true},
          },
          {
            'name': 'deskilo_create_reservation',
            'annotations': {'readOnlyHint': false},
          },
        ],
  },
};

Map<String, Object?> answer({
  Map<String, Object?>? data,
  String workspace = ws,
  bool isError = false,
  String status = 'completed',
}) => {
  'jsonrpc': '2.0',
  'id': 2,
  'result': {
    'isError': isError,
    'structuredContent': {
      'schema_version': 1,
      'operation': mcpPilotOperation,
      'workspace_id': workspace,
      'status': status,
      'data':
          data ??
          {
            'operations': ['get_capabilities'],
            'target_ceiling': 'own',
            'eligible_until': '2026-12-01',
          },
    },
  },
};

Map<String, CheckOutcome> run({Object? list, Object? call}) => {
  for (final c in evaluateMcpPilot(
    catalogue: fixtureCatalogue(),
    workspaceId: ws,
    toolsList: list ?? tools(),
    call: call ?? answer(),
  ))
    c.code: c.outcome,
};

void main() {
  test(
    'positive control: a minimized answer for the asked workspace passes',
    () {
      expect(run().values.toSet(), {CheckOutcome.pass});
    },
  );

  test('a field outside the contract fails minimization, by name only', () {
    final checks = evaluateMcpPilot(
      catalogue: fixtureCatalogue(),
      workspaceId: ws,
      toolsList: tools(),
      call: answer(
        data: {'operations': <String>[], 'email': 'person@deskilo.test'},
      ),
    );
    final c = checks.firstWhere((c) => c.code == 'pilot_output_minimized');
    expect(c.outcome, CheckOutcome.fail);
    expect(c.detail, contains('email'));
    expect(
      c.detail,
      isNot(contains('person@deskilo.test')),
      reason: 'a value never reaches the verdict',
    );
  });

  test('an answer for another workspace fails provenance', () {
    expect(
      run(
        call: answer(workspace: '00000000-0000-4000-8000-00000000a002'),
      )['pilot_provenance'],
      CheckOutcome.fail,
    );
  });

  test('a refused call fails the pilot', () {
    expect(
      run(call: answer(isError: true, status: 'denied'))['pilot_answered'],
      CheckOutcome.fail,
    );
    expect(
      run(
        call: {
          'jsonrpc': '2.0',
          'id': 2,
          'error': {'code': -32603},
        },
      )['pilot_answered'],
      CheckOutcome.fail,
    );
  });

  test('a tool this installation does not know fails the list', () {
    expect(
      run(
        list: tools([
          {
            'name': 'deskilo_export_everything',
            'annotations': {'readOnlyHint': true},
          },
        ]),
      )['pilot_tools_known'],
      CheckOutcome.fail,
    );
  });

  test('a writing tool annotated read-only fails the hints', () {
    expect(
      run(
        list: tools([
          {
            'name': 'deskilo_create_reservation',
            'annotations': {'readOnlyHint': true},
          },
        ]),
      )['pilot_read_only_hints'],
      CheckOutcome.fail,
    );
  });

  test(
    'the pilot operation must be a read in the catalogue it runs against',
    () {
      final writes = fixtureCatalogue();
      (writes['operations']! as Map)['get_capabilities'] = {
        'dispatch': true,
        'mutation': 'write',
        'output': ['operations'],
      };
      final checks = evaluateMcpPilot(
        catalogue: writes,
        workspaceId: ws,
        toolsList: tools(),
        call: answer(),
      );
      expect(
        checks.firstWhere((c) => c.code == 'pilot_operation_read_only').outcome,
        CheckOutcome.fail,
      );
    },
  );

  test('no answer at all is a failure, not a pass', () {
    final checks = evaluateMcpPilot(
      catalogue: fixtureCatalogue(),
      workspaceId: ws,
      toolsList: null,
      call: null,
    );
    expect(checks.where((c) => c.passed).map((c) => c.code), [
      'pilot_operation_read_only',
    ]);
  });
}
