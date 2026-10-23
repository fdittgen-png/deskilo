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
import '../time/workspace_calendar.dart';
import '../vat/tax_reference_snapshot.dart';

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

  /// The target as the installation's own birth record names it:
  /// `installationId:workspaceId` until `workspaces.network_id` exists.
  factory WorkspaceTarget.local({
    required String installationId,
    required String workspaceId,
  }) =>
      WorkspaceTarget(
        networkId: '$installationId:$workspaceId',
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
/// local account there, both epochs and the immutable business inputs:
/// the settings revision pair, the workspace's own calendar (zone, open
/// days, working day, closures) and the tax reference dataset its
/// installation answered (#2561 L4). All of them are read from the selected
/// workspace's own host and travel with its epoch, so W-B's context never
/// carries W-A's calendar or tax data.
@immutable
class WorkspaceContext {
  const WorkspaceContext({
    required this.identity,
    required this.target,
    required this.workspaceLocalUserId,
    required this.personalEpoch,
    required this.workspaceEpoch,
    required this.settings,
    required this.calendar,
    required this.taxReference,
  });

  final CanonicalIdentity identity;
  final WorkspaceTarget target;
  final String workspaceLocalUserId;
  final int personalEpoch;
  final int workspaceEpoch;
  final SettingsCapture settings;

  /// The workspace's calendar, captured with the context.
  final WorkspaceCalendar calendar;

  /// The tax reference dataset of the workspace's installation.
  final TaxReferenceSnapshot taxReference;

  /// The workspace's IANA zone as stored, captured with the context.
  String get timezone => calendar.timezone;

  /// The namespace a per-target cache or in-flight map is keyed by: target
  /// AND local account, so another account on the same target (or the same
  /// local ids elsewhere) never shares it.
  String get cacheNamespace => namespaceOf(target, workspaceLocalUserId);

  /// [cacheNamespace] before the context exists (#2561 L4: its own business
  /// inputs are read under it while it is captured).
  static String namespaceOf(WorkspaceTarget target, String localUserId) =>
      cacheDigest('workspace-context', [target.networkId, localUserId], 24);

  /// Whether [other] is the very same operation context: a late result
  /// computed for one may be applied only while this holds.
  bool sameOperationAs(WorkspaceContext other) =>
      other.identity == identity &&
      other.target == target &&
      other.workspaceLocalUserId == workspaceLocalUserId &&
      other.personalEpoch == personalEpoch &&
      other.workspaceEpoch == workspaceEpoch &&
      other.settings == settings &&
      other.calendar == calendar &&
      other.taxReference == taxReference;

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
        calendar,
        taxReference,
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
