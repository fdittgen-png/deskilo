// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Non-web half of the WebMCP seam (#2504): there is no browser agent on a
// native build, so nothing is ever registered.
import 'webmcp_context_base.dart';

/// The context of a build that is not the web app.
WebMcpContext browserWebMcpContext() => const _NoWebMcpContext();

class _NoWebMcpContext implements WebMcpContext {
  const _NoWebMcpContext();

  @override
  bool get available => false;

  @override
  WebMcpRegistration register({
    required String name,
    required String description,
    required String inputSchemaJson,
    required Map<String, Object?> annotations,
    required WebMcpExecute execute,
  }) =>
      throw UnsupportedError('WebMCP exists only in the web app');
}
