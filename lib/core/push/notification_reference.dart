// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2559 C2 — what a notification carries and where its tap may lead.
//
// A push names no person, amount or message: its visible text is generic
// per kind (send-push), and its data is an opaque, QUALIFIED reference —
// the installation that sent it, the workspace there, the kind of record
// and the record's id. The data is a claim, never an authority: the app
// opens the record's screen only after resolving the installation and the
// workspace against the signed-in account's own verified contexts. Anything
// else (signed out, another account, an unknown or unreachable source, a
// malformed reference) lands on a neutral page that shows nothing private.
//
// No Flutter, no client, no provider: the facts arrive as functions.
import 'package:meta/meta.dart';

import '../trace/trace_logger.dart';

/// The reference version this build reads (send-push `REFERENCE_VERSION`).
const String _referenceVersion = '1';

/// Ids are opaque tokens: uuids, or `installation:workspace` network ids.
final RegExp _opaqueId = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$');

/// The kinds of record a reference may point at.
enum NotificationObjectKind { event, note }

/// A notification's qualified reference, as validated from its data.
@immutable
class NotificationReference {
  const NotificationReference({
    required this.kind,
    required this.installationId,
    required this.workspaceId,
    required this.objectKind,
    required this.objectId,
  });

  /// The notification kind (`pending_request`, `member_note`, …).
  final String kind;
  final String installationId;
  final String workspaceId;
  final NotificationObjectKind objectKind;
  final String objectId;

  /// The reference of [data], or null when it is not a complete, valid
  /// version-1 workspace reference. Every other key is ignored: nothing
  /// beyond these five values is ever read from a notification.
  static NotificationReference? parse(Map<String, Object?> data) {
    if (data['v'] != _referenceVersion) return null;
    if (data['src'] != 'w') return null;
    final kind = data['kind'];
    final installation = data['inst'];
    final workspace = data['ws'];
    final objectId = data['ref_id'];
    final objectKind = NotificationObjectKind.values
        .where((k) => k.name == data['ref_kind'])
        .firstOrNull;
    if (kind is! String || !RegExp(r'^[a-z_]{1,64}$').hasMatch(kind)) {
      return null;
    }
    if (installation is! String ||
        workspace is! String ||
        objectId is! String ||
        objectKind == null) {
      return null;
    }
    for (final id in [installation, workspace, objectId]) {
      if (!_opaqueId.hasMatch(id)) return null;
    }
    return NotificationReference(
      kind: kind,
      installationId: installation,
      workspaceId: workspace,
      objectKind: objectKind,
      objectId: objectId,
    );
  }

  /// The wire form, exactly the keys [parse] reads.
  Map<String, String> toData() => {
        'v': _referenceVersion,
        'kind': kind,
        'src': 'w',
        'inst': installationId,
        'ws': workspaceId,
        'ref_kind': objectKind.name,
        'ref_id': objectId,
      };

  /// Two hosts may reuse local ids: the key that tells two notifications
  /// apart includes the source installation and workspace.
  String get dedupKey =>
      '$installationId|$workspaceId|${objectKind.name}|$objectId';

  @override
  bool operator ==(Object other) =>
      other is NotificationReference &&
      other.kind == kind &&
      other.installationId == installationId &&
      other.workspaceId == workspaceId &&
      other.objectKind == objectKind &&
      other.objectId == objectId;

  @override
  int get hashCode =>
      Object.hash(kind, installationId, workspaceId, objectKind, objectId);

  /// Never the ids themselves: a trace keeps the kind only.
  @override
  String toString() => 'NotificationReference($kind)';
}

/// The screen of a workspace that serves a notification kind. Unknown
/// kinds open the workspace's home: a newer server still reaches an older
/// client, and lands somewhere that belongs to the workspace.
@visibleForTesting
String notificationLocation(String kind) => switch (kind) {
      'pending_request' => '/pending',
      'member_note' || 'member_mention' => '/messages',
      'invoice_reminder' => '/invoices',
      _ => '/reserve',
    };

/// Why a tap opens the neutral landing instead of the record.
enum NeutralTapReason {
  /// The data was not a complete, valid reference.
  malformed,

  /// Nobody is signed in.
  signedOut,

  /// The installation or workspace is not one of the signed-in account's
  /// own (another account's notification, a removed membership).
  unknownSource,

  /// The source is known but could not be verified now (expired,
  /// revoked, unreachable).
  unavailable,
}

/// Where a tap leads.
sealed class TapDestination {
  const TapDestination();
}

/// The record's screen, on the workspace the reference names. [source] is
/// the connected installation's origin, null for the workspace on the
/// installation the app is signed in to.
final class OpenInWorkspace extends TapDestination {
  const OpenInWorkspace({
    required this.reference,
    required this.location,
    this.source,
  });

  final NotificationReference reference;
  final String location;
  final String? source;
}

/// The neutral landing: nothing private, nothing of another account.
final class NeutralLanding extends TapDestination {
  const NeutralLanding(this.reason);
  final NeutralTapReason reason;
}

/// What the app knows about the signed-in account when a tap arrives, as
/// functions so each fact is read only when it is needed.
class TapFacts {
  const TapFacts({
    required this.homeInstallationId,
    required this.homeWorkspaceIds,
    required this.connectedSourceOf,
    required this.verifyConnected,
  });

  /// The installation the app is signed in to (the personal home).
  final String homeInstallationId;

  /// The account's workspaces on that installation.
  final Future<Set<String>> Function() homeWorkspaceIds;

  /// The connected installation (its origin) of the signed-in account whose
  /// verified id is the given one, or null.
  final Future<String?> Function(String installationId) connectedSourceOf;

  /// Whether the account still reaches [workspaceId] on [source] (its own
  /// pinned client and session). Throws when it cannot be verified.
  final Future<bool> Function(String source, String workspaceId)
      verifyConnected;
}

/// Resolves a tapped notification's [data] against the signed-in account.
/// [facts] is null while nobody is signed in. Never throws: anything that
/// goes wrong is a neutral landing.
Future<TapDestination> resolveNotificationTap(
  Map<String, Object?> data,
  Future<TapFacts?> Function() facts,
) async {
  final reference = NotificationReference.parse(data);
  if (reference == null) {
    return const NeutralLanding(NeutralTapReason.malformed);
  }
  try {
    final known = await facts();
    if (known == null) return const NeutralLanding(NeutralTapReason.signedOut);
    final location = notificationLocation(reference.kind);
    if (reference.installationId == known.homeInstallationId) {
      final mine = await known.homeWorkspaceIds();
      return mine.contains(reference.workspaceId)
          ? OpenInWorkspace(reference: reference, location: location)
          : const NeutralLanding(NeutralTapReason.unknownSource);
    }
    final source = await known.connectedSourceOf(reference.installationId);
    if (source == null) {
      return const NeutralLanding(NeutralTapReason.unknownSource);
    }
    return await known.verifyConnected(source, reference.workspaceId)
        ? OpenInWorkspace(
            reference: reference,
            location: location,
            source: source,
          )
        : const NeutralLanding(NeutralTapReason.unknownSource);
  } on Object catch (e, st) {
    // An unverifiable source is a neutral landing, never the record and
    // never a crash.
    TraceLogger.instance.warn('push', 'notification tap source unverifiable',
        error: e, stackTrace: st);
    return const NeutralLanding(NeutralTapReason.unavailable);
  }
}
