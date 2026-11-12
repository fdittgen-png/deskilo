// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3675 — the devices a business enrolled as kiosks (kiosk_devices, 0734).
// The list never carries a credential or its hash; the credential exists
// only in the answer to an enrolment, once.

/// One enrolled device of the business.
class KioskDevice {
  const KioskDevice({
    required this.id,
    required this.name,
    required this.enrolledBy,
    required this.enrolledAt,
    this.lastUsedAt,
    this.revokedAt,
  });

  final String id;
  final String name;

  /// Who enrolled it, by name; empty when that person left.
  final String enrolledBy;
  final DateTime enrolledAt;
  final DateTime? lastUsedAt;
  final DateTime? revokedAt;

  bool get revoked => revokedAt != null;

  static KioskDevice? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final enrolledAt = DateTime.tryParse('${raw['enrolled_at']}');
    if (id is! String || id.isEmpty || enrolledAt == null) return null;
    return KioskDevice(
      id: id,
      name: '${raw['name'] ?? ''}',
      enrolledBy: '${raw['enrolled_by'] ?? ''}',
      enrolledAt: enrolledAt,
      lastUsedAt: DateTime.tryParse('${raw['last_used_at']}'),
      revokedAt: DateTime.tryParse('${raw['revoked_at']}'),
    );
  }
}

/// What an enrolment answers, once: the device and its credential.
class KioskEnrolment {
  const KioskEnrolment({required this.deviceId, required this.credential});

  final String deviceId;
  final String credential;
}

/// The business's kiosks, as the server keeps them.
abstract interface class KioskDeviceRepository {
  /// Every device of [workspaceId], newest first, revoked ones included.
  Future<List<KioskDevice>> list(String workspaceId);

  /// Enrols the calling device under [name]. The credential is in this
  /// answer only.
  Future<KioskEnrolment> enrol(String workspaceId, String name);

  /// Revokes [deviceId]; false when it was revoked already.
  Future<bool> revoke(String deviceId);
}
