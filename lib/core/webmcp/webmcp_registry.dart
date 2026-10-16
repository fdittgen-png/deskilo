// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2504 — decides which contract tools the page offers to an in-browser
// agent, and withdraws them the moment the reason to offer them is gone.
//
// Registered only while ALL of these hold: the browser has a modelContext
// (so: a web build), a person is signed in, `WorkspaceFeature.webMcp` is
// effective for the workspace and the per-device switch is on. A tool that
// names features is registered only when each of them is enabled. Any
// change of account or workspace withdraws every tool first (one person,
// one server), and a call that was started under the previous context never
// delivers its late answer under the new one.
import '../mcp/mcp_operations.dart' show mcpForbiddenInputs;
import 'webmcp_context_base.dart';
import 'webmcp_tool_spec.dart';
import 'webmcp_tools.g.dart';

export 'webmcp_context_base.dart';

/// What decides the registration, as the app currently knows it.
class WebMcpConditions {
  const WebMcpConditions({
    this.accountId,
    this.workspaceId,
    this.featureEnabled = false,
    this.deviceSwitchOn = false,
    this.enabledFeatureKeys = const {},
  });

  /// The signed-in person, or null when signed out.
  final String? accountId;

  /// The active workspace, or null when none.
  final String? workspaceId;

  /// `WorkspaceFeature.webMcp` is effective for the workspace.
  final bool featureEnabled;

  /// The per-device switch in Me > Account.
  final bool deviceSwitchOn;

  /// Keys of the workspace features that are effective.
  final Set<String> enabledFeatureKeys;

  bool get armed => accountId != null && workspaceId != null && featureEnabled && deviceSwitchOn;

  /// The identity a registration belongs to; a change of it is a new epoch.
  String get scopeKey => '$accountId|$workspaceId';
}

/// Runs a tool under the context it was registered for. The result is the
/// contract's answer (status and output), already shaped for the agent.
typedef WebMcpToolRunner = Future<Object?> Function(
  WebMcpToolSpec tool,
  Map<String, Object?> input,
  WebMcpConditions context,
);

/// The refusal an agent gets when a call cannot run; same shape everywhere.
Map<String, Object?> _refusal(String code, String message) => {
      'ok': false,
      'error': {'code': code, 'message': message},
    };

class WebMcpRegistry {
  WebMcpRegistry({
    required this.context,
    required this.runner,
    this.tools = webMcpTools,
  });

  final WebMcpContext context;
  final WebMcpToolRunner runner;
  final List<WebMcpToolSpec> tools;
  final Map<String, WebMcpRegistration> _registered = {};
  WebMcpConditions _current = const WebMcpConditions();
  String? _registeredScope;

  /// Names of the tools currently offered, in contract order.
  List<String> get registeredNames => [
        for (final t in tools)
          if (_registered.containsKey(t.name)) t.name,
      ];

  /// Brings the registration in line with [conditions].
  void update(WebMcpConditions conditions) {
    final scopeChanged = _registeredScope != null && _registeredScope != conditions.scopeKey;
    _current = conditions;
    if (!conditions.armed || !context.available || scopeChanged) {
      _withdraw();
    }
    if (!conditions.armed || !context.available) return;
    _registeredScope = conditions.scopeKey;
    for (final tool in tools) {
      final wanted = tool.features.every(conditions.enabledFeatureKeys.contains);
      final present = _registered.containsKey(tool.name);
      if (wanted && !present) {
        _registered[tool.name] = context.register(
          name: tool.name,
          description: tool.description,
          inputSchemaJson: tool.inputSchema,
          annotations: {
            'title': tool.title,
            'readOnlyHint': tool.readOnly,
            if (!tool.readOnly) 'destructiveHint': tool.destructive,
            'openWorldHint': false,
          },
          execute: (input) => _call(tool, input, conditions.scopeKey),
        );
      } else if (!wanted && present) {
        _registered.remove(tool.name)!.unregister();
      }
    }
  }

  /// Withdraws everything (sign-out, dispose).
  void dispose() {
    _current = const WebMcpConditions();
    _withdraw();
  }

  void _withdraw() {
    final all = _registered.values.toList();
    _registered.clear();
    _registeredScope = null;
    for (final r in all) {
      r.unregister();
    }
  }

  Future<Object?> _call(WebMcpToolSpec tool, Map<String, Object?> input, String scopeKey) async {
    final now = _current;
    if (!_registered.containsKey(tool.name) || now.scopeKey != scopeKey || !now.armed) {
      return _refusal('unavailable', 'This tool is no longer offered.');
    }
    for (final name in input.keys) {
      if (mcpForbiddenInputs.contains(name)) {
        return _refusal('validation_error', 'The input "$name" is not allowed.');
      }
    }
    final target = input['workspace_id'];
    if (target != null && target != now.workspaceId && tool.scope != 'discovery') {
      return _refusal('validation_error', 'workspace_id is not the workspace this page is in.');
    }
    final Object? answer;
    try {
      answer = await runner(tool, input, now);
    } on Object {
      return _refusal('internal_error', 'The tool could not run.');
    }
    // A late answer of the previous account or workspace is dropped.
    if (_current.scopeKey != scopeKey || !_current.armed || !_registered.containsKey(tool.name)) {
      return _refusal('context_changed', 'The workspace changed while the tool was running.');
    }
    return answer;
  }
}
