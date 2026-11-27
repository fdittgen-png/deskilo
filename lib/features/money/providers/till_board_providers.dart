// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/device_code.dart';

/// #4466 — the till boards connected to the business. Connecting one is the enrollment's step (#4454), which stores
/// nothing yet: until it does, no board is connected outside the Demo, and the Master data card counts none.
final connectedTillBoardsProvider = Provider<AsyncValue<List<DeviceCode>>>((ref) => const AsyncData(<DeviceCode>[]));
