// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1832 / #2562 C1b -- one connected target as the pool keeps it, and the
// check every connection (password, code or identity adoption) passes on
// the target's own server before anything is saved.
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_settings.dart';
import 'connection_outcome.dart';
import 'federation_authority.dart' show deskiloSubjectOf;

class ConnectedInstallation {
  const ConnectedInstallation({
    required this.endpoint,
    required this.account,
    required this.installationId,
    this.issuer,
    this.subject,
  });
  final BackendEndpoint endpoint;
  final String account, installationId;

  /// One saved record of the pool, keyed by its [source] address.
  factory ConnectedInstallation.fromRecord(
    String source,
    Map<Object?, Object?> record,
  ) => ConnectedInstallation(
    endpoint: BackendEndpoint(source, record['key'] as String),
    account: record['account'] as String,
    installationId: record['installation_id'] as String,
    issuer: record['issuer'] as String?,
    subject: record['subject'] as String?,
  );

  /// #2562 -- the canonical identity a connection adopted from the identity
  /// flow was verified for; null for one connected with that server's own
  /// password or code.
  final String? issuer, subject;
}

/// What [client]'s signed-in session is on its own server: the account,
/// the installation (refused when it is not [installationId]) and, for an
/// identity adoption, the Deskilo [subject] that account must carry.
/// Reads no private payload and changes nothing.
Future<({String account, String installation, Session session})>
inspectConnectedTarget(
  String source,
  SupabaseClient client, {
  String? installationId,
  String? subject,
}) async {
  final user = (await client.auth.getUser()).user;
  final session = client.auth.currentSession;
  if (user == null || session == null || user.id != session.user.id) {
    throw ConnectionFailure(source, ConnectionFailureReason.denied);
  }
  if (subject != null && deskiloSubjectOf(user) != subject) {
    throw ConnectionFailure(source, ConnectionFailureReason.changedIdentity);
  }
  final identity = await client
      .from('installation_identity')
      .select('installation_id')
      .single();
  final installation = identity['installation_id'];
  if (installation is! String || installation.isEmpty) {
    throw ConnectionFailure(source, ConnectionFailureReason.malformed);
  }
  if (installationId != null && installation != installationId) {
    throw ConnectionFailure(source, ConnectionFailureReason.changedIdentity);
  }
  // #1832 — compatibility comes from the target's public descriptor
  // (#1847), not from reading the account's invoices: connecting reads
  // no private payload and runs no financial operation.
  if (!connectableProfile(await describeTarget(client))) {
    throw ConnectionFailure(source, ConnectionFailureReason.unsupported);
  }
  return (account: user.id, installation: installation, session: session);
}
