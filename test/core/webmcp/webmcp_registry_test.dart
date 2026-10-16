// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2504 — the WebMCP tools are the MCP contract and are offered only while
// signed in, in a workspace with the feature, with the device switch on, in a
// browser that has a modelContext; every lifecycle change withdraws them and
// a late answer of a previous workspace is never delivered.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/mcp/mcp_operations.dart';
import 'package:deskilo/core/webmcp/webmcp_context_stub.dart';
import 'package:deskilo/core/webmcp/webmcp_registry.dart';
import 'package:deskilo/core/webmcp/webmcp_tools.g.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRegistration implements WebMcpRegistration {
  _FakeRegistration(this.onUnregister);
  final void Function() onUnregister;
  @override
  void unregister() => onUnregister();
}

class _FakeContext implements WebMcpContext {
  _FakeContext({this.available = true});
  @override
  bool available;
  final Map<String, WebMcpExecute> live = {};

  @override
  WebMcpRegistration register({
    required String name,
    required String description,
    required String inputSchemaJson,
    required Map<String, Object?> annotations,
    required WebMcpExecute execute,
  }) {
    live[name] = execute;
    return _FakeRegistration(() => live.remove(name));
  }
}

const _on = WebMcpConditions(
  accountId: 'a1',
  workspaceId: 'w1',
  featureEnabled: true,
  deviceSwitchOn: true,
  enabledFeatureKeys: {'mcpAccess'},
);

WebMcpRegistry _registry(_FakeContext context, [WebMcpToolRunner? runner]) =>
    WebMcpRegistry(
      context: context,
      runner: runner ?? (tool, input, _) async => {'ok': true, 'tool': tool.name},
    );

void main() {
  test('the generated tools are the contract: name, description, schema, no forbidden input', () {
    final contract = jsonDecode(File('contracts/mcp/operations.json').readAsStringSync()) as Map;
    final ops = [
      for (final o in contract['operations'] as List)
        if ((o as Map)['handler'] == true) o,
    ];
    expect(webMcpTools.map((t) => t.id), ops.map((o) => o['id']));
    final published = (jsonDecode(File('contracts/mcp/generated/tools.json').readAsStringSync())
        as Map)['tools'] as List;
    for (var i = 0; i < ops.length; i++) {
      final tool = webMcpTools[i];
      expect(tool.name, 'deskilo_${ops[i]['id']}');
      expect(tool.description, ops[i]['description']);
      expect(tool.mutation, ops[i]['mutation']);
      expect(tool.confirmation, ops[i]['confirmation']);
      expect(tool.scope, ops[i]['scope']);
      expect(tool.features, ops[i]['features']);
      expect(jsonDecode(tool.inputSchema), (published[i] as Map)['inputSchema']);
      final properties = ((jsonDecode(tool.inputSchema) as Map)['properties'] as Map).keys;
      expect(properties.toSet().intersection(mcpForbiddenInputs), isEmpty, reason: tool.id);
    }
  });

  test('registers every contract tool whose features are enabled, and nothing otherwise', () {
    final context = _FakeContext();
    final registry = _registry(context)
      ..update(WebMcpConditions(
        accountId: 'a1',
        workspaceId: 'w1',
        featureEnabled: true,
        deviceSwitchOn: true,
        enabledFeatureKeys: {for (final t in webMcpTools) ...t.features},
      ));
    expect(registry.registeredNames, webMcpTools.map((t) => t.name).toList());

    registry.update(const WebMcpConditions(
      accountId: 'a1',
      workspaceId: 'w1',
      featureEnabled: true,
      deviceSwitchOn: true,
    ));
    expect(registry.registeredNames,
        [for (final t in webMcpTools) if (t.features.isEmpty) t.name]);
  });

  for (final entry in <String, WebMcpConditions>{
    'signed out': const WebMcpConditions(
        workspaceId: 'w1', featureEnabled: true, deviceSwitchOn: true),
    'no workspace': const WebMcpConditions(
        accountId: 'a1', featureEnabled: true, deviceSwitchOn: true),
    'feature off': const WebMcpConditions(
        accountId: 'a1', workspaceId: 'w1', deviceSwitchOn: true),
    'switch off': const WebMcpConditions(
        accountId: 'a1', workspaceId: 'w1', featureEnabled: true),
  }.entries) {
    test('nothing is registered when ${entry.key}', () {
      final context = _FakeContext();
      final registry = _registry(context)..update(entry.value);
      expect(context.live, isEmpty);
      expect(registry.registeredNames, isEmpty);
    });
  }

  test('each lifecycle event withdraws every tool', () {
    for (final next in <WebMcpConditions>[
      const WebMcpConditions(),
      const WebMcpConditions(
          accountId: 'a2', workspaceId: 'w1', featureEnabled: true, deviceSwitchOn: true),
      const WebMcpConditions(
          accountId: 'a1', workspaceId: 'w2', featureEnabled: true, deviceSwitchOn: true),
      const WebMcpConditions(accountId: 'a1', workspaceId: 'w1', deviceSwitchOn: true),
      const WebMcpConditions(accountId: 'a1', workspaceId: 'w1', featureEnabled: true),
    ]) {
      final context = _FakeContext();
      final registry = _registry(context)..update(_on);
      expect(context.live, isNotEmpty);
      registry.update(next);
      // A new account or workspace is registered afresh, never kept.
      expect(context.live.length, next.armed ? greaterThan(0) : 0);
      registry.dispose();
      expect(context.live, isEmpty);
    }
  });

  test('a browser without WebMCP registers nothing', () {
    final context = _FakeContext(available: false);
    final registry = _registry(context)..update(_on);
    expect(context.live, isEmpty);
    expect(registry.registeredNames, isEmpty);
  });

  test('a build that is not the web app has no context to register with', () {
    final context = browserWebMcpContext();
    expect(context.available, isFalse);
    final registry = _registry(_FakeContext(available: false))..update(_on);
    expect(registry.registeredNames, isEmpty);
  });

  test('a call with a forbidden input, or another workspace, is refused before running', () async {
    var ran = 0;
    final context = _FakeContext();
    _registry(context, (_, _, _) async {
      ran++;
      return {'ok': true};
    }).update(_on);
    final call = context.live['deskilo_get_capabilities']!;
    expect(await call({'workspace_id': 'w1', 'role': 'admin'}),
        containsPair('ok', false));
    expect(await call({'workspace_id': 'w2'}), containsPair('ok', false));
    expect(ran, 0);
    expect(await call({'workspace_id': 'w1'}), containsPair('ok', true));
    expect(ran, 1);
  });

  test('a late answer of the previous workspace is dropped, never returned as the new one', () async {
    final release = Completer<void>();
    final context = _FakeContext();
    final registry = _registry(context, (tool, input, _) async {
      await release.future;
      return {'ok': true, 'workspace': 'w1'};
    })..update(_on);
    final pending = context.live['deskilo_get_capabilities']!({'workspace_id': 'w1'});
    registry.update(const WebMcpConditions(
        accountId: 'a1', workspaceId: 'w2', featureEnabled: true, deviceSwitchOn: true, enabledFeatureKeys: {'mcpAccess'}));
    release.complete();
    final answer = await pending as Map;
    expect(answer['ok'], false);
    expect((answer['error'] as Map)['code'], 'context_changed');
  });

  test('a call to a tool that has been withdrawn is refused', () async {
    final context = _FakeContext();
    final registry = _registry(context)..update(_on);
    final call = context.live['deskilo_get_capabilities']!;
    registry.update(const WebMcpConditions());
    expect((await call({}) as Map)['ok'], false);
  });
}
