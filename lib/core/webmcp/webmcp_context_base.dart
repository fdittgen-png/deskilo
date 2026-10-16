// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2504 — what the registry needs from a browser, and nothing else.

/// Runs one tool call and answers with a JSON-encodable value.
typedef WebMcpExecute = Future<Object?> Function(Map<String, Object?> input);

/// One tool registered with the browser; [unregister] withdraws it.
abstract class WebMcpRegistration {
  void unregister();
}

/// The browser's `modelContext`, or a stand-in for it.
abstract class WebMcpContext {
  /// False when there is nothing to register with (not a web build, or a
  /// browser without WebMCP).
  bool get available;

  /// Registers one tool. [inputSchemaJson] is the contract's schema text.
  WebMcpRegistration register({
    required String name,
    required String description,
    required String inputSchemaJson,
    required Map<String, Object?> annotations,
    required WebMcpExecute execute,
  });
}
