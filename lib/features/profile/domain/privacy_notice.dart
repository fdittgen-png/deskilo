// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1914 (0329) — the privacy notice as the server publishes it: the
// installation's, and the space's own supplement. What a recipient's
// region or transfer mechanism is may be `unknown`; the app says so
// rather than filling it in.

/// One recipient of personal data named by a notice.
class PrivacyRecipient {
  const PrivacyRecipient({
    required this.name,
    required this.role,
    required this.purpose,
    required this.legalBasis,
    required this.region,
    required this.transferMechanism,
    required this.essential,
  });

  factory PrivacyRecipient.fromJson(Map<String, dynamic> json) =>
      PrivacyRecipient(
        name: json['name'] as String? ?? '',
        role: json['role'] as String? ?? '',
        purpose: json['purpose'] as String? ?? '',
        legalBasis: json['legal_basis'] as String? ?? '',
        region: json['region'] as String? ?? '',
        transferMechanism: json['transfer_mechanism'] as String? ?? 'unknown',
        essential: json['essential'] as bool? ?? true,
      );

  final String name;
  final String role;
  final String purpose;
  final String legalBasis;
  final String region;
  final String transferMechanism;

  /// False for processing the person can do without (push delivery, …).
  final bool essential;
}

/// One published notice.
class PrivacyNotice {
  const PrivacyNotice({
    required this.version,
    required this.controllerName,
    required this.controllerContact,
    required this.rightsContact,
    required this.retention,
    required this.recipients,
  });

  factory PrivacyNotice.fromJson(Map<String, dynamic> json) {
    final manifest = Map<String, dynamic>.from(
      json['manifest'] as Map? ?? const {},
    );
    final controller = Map<String, dynamic>.from(
      manifest['controller'] as Map? ?? const {},
    );
    return PrivacyNotice(
      version: json['version'] as String,
      controllerName: controller['name'] as String? ?? '',
      controllerContact: controller['contact'] as String? ?? '',
      rightsContact: manifest['rights_contact'] as String? ?? '',
      retention: manifest['retention'] as String? ?? '',
      recipients: [
        for (final r in (manifest['recipients'] as List? ?? const []))
          PrivacyRecipient.fromJson(Map<String, dynamic>.from(r as Map)),
      ],
    );
  }

  final String version;
  final String controllerName;
  final String controllerContact;
  final String rightsContact;
  final String retention;
  final List<PrivacyRecipient> recipients;
}

/// What applies to the signed-in person: the installation's notice, the
/// current space's supplement, and which versions they acknowledged.
class PrivacyNotices {
  const PrivacyNotices({
    this.installation,
    this.workspace,
    this.workspaceId,
    this.acknowledgedVersions = const {},
  });

  factory PrivacyNotices.fromJson(
    Map<String, dynamic> json, {
    String? workspaceId,
  }) => PrivacyNotices(
    workspaceId: workspaceId,
    installation: json['installation'] is Map
        ? PrivacyNotice.fromJson(
            Map<String, dynamic>.from(json['installation'] as Map),
          )
        : null,
    workspace: json['workspace'] is Map
        ? PrivacyNotice.fromJson(
            Map<String, dynamic>.from(json['workspace'] as Map),
          )
        : null,
    acknowledgedVersions: {
      for (final a in (json['acknowledged'] as List? ?? const []))
        '${(a as Map)['workspace_id'] ?? ''}:${a['version']}',
    },
  );

  static const none = PrivacyNotices();

  final PrivacyNotice? installation;
  final PrivacyNotice? workspace;

  /// The space [workspace] belongs to.
  final String? workspaceId;

  /// `<workspace id or empty>:<version>` for every acknowledgment.
  final Set<String> acknowledgedVersions;

  bool acknowledgedWorkspace(String workspaceId) =>
      workspace != null &&
      acknowledgedVersions.contains('$workspaceId:${workspace!.version}');
}
