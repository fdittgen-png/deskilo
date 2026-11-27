// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// #4466 — the till boards connected to the business. Connecting one is the enrollment's step (#4454), which stores
/// nothing yet: until it does, no board is connected, and the Master data card counts none.
final connectedTillBoardsProvider = Provider<AsyncValue<List<Object?>>>((ref) => const AsyncData(<Object?>[]));
