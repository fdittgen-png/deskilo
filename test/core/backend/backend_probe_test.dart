// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1651 — what may be sent to a candidate server, and what its answer
// proves. The key classifier reads shape and declared claims and sends
// nothing; the probe's table of answers maps every shape a server can
// produce onto facets, and an answer it cannot classify is `attention`,
// never `ok`. A save records what it replaced so it can be undone until
// the restart that would make it real.
import 'dart:async';
import 'dart:convert';

import 'package:deskilo/core/backend/backend_key.dart';
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/backend_uri.dart';
import 'package:deskilo/core/backend/schema_version.dart';
import 'package:deskilo/core/demo/data/stores.dart';
import 'package:deskilo/core/instance/schema_compatibility.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A JWT with [claims] — three base64url segments, an unsigned header.
String jwt(Map<String, Object?> claims) {
  String seg(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${seg({'alg': 'HS256', 'typ': 'JWT'})}.${seg(claims)}.sig';
}

final anonJwt = jwt({'iss': 'supabase', 'ref': 'abc', 'role': 'anon'});
final serviceJwt =
    jwt({'iss': 'supabase', 'ref': 'abc', 'role': 'service_role'});
final userJwt = jwt({
  'iss': 'https://abc.supabase.co/auth/v1',
  'sub': '5f1c0d3a-0000-4000-8000-000000000001',
  'role': 'authenticated',
});
final idToken = jwt({
  'iss': 'https://accounts.google.com',
  'sub': '1234567890',
  'email': 'someone@example.com',
});
const publishable = 'sb_publishable_0123456789abcdefghij';

/// A transport scripted per call.
class ScriptedTransport implements BackendProbeTransport {
  ScriptedTransport({this.onWorkspace, this.version, this.versionError});
  final Object? onWorkspace;
  final int? version;
  final Object? versionError;
  bool disposed = false;

  @override
  Future<void> readOneWorkspace() async {
    if (onWorkspace != null) throw onWorkspace!;
  }

  @override
  Future<int?> readVersion() async {
    if (versionError != null) throw versionError!;
    return version;
  }

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  const endpoint = BackendEndpoint('https://abc.supabase.co', publishable);

  group('the key classifier', () {
    test('accepts the two public client keys and nothing else', () {
      expect(classifyBackendKey(publishable), BackendKeyKind.publishable);
      expect(classifyBackendKey(anonJwt), BackendKeyKind.legacyAnon);
      expect(classifyBackendKey('sb_secret_0123456789'), BackendKeyKind.secret);
      expect(classifyBackendKey(serviceJwt), BackendKeyKind.secret);
      expect(classifyBackendKey('sbp_0123456789abcdef'),
          BackendKeyKind.personalAccessToken);
      expect(classifyBackendKey(userJwt), BackendKeyKind.userToken);
      expect(classifyBackendKey(idToken), BackendKeyKind.userToken);
      expect(classifyBackendKey('postgresql://postgres:pw@db.example:5432/x'),
          BackendKeyKind.connectionString);
      expect(classifyBackendKey('postgres://x'), BackendKeyKind.connectionString);
    });

    test('a JWT whose claims cannot be read is malformed, not anon', () {
      // The old rule: any eyJ with two dots passed as the anon key.
      expect(classifyBackendKey('eyJa.b.c'), BackendKeyKind.malformed);
      expect(classifyBackendKey('eyJ.only.two.dots.x'), BackendKeyKind.malformed);
      expect(classifyBackendKey(jwt({'iss': 'x'})), BackendKeyKind.malformed);
      expect(classifyBackendKey('sb_publishable_'), BackendKeyKind.malformed);
      expect(classifyBackendKey('random words'), BackendKeyKind.malformed);
      expect(classifyBackendKey('a' * (backendKeyMaxLength + 1)),
          BackendKeyKind.malformed);
      expect(classifyBackendKey(''), BackendKeyKind.malformed);
    });

    test('each refused kind is its own sentence, and none repeats the value',
        () {
      final cases = {
        'sb_secret_abc': BackendEndpointError.keySecret,
        serviceJwt: BackendEndpointError.keySecret,
        'sbp_tok': BackendEndpointError.keyPersonalToken,
        userJwt: BackendEndpointError.keyUserToken,
        'postgres://u:p@h/db': BackendEndpointError.keyConnectionString,
        'eyJa.b.c': BackendEndpointError.keyNotSupabase,
      };
      for (final entry in cases.entries) {
        final error = validateBackendEndpoint(endpoint.url, entry.key);
        expect(error, entry.value, reason: entry.key);
        expect(backendErrorText(null, error!), isNot(contains(entry.key)));
      }
      expect(validateBackendEndpoint(endpoint.url, anonJwt), isNull);
      expect(validateBackendEndpoint(endpoint.url, publishable), isNull);
    });
  });

  group('the canonical origin', () {
    test('is https://host[:port] and nothing more', () {
      expect(canonicalBackendUrl('https://ABC.supabase.co/'),
          'https://abc.supabase.co');
      expect(canonicalBackendUrl('https://self.example:8443'),
          'https://self.example:8443');
      expect(canonicalBackendUrl('https://self.example:443'),
          'https://self.example');
      for (final bad in [
        'https://user:pw@abc.supabase.co',
        'https://abc.supabase.co/rest/v1',
        'https://abc.supabase.co?x=1',
        'https://abc.supabase.co#frag',
        'http://abc.supabase.co',
        'https://localhost',
        'https://${'a' * backendUrlMaxLength}.example',
      ]) {
        expect(canonicalBackendUrl(bad), isNull, reason: bad);
      }
      expect(
        validateBackendEndpoint('https://abc.supabase.co/rest/v1', publishable),
        BackendEndpointError.urlNotCanonical,
      );
    });
  });

  group('the server code', () {
    test('carries a label that is shown as unverified, never keyed on', () {
      final payload = BackendUriCodec.encode(endpoint, label: 'Pézenas');
      final d = BackendUriCodec.decodeDescriptor(payload)!;
      expect(d.endpoint.url, endpoint.url);
      expect(d.endpoint.key, publishable);
      expect(d.label, 'Pézenas');
      expect(BackendUriCodec.decode(payload)?.url, endpoint.url);
    });

    test('is refused whole when any part is not a public descriptor', () {
      expect(
        BackendUriCodec.decodeDescriptor(
            'deskilo://server?url=https://abc.supabase.co&key=sb_secret_x'),
        isNull,
      );
      expect(
        BackendUriCodec.decodeDescriptor(
            'deskilo://server?url=https://u:p@abc.supabase.co&key=$publishable'),
        isNull,
      );
      expect(
        BackendUriCodec.decodeDescriptor(
            'deskilo://server?url=https://abc.supabase.co/x&key=$publishable'),
        isNull,
      );
      final oversized =
          '${BackendUriCodec.encode(endpoint)}&pad=${'x' * BackendUriCodec.maxPayloadLength}';
      expect(BackendUriCodec.decodeDescriptor(oversized), isNull);
      expect(BackendUriCodec.decodeDescriptor('https://abc.supabase.co'), isNull);
    });

    test('the URL is canonicalised on decode', () {
      final d = BackendUriCodec.decodeDescriptor(
          'deskilo://server?url=https://ABC.supabase.co/&key=$publishable');
      expect(d?.endpoint.url, 'https://abc.supabase.co');
    });
  });

  group('the probe', () {
    Future<BackendProbeReport> probe(ScriptedTransport t) =>
        probeBackend(endpoint, transport: (_) => t);

    test('a current schema is ok on every facet', () async {
      final t = ScriptedTransport(version: requiredSchemaVersion);
      final r = await probe(t);
      expect(r.result, BackendProbeResult.ok);
      expect(r.reachable, ProbeFacet.yes);
      expect(r.keyAccepted, ProbeFacet.yes);
      expect(r.schemaRecognised, ProbeFacet.yes);
      expect(r.compatibility, SchemaCompatibility.current);
      expect(r.usable, isTrue);
      expect(t.disposed, isTrue, reason: 'the throwaway client is closed');
    });

    test('newer is usable under the declared contract; older is not',
        () async {
      final ahead = await probe(ScriptedTransport(version: requiredSchemaVersion + 1));
      expect(ahead.result, BackendProbeResult.ahead);
      expect(ahead.usable, isTrue);
      final behind = await probe(ScriptedTransport(version: requiredSchemaVersion - 1));
      expect(behind.result, BackendProbeResult.behind);
      expect(behind.usable, isFalse);
      final none = await probe(ScriptedTransport(version: null));
      expect(none.result, BackendProbeResult.behind,
          reason: 'no marker = predates 0226');
    });

    test('a version that could not be read is attention, not ok', () async {
      final r = await probe(ScriptedTransport(
          versionError: const SchemaVersionUnavailable('timeout')));
      expect(r.result, BackendProbeResult.attention);
      expect(r.schemaRecognised, ProbeFacet.yes);
      expect(r.compatibility, isNull);
      expect(r.usable, isFalse);
    });

    test('each PostgREST answer lands on its own facets', () async {
      PostgrestException pg(String? code, [String message = '']) =>
          PostgrestException(message: message, code: code);
      final table = <PostgrestException, BackendProbeResult>{
        pg('42P01', 'relation "workspaces" does not exist'):
            BackendProbeResult.schemaMissing,
        pg('PGRST301', 'JWT expired'): BackendProbeResult.badKey,
        pg('401', 'Invalid API key'): BackendProbeResult.badKey,
        pg('403', 'permission denied'): BackendProbeResult.attention,
        pg('42501', 'permission denied for table workspaces'):
            BackendProbeResult.attention,
        pg('500', 'internal'): BackendProbeResult.attention,
        pg('502', '<html>bad gateway</html>'): BackendProbeResult.attention,
        pg('301', 'moved'): BackendProbeResult.attention,
        pg(null, 'something new'): BackendProbeResult.attention,
      };
      for (final entry in table.entries) {
        final r = await probe(ScriptedTransport(onWorkspace: entry.key));
        expect(r.result, entry.value, reason: '${entry.key.code}');
        expect(r.reachable, ProbeFacet.yes);
        expect(r.usable, isFalse);
      }
      final missing = classifyProbeError(pg('42P01'));
      expect(missing.schemaRecognised, ProbeFacet.no);
      expect(missing.keyAccepted, ProbeFacet.yes);
      final refused = classifyProbeError(pg('PGRST301'));
      expect(refused.keyAccepted, ProbeFacet.no);
      expect(refused.schemaRecognised, ProbeFacet.unknown);
    });

    test('a timeout, a socket error or a malformed body is unreachable',
        () async {
      for (final failure in [
        TimeoutException('12s'),
        const SocketExceptionLike(),
        const FormatException('not json'),
      ]) {
        final r = await probe(ScriptedTransport(onWorkspace: failure));
        expect(r.result, BackendProbeResult.unreachable, reason: '$failure');
        expect(r.reachable, ProbeFacet.no);
        expect(r.keyAccepted, ProbeFacet.unknown);
        expect(r.usable, isFalse);
      }
    });
  });

  group('the pending switch', () {
    late InMemoryBackendSettingsStore store;
    late ProviderContainer container;
    const first = BackendEndpoint('https://first.supabase.co', publishable);
    const second = BackendEndpoint('https://second.supabase.co', publishable);

    setUp(() {
      store = InMemoryBackendSettingsStore();
      container = ProviderContainer(overrides: [
        backendSettingsStoreProvider.overrideWithValue(store),
      ]);
      addTearDown(container.dispose);
    });

    test('a save records what it replaced, and undo restores it', () async {
      await container.read(activeBackendProvider.future);
      final notifier = container.read(activeBackendProvider.notifier);
      await notifier.setEndpoint(first);
      expect(store.value, first);
      expect(store.pending?.previous, isNull, reason: 'the default was in force');
      expect(await notifier.undoSwitch(), isTrue);
      expect(store.value, isNull);
      expect(store.pending, isNull);
      expect(await notifier.undoSwitch(), isFalse, reason: 'nothing pending');
    });

    test('two saves before a restart still undo to what the process runs on',
        () async {
      store.value = first;
      await container.read(activeBackendProvider.future);
      final notifier = container.read(activeBackendProvider.notifier);
      await notifier.setEndpoint(second);
      await notifier.setEndpoint(null);
      expect(store.pending?.previous, first);
      await notifier.undoSwitch();
      expect(store.value, first);
    });
  });
}

/// A non-Postgrest, non-timeout failure: what a dead socket throws is a
/// platform type; any other Object takes the same branch.
class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
  @override
  String toString() => 'SocketException: connection refused';
}
