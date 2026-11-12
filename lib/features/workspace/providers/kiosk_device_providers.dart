// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/backend/kiosk_credential_store.dart';
import '../application/kiosk_device_commands.dart';
import '../data/supabase_kiosk_devices.dart';
import '../domain/kiosk_device.dart';
import 'operation_context_providers.dart';

part 'kiosk_device_providers.g.dart';

/// #3675 — the business's enrolled kiosks.
@Riverpod(keepAlive: true)
KioskDeviceRepository kioskDeviceRepository(Ref ref) =>
    SupabaseKioskDevices(ref.watch(selectedWorkspaceClientProvider));

/// What the kiosk devices screen asks for.
@Riverpod(keepAlive: true)
KioskDeviceCommands kioskDeviceCommands(Ref ref) => KioskDeviceCommands(
  ref.watch(kioskDeviceRepositoryProvider),
  ref.watch(kioskCredentialStoreProvider),
);

Duration? _noRetry(int count, Object error) => null;

/// The devices of [workspaceId], newest first. A read that failed is said
/// at once, with Try again (#3742): no automatic retries.
@Riverpod(retry: _noRetry)
Future<List<KioskDevice>> kioskDevices(Ref ref, String workspaceId) =>
    ref.watch(kioskDeviceRepositoryProvider).list(workspaceId);
