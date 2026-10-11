// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1914 (0329) — the privacy notice as the server publishes it: the
// installation's, and the space's own supplement. What a recipient's
// region or transfer mechanism is may be `unknown`; the app says so
// rather than filling it in.
import '../../../core/data/json_reader.dart';

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

  factory PrivacyRecipient._read(JsonReader r) => PrivacyRecipient(
    name: r.stringOr('name'),
    role: r.stringOr('role'),
    purpose: r.stringOr('purpose'),
    legalBasis: r.stringOr('legal_basis'),
    region: r.stringOr('region'),
    transferMechanism: r.stringOr('transfer_mechanism', 'unknown'),
    essential: r.boolOr('essential', true),
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

  /// #2387 — read through [JsonReader]; [context] names the RPC.
  factory PrivacyNotice._read(JsonReader r) {
    final manifest = JsonReader(
      r.objectOrEmpty('manifest'),
      context: '${r.context}.manifest',
    );
    final controller = JsonReader(
      manifest.objectOrEmpty('controller'),
      context: '${manifest.context}.controller',
    );
    return PrivacyNotice(
      version: r.string('version'),
      controllerName: controller.stringOr('name'),
      controllerContact: controller.stringOr('contact'),
      rightsContact: manifest.stringOr('rights_contact'),
      retention: manifest.stringOr('retention'),
      recipients: manifest.objects('recipients', PrivacyRecipient._read),
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

  /// #2387 — read through [JsonReader]; [context] names the RPC.
  factory PrivacyNotices.fromJson(
    Map<String, dynamic> json, {
    String? workspaceId,
    String context = 'current_privacy_notice',
  }) {
    final r = JsonReader(json, context: context);
    final installation = r.objectOrNull('installation');
    final workspace = r.objectOrNull('workspace');
    return PrivacyNotices(
      workspaceId: workspaceId,
      installation: installation == null
          ? null
          : PrivacyNotice._read(installation),
      workspace: workspace == null ? null : PrivacyNotice._read(workspace),
      acknowledgedVersions: {
        ...r.objects(
          'acknowledged',
          (a) => '${a.stringOr('workspace_id')}:${a.string('version')}',
        ),
      },
    );
  }

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
