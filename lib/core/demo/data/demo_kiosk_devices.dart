// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3675 — the Demo's enrolled kiosks: the front-desk tablet, enrolled by
// the owner a month before the Demo's day and used that morning. The
// device the visitor holds is not the tablet: its enrolment store starts
// empty and lives in memory, so enrolling it in the Demo writes nothing to
// the platform's secure storage.
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../../features/kiosk/domain/kiosk_device.dart';
import '../../../features/kiosk/providers/kiosk_device_providers.dart';
import '../../backend/kiosk_credential_store.dart';
import '../demo_dataset.dart';
import '../demo_fixture.dart';

/// The kiosks of the Demo's business, kept for the session.
class DemoKioskDevices implements KioskDeviceRepository {
  DemoKioskDevices({required this.workspaceId, required this.today})
    : _devices = [
        KioskDevice(
          id: frontDeskId,
          name: demoKioskDevice.name,
          enrolledBy: demoCast.first.name,
          enrolledAt: today.subtract(const Duration(days: 30)),
          lastUsedAt: DateTime(today.year, today.month, today.day, 8, 40),
        ),
      ];

  /// The front-desk tablet's device id.
  static const frontDeskId = 'demo-kiosk-front-desk';

  final String workspaceId;

  /// The Demo's day: what is enrolled or revoked now happens on it.
  final DateTime today;
  final List<KioskDevice> _devices;

  @override
  Future<List<KioskDevice>> list(String workspaceId) async => [
    if (workspaceId == this.workspaceId) ..._devices.reversed,
  ];

  @override
  Future<KioskEnrolment> enrol(String workspaceId, String name) async {
    final id = 'demo-kiosk-${_devices.length + 1}';
    _devices.add(
      KioskDevice(
        id: id,
        name: name,
        enrolledBy: demoCast.first.name,
        enrolledAt: today,
      ),
    );
    // A stand-in of the credential's shape: the Demo signs nobody in with it.
    return KioskEnrolment(deviceId: id, credential: '0' * 64);
  }

  @override
  Future<bool> revoke(String deviceId) async {
    final i = _devices.indexWhere((d) => d.id == deviceId && !d.revoked);
    if (i < 0) return false;
    final d = _devices[i];
    _devices[i] = KioskDevice(
      id: d.id,
      name: d.name,
      enrolledBy: d.enrolledBy,
      enrolledAt: d.enrolledAt,
      lastUsedAt: d.lastUsedAt,
      revokedAt: today,
    );
    return true;
  }
}

/// The Demo's kiosk devices and this device's (empty) enrolment store.
List<Override> demoKioskOverrides(DemoFixture fixture) => [
  kioskDeviceRepositoryProvider.overrideWithValue(
    DemoKioskDevices(
      workspaceId: fixture.workspaces.workspaces.first.id,
      today: fixture.seededAt,
    ),
  ),
  kioskCredentialStoreProvider.overrideWithValue(
    InMemoryKioskCredentialStore(),
  ),
];
