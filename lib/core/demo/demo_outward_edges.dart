// SPDX-License-Identifier: 0BSD
//
// #1377 — the app's outward edges, in a Demo session.
//
// A payment, an invitation, an e-invoice, a webhook: each of those
// travels through a repository, and inside a Demo scope every repository
// is in memory (ADR 0028) — so they cannot leave, and no check is needed
// to stop them. What is left is the handful of edges the app itself owns:
// saving a file to the device, sharing one, sharing text, opening a link.
//
// Those are not "effects that must be refused" either. Saving a PDF a
// visitor asked for is the demo working. What matters is that they are
// SEEN: a session records what it was asked to send outwards, so a test
// can assert that a journey stayed inside the app, and a future journey
// that wants to show a share can show a simulated one.
//
// #1564 added the three that are not the app's own doing: the push
// transport, the push endpoint registry and the schema probe. Each was
// left live because Demo overrode repositories and these are not
// repositories — and each of them talks to a server.
import 'dart:typed_data';

import '../backend/schema_version.dart';
import '../instance/schema_compatibility.dart';
import '../push/push_connector.dart';
import '../push/push_endpoint_repository.dart';
import '../share/file_sharer.dart';

/// Everything a session was asked to send outwards, in order.
class DemoOutwardEdges {
  final List<String> savedFiles = [];
  final List<String> sharedFiles = [];
  final List<String> sharedTexts = [];
  final List<Uri> openedLinks = [];

  /// #1564 — the push pair, which used to be the one edge Demo left
  /// live. The exemption's stated reason was that "the bootstrap never
  /// runs"; it does. `pushBootstrap` gates on `enabledFeatures`, which
  /// inside Demo comes from the fixture — with `pushNotifications` on —
  /// so on a build with a configured transport the shell constructed the
  /// real connector and a `SupabasePushEndpointRepository` over
  /// `Supabase.instance.client`, and the service upserted synthetic
  /// member ids into `push_endpoints`. A refusal from the server is not
  /// isolation.
  final DemoPushConnector push = DemoPushConnector();
  final DemoPushEndpoints pushEndpoints = DemoPushEndpoints();

  /// #1564 — the schema check the ROUTER watches. Left live it asked a
  /// configured backend how old its schema was, and an old one sent an
  /// otherwise independent demonstration to the server-update screen.
  final DemoSchemaVersionSource schema = DemoSchemaVersionSource();

  /// Nothing reached the device or the network.
  bool get nothingLeft =>
      savedFiles.isEmpty &&
      sharedFiles.isEmpty &&
      sharedTexts.isEmpty &&
      openedLinks.isEmpty &&
      pushEndpoints.saved.isEmpty;

  Future<String?> saveFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    savedFiles.add(fileName);
    return 'demo://$fileName';
  }

  Future<FileShareOutcome> shareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? text,
  }) async {
    sharedFiles.add(fileName);
    // Demo shares nothing anywhere; `sent` keeps the journeys reading
    // like the real thing (#1532).
    return FileShareOutcome.sent;
  }

  Future<void> shareText(String text) async => sharedTexts.add(text);

  Future<bool> openLink(Uri uri) async {
    openedLinks.add(uri);
    return true;
  }
}

/// #1564 — the push transport a Demo session has, which is none.
///
/// [initialize] answers false, the same answer an unconfigured Firebase
/// or the F-Droid build gives, so `PushService.start` stops before it can
/// register. The attempt is RECORDED rather than silently dropped: the
/// point of these edges is that a session can say what it was asked to
/// send, not that the asking is invisible.
class DemoPushConnector implements PushConnector {
  int initializeCalls = 0;
  int registerCalls = 0;

  @override
  Future<bool> initialize({
    required void Function(String url) onNewEndpoint,
    required void Function() onUnregistered,
    required void Function(Uint8List content) onMessage,
  }) async {
    initializeCalls++;
    return false;
  }

  @override
  Future<void> register() async => registerCalls++;
}

/// #1564 — the server-side endpoint registry, in memory.
///
/// Reached only if a transport somehow answered; it exists so that the
/// answer to "could a Demo session write a row into `push_endpoints`" is
/// "there is no client here", rather than "the server would refuse it".
class DemoPushEndpoints implements PushEndpointRepository {
  final List<String> saved = [];
  final List<String> removed = [];

  @override
  Future<void> saveEndpoint({
    required List<String> memberIds,
    required String endpoint,
  }) async {
    saved.add(endpoint);
  }

  @override
  Future<void> removeEndpoint(String endpoint) async => removed.add(endpoint);
}

/// #1564 — the schema version a Demo session reports: exactly the one
/// this build needs.
///
/// The demonstration runs on the fixture, which IS this build's shape,
/// so "current" is the truthful answer rather than a convenient one —
/// and `schemaCompatibility` never sends a visitor to /server-update for
/// the state of a backend the session is not talking to.
class DemoSchemaVersionSource implements SchemaVersionSource {
  int reads = 0;

  @override
  Future<int?> read() async {
    reads++;
    return requiredSchemaVersion;
  }
}
