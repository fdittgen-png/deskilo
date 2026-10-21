// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2504 — where the page's WebMCP registry meets the app: the conditions it
// registers under (who is signed in, which workspace, its features, the
// device switch) and the read tools it can answer. A tool is offered only
// when a runner here answers it; the rest of the contract waits for its
// runner (reads, then the writes with the in-app confirmation).
//
// A runner reads what the app's own screens read, through the same
// providers and repositories, never the MCP facade. Its answer carries only
// the fields the contract's `output` lists for the operation.

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/trace/trace_logger.dart';
import '../core/webmcp/webmcp_context.dart';
import '../core/webmcp/webmcp_device_switch.dart';
import '../core/webmcp/webmcp_registry.dart';
import '../core/webmcp/webmcp_tool_spec.dart';
import '../core/webmcp/webmcp_tools.g.dart';
import '../features/workspace/domain/workspace_feature.dart';
import '../features/workspace/providers/workspace_providers.dart';
import 'webmcp_reads.dart';
import 'webmcp_writes.dart';

/// What decides whether the page offers tools, as the app knows it now.
final _conditionsProvider = Provider<WebMcpConditions>((ref) {
  final features = ref.watch(enabledFeaturesSyncProvider);
  return WebMcpConditions(
    accountId: ref.watch(currentAccountIdProvider),
    workspaceId: ref.watch(currentWorkspaceProvider).value?.id,
    featureEnabled: features.contains(WorkspaceFeature.webMcp),
    deviceSwitchOn: ref.watch(webMcpDeviceSwitchProvider).value ?? false,
    enabledFeatureKeys: {for (final f in features) f.dbKey},
  );
});

/// The browser's `modelContext` (a stand-in that offers nothing outside
/// the web build).
@visibleForTesting
final webMcpContextProvider = Provider<WebMcpContext>(
  (ref) => browserWebMcpContext(),
);

/// The page's registry, kept in line with [_conditionsProvider]: the
/// shell watches it, so it lives as long as the signed-in app does.
final webMcpRegistryProvider = Provider<WebMcpRegistry>((ref) {
  late final WebMcpRegistry registry;
  registry = WebMcpRegistry(
    context: ref.watch(webMcpContextProvider),
    runner: (tool, input, conditions) => _run(
      ref,
      tool,
      input,
      conditions,
      offered: () => registry.registeredNames,
    ),
    tools: [
      for (final tool in webMcpTools)
        if (webMcpReadRunners.containsKey(tool.id) ||
            webMcpWriteRunners.containsKey(tool.id))
          tool,
    ],
  );
  ref
    ..onDispose(registry.dispose)
    ..listen(
      _conditionsProvider,
      (_, next) => registry.update(next),
      fireImmediately: true,
    );
  return registry;
});

/// What an assistant in this browser just did through the page (the
/// operation id); the shell says it so the page and the agent stay in step.
class WebMcpActivity extends Notifier<String?> {
  @override
  String? build() => null;

  void acted(String operation) => state = operation;
}

final webMcpActivityProvider = NotifierProvider<WebMcpActivity, String?>(
  WebMcpActivity.new,
);

/// Runs [tool] and wraps its answer as the MCP facade does: a status, the
/// operation, the workspace and its output; or the refusal it ran into.
Future<Object?> _run(
  Ref ref,
  WebMcpToolSpec tool,
  Map<String, Object?> input,
  WebMcpConditions conditions, {
  required List<String> Function() offered,
}) async {
  final read = webMcpReadRunners[tool.id];
  final write = webMcpWriteRunners[tool.id];
  if (read == null && write == null) {
    return _refusal('unavailable', 'This tool is not offered here.');
  }
  try {
    final output = read != null
        ? await read(ref, input, conditions, offered)
        : await ref
              .read(webMcpIntentsProvider)
              .once(conditions.scopeKey, input, () => write!(ref, input));
    if (write != null) ref.read(webMcpActivityProvider.notifier).acted(tool.id);
    return {
      'ok': true,
      'status': 'completed',
      'operation': tool.id,
      if (tool.scope != 'discovery') 'workspace_id': conditions.workspaceId,
      if (write != null) 'request_id': input['request_id'],
      'output': output,
    };
  } on WebMcpRefused catch (r, st) {
    TraceLogger.instance.warn(
      'webmcp',
      '${tool.id} refused: ${r.code}',
      stackTrace: st,
    );
    return _refusal(r.code, r.message);
  }
}

Map<String, Object?> _refusal(String code, String message) => {
  'ok': false,
  'error': {'code': code, 'message': message},
};
