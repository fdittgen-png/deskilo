// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Where one account was when the app last ran: its personal destination and
// its last place in a workspace, kept apart so a cold start can open either
// and a return to Me still lands on the personal one.
//
// The record names its owner whole (the issuer, the subject and the personal
// home installation) and is read back only by that owner. The workspace side
// names the space by its installation and its network reference, never by a
// bare local id: equal ids on two installations are two spaces. A record of
// another shape, another version or another owner decodes to nothing.
import 'dart:convert';

import 'package:meta/meta.dart';

import '../../../core/data/json_reader.dart';

/// Which side the account was on last.
enum ResumeSide { personal, workspace }

/// The last place in one workspace.
@immutable
class WorkspaceResume {
  const WorkspaceResume({
    required this.installation,
    required this.network,
    required this.location,
  });

  /// The installation the workspace lives on.
  final String installation;

  /// The workspace's network reference (`<installation>:<local id>`).
  final String network;

  /// The workspace location, a path without a query.
  final String location;

  @override
  bool operator ==(Object other) =>
      other is WorkspaceResume &&
      other.installation == installation &&
      other.network == network &&
      other.location == location;

  @override
  int get hashCode => Object.hash(installation, network, location);
}

/// One account's places.
@immutable
class ResumePlaces {
  const ResumePlaces({
    required this.issuer,
    required this.subject,
    required this.home,
    this.side = ResumeSide.personal,
    this.personal,
    this.workspace,
  });

  /// The record's shape. Bumped when a field changes meaning; an older
  /// record is then dropped rather than reinterpreted.
  static const int version = 1;

  final String issuer;
  final String subject;

  /// The personal home installation the account signed in to.
  final String home;
  final ResumeSide side;

  /// The personal destination (`/me…`), or null for Me's home.
  final String? personal;
  final WorkspaceResume? workspace;

  /// Whether this record is the one of [issuer]'s [subject] at [home].
  bool belongsTo({
    required String issuer,
    required String subject,
    required String home,
  }) => this.issuer == issuer && this.subject == subject && this.home == home;

  ResumePlaces atPersonal(String destination) => ResumePlaces(
    issuer: issuer,
    subject: subject,
    home: home,
    personal: destination,
    workspace: workspace,
  );

  ResumePlaces atWorkspace(WorkspaceResume place) => ResumePlaces(
    issuer: issuer,
    subject: subject,
    home: home,
    side: ResumeSide.workspace,
    personal: personal,
    workspace: place,
  );

  String encode() => jsonEncode({
    'v': version,
    'issuer': issuer,
    'subject': subject,
    'home': home,
    'side': side.name,
    if (personal != null) 'personal': personal,
    if (workspace case final w?)
      'workspace': {
        'installation': w.installation,
        'network': w.network,
        'location': w.location,
      },
  });

  /// Null for anything that is not a whole record of this version.
  static ResumePlaces? decode(String? raw) {
    if (raw == null) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final row = JsonReader.of(decoded, context: 'resume_places');
    if (row.intOrAbsent('v') != version) return null;
    final (issuer, subject, home) = (
      row.textOrAbsent('issuer'),
      row.textOrAbsent('subject'),
      row.textOrAbsent('home'),
    );
    final side = ResumeSide.values
        .where((s) => s.name == row.textOrAbsent('side'))
        .firstOrNull;
    final personal = row.textOrAbsent('personal');
    if (issuer == null ||
        subject == null ||
        home == null ||
        side == null ||
        (row.raw('personal') != null && !isPersonal(personal))) {
      return null;
    }
    WorkspaceResume? workspace;
    if (row.raw('workspace') != null) {
      final stored = row.objectOrAbsent('workspace');
      final (installation, network, location) = (
        stored.textOrAbsent('installation'),
        stored.textOrAbsent('network'),
        stored.textOrAbsent('location'),
      );
      if (installation == null ||
          network == null ||
          location == null ||
          installation.isEmpty ||
          !network.startsWith('$installation:') ||
          !location.startsWith('/') ||
          location.contains('?')) {
        return null;
      }
      workspace = WorkspaceResume(
        installation: installation,
        network: network,
        location: location,
      );
    }
    if (side == ResumeSide.workspace && workspace == null) return null;
    return ResumePlaces(
      issuer: issuer,
      subject: subject,
      home: home,
      side: side,
      personal: personal,
      workspace: workspace,
    );
  }

  /// Whether [location] is a personal address (`/me` or below it).
  static bool isPersonal(Object? location) =>
      location is String &&
      (location == '/me' ||
          location.startsWith('/me/') ||
          location.startsWith('/me?'));
}
