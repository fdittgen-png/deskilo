// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1834 A — connecting ANOTHER participating installation with the
// identity the person already has, instead of a second account and
// password on every server.
//
// The person is signed in here. To contact, write to or ask to join a
// space on server B, B must know it is them. If B accepts the same
// identity authority this person signed up with, B's own sign-in runs in
// the system browser ("Continue with Deskilo"), B verifies the binding on
// its side, and the resulting B-native session is kept in the connection
// registry (`ConnectedInstallations.adopt`) — never installed as this
// app's main session, never forwarded anywhere else.
//
// Separate transitions, never merged: being signed in, being bound on B,
// being connected to B, being admitted to a space on B, and assistant
// eligibility. Connecting grants no membership, role or MCP authority.
//
// The identity is the authority's issuer and subject, never an e-mail or
// a display name: B must report, for the account its flow produced, the
// SAME subject at the SAME issuer as the person signed in here. A browser
// that returns somebody else is refused and nothing is saved.
//
// One callback owner: the flow's guard is routed through the existing
// `AuthCallbackDispatcher`; the main SDK client never exchanges the code.
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../trace/trace_logger.dart';
import 'auth_callback_dispatch.dart';
import 'auth_callback_guard.dart';
import 'auth_secret_store.dart';
import 'backend_settings.dart';
import 'connected_installations.dart';
import 'federation_authority.dart';
import 'federation_handoff.dart';
import 'installation_auth_storage.dart';
import 'native_federation_flow.dart' show NativeFederationFlow;
import 'schema_version.dart' show isMissingFunction;

/// What the person was about to do on the other server. Kept while the
/// browser is open, so the screen resumes exactly that — with its normal
/// confirmation — and never anything else.
enum SecondaryConnectAction { contact, inquiry, apply }

class SecondaryConnectIntent {
  const SecondaryConnectIntent({
    required this.target,
    required this.workspaceId,
    required this.action,
  });

  /// The other server, as its public card names it.
  final BackendEndpoint target;
  final String workspaceId;
  final SecondaryConnectAction action;
}

/// Who the person is at the identity authority.
class CanonicalIdentity {
  const CanonicalIdentity(this.issuer, this.subject);
  final String issuer;
  final String subject;
}

/// Why connecting with the identity is not possible for this target.
/// Each is a named answer; none of them creates an account anywhere.
enum IdentityConnectUnsupported {
  /// This app's own server does not tell who the person is at an
  /// authority another server could accept.
  noSharedIdentity,

  /// The other server does not offer "Continue with Deskilo".
  targetWithoutDeskiloSignIn,

  /// The other server accepts a DIFFERENT identity authority.
  differentAuthority,

  /// The other server speaks no connection protocol this build speaks.
  serverUnsupported,

  /// The other server is this app's own server.
  currentServer,

  /// Nothing answered.
  unavailable,
}

class IdentityConnectUnavailable implements Exception {
  const IdentityConnectUnavailable(this.reason);
  final IdentityConnectUnsupported reason;

  @override
  String toString() => 'IdentityConnectUnavailable(${reason.name})';
}

/// The other server checked before anything opens: its address, the
/// identity authority it accepts and the installation it is.
class IdentityConnectReadiness {
  const IdentityConnectReadiness({
    required this.target,
    required this.authority,
    required this.identity,
  });
  final BackendEndpoint target;
  final FederationAuthority authority;
  final CanonicalIdentity identity;

  /// The host the person is about to sign in to.
  String get host => Uri.parse(target.url).host;
}

enum SecondaryConnectStatus {
  /// Bound on the other server and saved in the connection registry.
  connected,

  /// Nothing was saved; [SecondaryConnectEvent.failure] says why.
  failed,

  /// The other server accepted the person, but this device could not keep
  /// the connection. Nothing was submitted; connecting again is safe.
  notSaved,

  /// The person (or a newer flow) gave up before the browser returned.
  cancelled,
}

class SecondaryConnectEvent {
  const SecondaryConnectEvent(
    this.flow,
    this.intent,
    this.status, {
    this.failure,
    this.notSaved,
  });
  final String flow;
  final SecondaryConnectIntent intent;
  final SecondaryConnectStatus status;
  final FederationFailure? failure;
  final ConnectionFailure? notSaved;
}

/// The connection journey as screens see it. [SecondaryFederation] runs
/// it against real servers; tests and Demo answer it in memory.
abstract interface class IdentityConnector {
  /// Checks the other server without launching anything.
  Future<IdentityConnectReadiness> assess(BackendEndpoint target);

  /// Opens the other server's own sign-in ONCE; answers the flow id. The
  /// outcome arrives later on [events].
  Future<String> begin(SecondaryConnectIntent intent);

  /// Abandons [flow] if its browser has not come back yet.
  Future<void> cancel(String flow);

  Stream<SecondaryConnectEvent> get events;
}

/// The person's identity at the authority, read from this app's server.
/// Null when this server does not say (an anonymous or federated account
/// without a provider subject): connecting by identity is then refused.
Future<CanonicalIdentity?> canonicalIdentityOf(SupabaseClient active) async {
  final user = active.auth.currentUser;
  if (user == null) return null;
  final authority = FederationAuthority.parse(
    await active.rpc<Object?>('public_identity_authority'),
  );
  if (authority != null) {
    // A federated server: the person's subject is their Deskilo identity.
    final sub = deskiloSubjectOf(user);
    return sub == null ? null : CanonicalIdentity(authority.issuer, sub);
  }
  // This server is its own identity authority: other servers that accept
  // it as their Deskilo provider see this account's id as the subject.
  return CanonicalIdentity(
    '${Uri.parse(active.rest.url).origin}/auth/v1',
    user.id,
  );
}

/// The subject [user] holds at the Deskilo provider, if any.
String? deskiloSubjectOf(User user) {
  for (final identity in user.identities ?? const <UserIdentity>[]) {
    if (identity.provider != NativeFederationFlow.provider.name) continue;
    final sub = identity.identityData?['sub'];
    if (sub is String && sub.isNotEmpty) return sub;
  }
  return null;
}

class _Pending {
  _Pending(this.flow, this.intent, this.guard, this.readiness, this.account);
  final String flow;
  final SecondaryConnectIntent intent;
  final AuthCallbackGuard guard;
  final IdentityConnectReadiness readiness;
  final String account;
}

class SecondaryFederation implements IdentityConnector {
  SecondaryFederation({
    required this.active,
    required this.registry,
    required this.secrets,
    required this.callback,
    this.dispatcher,
    this.launch = _launch,
    http.Client Function()? transport,
    DateTime Function()? now,
  }) : transport = transport ?? http.Client.new,
       now = now ?? DateTime.now;

  final SupabaseClient active;
  final ConnectedInstallations registry;
  final AuthSecretStore secrets;
  final Uri callback;
  final AuthCallbackDispatcher? dispatcher;
  final Future<bool> Function(Uri) launch;
  final http.Client Function() transport;
  final DateTime Function() now;
  final _events = StreamController<SecondaryConnectEvent>.broadcast();
  _Pending? _pending;

  static Future<bool> _launch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  Stream<SecondaryConnectEvent> get events => _events.stream;

  String get _origin => Uri.parse(active.rest.url).origin;

  SupabaseClient _client(BackendEndpoint target, {String? flow}) {
    final origin = Uri.parse(target.url).origin;
    return SupabaseClient(
      target.url,
      target.key,
      httpClient: OriginOnlyClient(origin, transport()),
      authOptions: AuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: false,
        pkceAsyncStorage: flow == null
            ? null
            : InstallationPkceStorage(
                secrets,
                Uri.parse(origin),
                purpose: 'connect.$flow',
              ),
      ),
    );
  }

  BackendEndpoint _canonical(BackendEndpoint target) {
    final url = canonicalBackendUrl(target.url);
    if (url != null && url == _origin) {
      throw const IdentityConnectUnavailable(
        IdentityConnectUnsupported.currentServer,
      );
    }
    if (url == null ||
        validateBackendEndpoint(url, target.key.trim()) != null) {
      throw const IdentityConnectUnavailable(
        IdentityConnectUnsupported.unavailable,
      );
    }
    return BackendEndpoint(url, target.key.trim());
  }

  @override
  Future<IdentityConnectReadiness> assess(BackendEndpoint target) async {
    final endpoint = _canonical(target);
    final CanonicalIdentity? identity;
    try {
      identity = await canonicalIdentityOf(active);
    } catch (e, st) {
      TraceLogger.instance.warn(
        'connections',
        'own identity unreadable',
        error: e.runtimeType,
        stackTrace: st,
      );
      throw const IdentityConnectUnavailable(
        IdentityConnectUnsupported.unavailable,
      );
    }
    if (identity == null) {
      throw const IdentityConnectUnavailable(
        IdentityConnectUnsupported.noSharedIdentity,
      );
    }
    final client = _client(endpoint);
    try {
      if (!connectableProfile(await describeTarget(client))) {
        throw const IdentityConnectUnavailable(
          IdentityConnectUnsupported.serverUnsupported,
        );
      }
      final authority = FederationAuthority.parse(
        await client
            .rpc<Object?>('public_identity_authority')
            .timeout(const Duration(seconds: 12)),
      );
      if (authority == null) {
        throw const IdentityConnectUnavailable(
          IdentityConnectUnsupported.targetWithoutDeskiloSignIn,
        );
      }
      if (authority.issuer != identity.issuer) {
        throw const IdentityConnectUnavailable(
          IdentityConnectUnsupported.differentAuthority,
        );
      }
      return IdentityConnectReadiness(
        target: endpoint,
        authority: authority,
        identity: identity,
      );
    } on IdentityConnectUnavailable {
      rethrow;
    } catch (e, st) {
      // trace-exempt: classified below; only the type is recorded.
      TraceLogger.instance.warn(
        'connections',
        'identity connect check failed',
        error: e.runtimeType,
        stackTrace: st,
      );
      throw IdentityConnectUnavailable(
        e is PostgrestException && isMissingFunction(e)
            ? IdentityConnectUnsupported.targetWithoutDeskiloSignIn
            : IdentityConnectUnsupported.unavailable,
      );
    } finally {
      await client.dispose();
    }
  }

  @override
  Future<String> begin(SecondaryConnectIntent intent) async {
    final account = active.auth.currentUser?.id;
    if (account == null) {
      throw const FederationStartFailure(FederationFailure.wrongAccount);
    }
    final readiness = await assess(intent.target);
    final previous = _pending;
    if (previous != null) await cancel(previous.flow);
    final target = readiness.target;
    final guard = AuthCallbackGuard(
      secrets,
      Uri.parse(Uri.parse(target.url).origin),
      callback,
      now: now,
    );
    final redirect = await guard.begin(
      'federation-connect',
      account: account,
      issuer: readiness.authority.issuer,
      installationId: readiness.authority.installationId,
    );
    final flow = guard.flow!;
    final client = _client(target, flow: flow);
    try {
      final url = await client.auth.getOAuthSignInUrl(
        provider: NativeFederationFlow.provider,
        redirectTo: redirect,
        scopes: 'openid profile',
      );
      if (active.auth.currentUser?.id != account) {
        throw const FederationStartFailure(FederationFailure.wrongAccount);
      }
      _pending = _Pending(flow, intent, guard, readiness, account);
      dispatcher?.routeSecondary(guard, complete);
      if (!await launch(Uri.parse(url.url))) {
        throw const FederationStartFailure(
          FederationFailure.browserUnavailable,
        );
      }
      return flow;
    } catch (error, stack) {
      // trace-exempt: OAuth exceptions may include browser URLs or codes.
      await _release(flow, guard);
      Error.throwWithStackTrace(
        FederationStartFailure(switch (error) {
          FederationStartFailure(:final failure) => failure,
          AuthRetryableFetchException() => FederationFailure.network,
          AuthException(:final code) => federationFailureFromCode(code),
          _ => FederationFailure.network,
        }),
        stack,
      );
    } finally {
      await client.dispose();
    }
  }

  /// Called by the dispatcher once the flow's guard claimed [uri].
  Future<void> complete(Uri uri) async {
    final pending = _pending;
    if (pending == null || !pending.guard.consumed) return;
    final flow = pending.flow;
    final target = pending.readiness.target;
    final client = _client(target, flow: flow);
    SecondaryConnectEvent? outcome;
    var keep = false;
    try {
      if (uri.queryParameters.containsKey('error')) {
        outcome = _failed(
          pending,
          federationFailureFromCode(uri.queryParameters['error_code']),
        );
        return;
      }
      final code = uri.queryParameters['code'];
      if (code == null || code.isEmpty) throw const _Refused();
      final session = (await client.auth.exchangeCodeForSession(code)).session;
      final user = (await client.auth.getUser()).user;
      if (user == null || user.id != session.user.id) throw const _Refused();
      // The person who started is still the one signed in here.
      if (active.auth.currentUser?.id != pending.account) {
        throw const _Refused(FederationFailure.wrongAccount);
      }
      final authority = FederationAuthority.parse(
        await client.rpc<Object?>('public_identity_authority'),
      );
      if (authority?.issuer != pending.readiness.authority.issuer ||
          authority?.installationId !=
              pending.readiness.authority.installationId) {
        throw const _Refused(FederationFailure.incompatibleServer);
      }
      // The SAME person at the SAME authority — never an e-mail match.
      if (deskiloSubjectOf(user) != pending.readiness.identity.subject) {
        throw const _Refused(FederationFailure.wrongAccount);
      }
      final binding = await client.rpc<Object?>('finalize_identity_binding');
      final refusal = federationFailureFromBinding(binding);
      if (refusal != null) throw _Refused(refusal);
      if (binding is! Map ||
          binding['issuer'] != authority!.issuer ||
          binding['installation_id'] != authority.installationId) {
        throw const _Refused(FederationFailure.incompatibleServer);
      }
      if (_pending?.flow != flow) throw const _Refused();
      try {
        await registry.adopt(
          target,
          session,
          installationId: authority.installationId,
        );
        keep = true;
        outcome = SecondaryConnectEvent(
          flow,
          pending.intent,
          SecondaryConnectStatus.connected,
        );
      } on ConnectionFailure catch (failure, stack) {
        TraceLogger.instance.warn(
          'connections',
          'identity connection not kept: ${failure.reason.name}',
          stackTrace: stack,
        );
        outcome = SecondaryConnectEvent(
          flow,
          pending.intent,
          SecondaryConnectStatus.notSaved,
          notSaved: failure,
        );
      }
    } on _Refused catch (refusal, stack) {
      TraceLogger.instance.warn(
        'connections',
        'identity connection refused: ${refusal.failure.name}',
        stackTrace: stack,
      );
      outcome = _failed(pending, refusal.failure);
    } on AuthRetryableFetchException catch (_, stack) {
      TraceLogger.instance.warn(
        'connections',
        'identity connection unavailable',
        stackTrace: stack,
      );
      outcome = _failed(pending, FederationFailure.network);
    } on AuthException catch (error, stack) {
      // The error CODE only: its prose may quote the account or callback.
      TraceLogger.instance.warn(
        'connections',
        'identity exchange refused: ${error.code ?? error.statusCode}',
        stackTrace: stack,
      );
      outcome = _failed(pending, federationFailureFromCode(error.code));
    } catch (error, stack) {
      // trace-exempt: network/provider payloads may contain credentials.
      TraceLogger.instance.warn(
        'connections',
        'identity connection failed',
        stackTrace: stack,
      );
      outcome = _failed(pending, FederationFailure.network);
    } finally {
      // A session this device does not keep must not stay alive here.
      if (!keep && client.auth.currentSession != null) {
        try {
          await client.auth.signOut(scope: SignOutScope.local);
        } catch (error, stack) {
          // trace-exempt: report only that cleanup could not be confirmed.
          TraceLogger.instance.warn(
            'connections',
            'unused identity session cleanup unavailable',
            stackTrace: stack,
          );
        }
      }
      await client.dispose();
      await _release(flow, pending.guard);
      final event = outcome;
      if (event != null) _events.add(event);
    }
  }

  SecondaryConnectEvent _failed(_Pending pending, FederationFailure failure) =>
      SecondaryConnectEvent(
        pending.flow,
        pending.intent,
        SecondaryConnectStatus.failed,
        failure: failure,
      );

  @override
  Future<void> cancel(String flow) async {
    final pending = _pending;
    if (pending == null || pending.flow != flow || pending.guard.consumed) {
      return;
    }
    await _release(flow, pending.guard);
    _events.add(
      SecondaryConnectEvent(
        flow,
        pending.intent,
        SecondaryConnectStatus.cancelled,
      ),
    );
  }

  /// Lets go of [flow]: the dispatcher stops routing to it, its verifier
  /// and callback metadata go, so a late browser return is refused.
  Future<void> _release(String flow, AuthCallbackGuard guard) async {
    dispatcher?.unrouteSecondary(guard);
    if (_pending?.flow == flow) _pending = null;
    try {
      await guard.finish(flow);
      await InstallationPkceStorage(
        secrets,
        guard.origin,
        purpose: 'connect.$flow',
      ).removeItem(key: 'supabase.auth.token-code-verifier');
    } catch (error, stack) {
      // trace-exempt: no persisted callback secrets in diagnostic payloads.
      TraceLogger.instance.warn(
        'connections',
        'identity flow cleanup unavailable',
        stackTrace: stack,
      );
    }
  }

  Future<void> dispose() async {
    final pending = _pending;
    if (pending != null) await _release(pending.flow, pending.guard);
    await _events.close();
  }
}

class _Refused implements Exception {
  const _Refused([this.failure = FederationFailure.refused]);
  final FederationFailure failure;
}
