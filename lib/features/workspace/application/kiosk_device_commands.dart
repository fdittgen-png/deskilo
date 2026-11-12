// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3675 — what the kiosk devices screen asks for, with this device's
// enrolment kept in step with the server: an enrolment is stored here only
// once the server answered it, and revoking the device in hand forgets it
// here too.
import '../../../core/backend/kiosk_credential_store.dart';
import '../domain/kiosk_device.dart';

class KioskDeviceCommands {
  const KioskDeviceCommands(this._devices, this._held);

  final KioskDeviceRepository _devices;
  final KioskCredentialStore _held;

  /// Enrols this device in [workspaceId] under [name] and keeps its
  /// credential on this device.
  Future<void> enrol(String workspaceId, String name) async {
    final enrolment = await _devices.enrol(workspaceId, name);
    await _held.write(
      KioskCredential(
        workspaceId: workspaceId,
        deviceId: enrolment.deviceId,
        name: name,
        secret: enrolment.credential,
      ),
    );
  }

  /// Revokes [deviceId]; the device in hand forgets its credential too.
  Future<void> revoke(String deviceId) async {
    final held = await _held.read();
    await _devices.revoke(deviceId);
    if (held?.deviceId == deviceId) await _held.forget();
  }

  /// This device stops being a kiosk here; the server's record stays until
  /// it is revoked.
  Future<void> forget() => _held.forget();
}
