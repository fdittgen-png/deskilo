// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3675 — the kiosk devices through their three functions (0734). Who may
// call them (operateKiosk or an owner, in their own session) is the
// server's decision; a refusal comes back as the PostgrestException.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/kiosk_device.dart';

class SupabaseKioskDevices implements KioskDeviceRepository {
  const SupabaseKioskDevices(this._client);

  final SupabaseClient _client;

  @override
  Future<List<KioskDevice>> list(String workspaceId) async {
    final raw = await _client.rpc<Object?>(
      'kiosk_devices_v1',
      params: {'p_workspace_id': workspaceId},
    );
    return [
      if (raw is List)
        for (final row in raw) KioskDevice.fromJson(row),
    ];
  }

  @override
  Future<KioskEnrolment> enrol(String workspaceId, String name) async {
    final raw = await _client.rpc<Object?>(
      'enrol_kiosk_device_v1',
      params: {'p_workspace_id': workspaceId, 'p_name': name},
    );
    final r = JsonReader.of(raw, context: 'enrol_kiosk_device_v1');
    return KioskEnrolment(
      deviceId: r.string('device_id'),
      credential: r.string('credential'),
    );
  }

  @override
  Future<bool> revoke(String deviceId) async =>
      await _client.rpc<Object?>(
        'revoke_kiosk_device_v1',
        params: {'p_device_id': deviceId},
      ) ==
      true;
}
