// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 C1 -- the semantic context an operation runs in, captured BEFORE its
// first await so a later selection (another workspace, another account, a
// different backend) cannot retarget it. Pure Dart: no client, no
// credential, nothing serialisable that could leak one. The personal home
// (P) and a workspace host (W) are separate physical installations; selecting
// W-B never changes the [PersonalContext].
import 'package:meta/meta.dart';

import '../cache/cache_scope.dart';
import '../settings/settings_capture.dart';

/// Who a person is across installations: the authority that vouches
/// ([issuer]) and the id it gave ([subject]). Never an email.
@immutable
class CanonicalIdentity {
  const CanonicalIdentity({required this.issuer, required this.subject});

  final String issuer;
  final String subject;

  @override
  bool operator ==(Object other) =>
      other is CanonicalIdentity &&
      other.issuer == issuer &&
      other.subject == subject;

  @override
  int get hashCode => Object.hash(issuer, subject);

  @override
  String toString() => 'CanonicalIdentity($issuer, $subject)';
}

/// The personal home: who is signed in there and which installation holds
/// the personal data. [personalEpoch] changes whenever that principal or
/// home changes, and fences work started for the previous one.
@immutable
class PersonalContext {
  const PersonalContext({
    required this.identity,
    required this.homeInstallationId,
    required this.personalLocalUserId,
    required this.personalEpoch,
  });

  final CanonicalIdentity identity;
  final String homeInstallationId;
  final String personalLocalUserId;
  final int personalEpoch;

  @override
  bool operator ==(Object other) =>
      other is PersonalContext &&
      other.identity == identity &&
      other.homeInstallationId == homeInstallationId &&
      other.personalLocalUserId == personalLocalUserId &&
      other.personalEpoch == personalEpoch;

  @override
  int get hashCode => Object.hash(
        identity,
        homeInstallationId,
        personalLocalUserId,
        personalEpoch,
      );
}

/// One workspace on one verified installation. Equal local workspace ids on
/// two installations are two targets.
@immutable
class WorkspaceTarget {
  const WorkspaceTarget({
    required this.networkId,
    required this.installationId,
    required this.workspaceId,
  });

  /// The target of a row that carries no stored `network_id` (a server
  /// from before the column, a fixture): the birth record as the server
  /// would stamp it, `installationId:workspaceId`.
  factory WorkspaceTarget.local({
    required String installationId,
    required String workspaceId,
  }) =>
      WorkspaceTarget(
        networkId: '$installationId:$workspaceId',
        installationId: installationId,
        workspaceId: workspaceId,
      );

  /// The target as the workspace row names it: the stored `network_id`
  /// (the installation's own birth record, never recomputed here) when the
  /// row carries one, [WorkspaceTarget.local] otherwise.
  factory WorkspaceTarget.stored({
    required String networkId,
    required String installationId,
    required String workspaceId,
  }) =>
      networkId.isEmpty
          ? WorkspaceTarget.local(
              installationId: installationId,
              workspaceId: workspaceId,
            )
          : WorkspaceTarget(
              networkId: networkId,
              installationId: installationId,
              workspaceId: workspaceId,
            );

  final String networkId;
  final String installationId;
  final String workspaceId;

  @override
  bool operator ==(Object other) =>
      other is WorkspaceTarget &&
      other.networkId == networkId &&
      other.installationId == installationId &&
      other.workspaceId == workspaceId;

  @override
  int get hashCode => Object.hash(networkId, installationId, workspaceId);

  @override
  String toString() => 'WorkspaceTarget($networkId)';
}

/// What a workspace operation runs on: the person, the verified target, the
/// local account there, both epochs and the immutable business inputs
/// (settings revision pair, the workspace's own time zone). The calendar
/// object and the tax-reference dataset join it with their consumers.
@immutable
class WorkspaceContext {
  const WorkspaceContext({
    required this.identity,
    required this.target,
    required this.workspaceLocalUserId,
    required this.personalEpoch,
    required this.workspaceEpoch,
    required this.settings,
    required this.timezone,
  });

  final CanonicalIdentity identity;
  final WorkspaceTarget target;
  final String workspaceLocalUserId;
  final int personalEpoch;
  final int workspaceEpoch;
  final SettingsCapture settings;

  /// The workspace's IANA zone as stored, captured with the context.
  final String timezone;

  /// The namespace a per-target cache or in-flight map is keyed by: target
  /// AND local account, so another account on the same target (or the same
  /// local ids elsewhere) never shares it.
  String get cacheNamespace => cacheDigest('workspace-context', [
        target.networkId,
        workspaceLocalUserId,
      ], 24);

  /// Whether [other] is the very same operation context: a late result
  /// computed for one may be applied only while this holds.
  bool sameOperationAs(WorkspaceContext other) =>
      other.identity == identity &&
      other.target == target &&
      other.workspaceLocalUserId == workspaceLocalUserId &&
      other.personalEpoch == personalEpoch &&
      other.workspaceEpoch == workspaceEpoch &&
      other.settings == settings &&
      other.timezone == timezone;

  @override
  bool operator ==(Object other) =>
      other is WorkspaceContext && sameOperationAs(other);

  @override
  int get hashCode => Object.hash(
        identity,
        target,
        workspaceLocalUserId,
        personalEpoch,
        workspaceEpoch,
        settings,
        timezone,
      );
}

/// Epochs that only move when the thing they fence changes. A slot is
/// "personal" or one target; the fingerprint names the principal and host.
/// The same fingerprint keeps its epoch (a token refresh is not a change),
/// a different one starts the next.
class EpochLedger {
  final _seen = <String, ({String fingerprint, int epoch})>{};

  int epochOf(String slot, String fingerprint) {
    final last = _seen[slot];
    if (last != null && last.fingerprint == fingerprint) return last.epoch;
    final next = (last?.epoch ?? 0) + 1;
    _seen[slot] = (fingerprint: fingerprint, epoch: next);
    return next;
  }
}
