// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../workspace/providers/operation_context_providers.dart';
import '../data/supabase_kiosk_devices.dart';
import '../domain/kiosk_device.dart';

part 'kiosk_device_providers.g.dart';

/// #3675 — the business's enrolled kiosks.
@Riverpod(keepAlive: true)
KioskDeviceRepository kioskDeviceRepository(Ref ref) =>
    SupabaseKioskDevices(ref.watch(selectedWorkspaceClientProvider));

Duration? _noRetry(int count, Object error) => null;

/// The devices of [workspaceId], newest first. A read that failed is said
/// at once, with Try again (#3742): no automatic retries.
@Riverpod(retry: _noRetry)
Future<List<KioskDevice>> kioskDevices(Ref ref, String workspaceId) =>
    ref.watch(kioskDeviceRepositoryProvider).list(workspaceId);
